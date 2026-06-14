-- Run `just` recipes / commands in a tmux pane YOU pick. nvim never runs the
-- server itself — it lists panes, you choose one, and the recipe is sent there
-- via tmux. Pure tmux. (Pane picker mirrors custom.agentsend.)
local M = {}

M.pane_id = nil -- sticky chosen pane
M.last_cmd = nil -- last command we sent (for restart)

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "just" })
end

local function in_tmux()
	if vim.env.TMUX then
		return true
	end
	notify("Not inside tmux", vim.log.levels.WARN)
	return false
end

-- tmux primitives -----------------------------------------------------------
local function list_panes()
	local self_pane = vim.env.TMUX_PANE
	local out = vim.fn.systemlist({
		"tmux",
		"list-panes",
		"-a",
		"-F",
		"#{pane_id}\t#{session_name}:#{window_index}.#{pane_index}\t#{pane_current_command}\t#{pane_current_path}",
	})
	if vim.v.shell_error ~= 0 then
		return nil
	end
	local panes = {}
	for _, l in ipairs(out) do
		local id, loc, cmd, path = unpack(vim.split(l, "\t", { plain = true }))
		if id and id ~= self_pane then
			panes[#panes + 1] = { id = id, loc = loc or "", cmd = cmd or "", path = path or "" }
		end
	end
	return panes
end

local function capture(id, scrollback)
	local args = { "tmux", "capture-pane", "-p", "-t", id }
	if scrollback then
		vim.list_extend(args, { "-S", "-" .. scrollback })
	end
	local out = vim.fn.systemlist(args)
	return (vim.v.shell_error == 0) and out or {}
end

-- send literal text (then optionally Enter); C-c etc. go via send_key
local function send_text(id, text, enter)
	if text and text ~= "" then
		vim.fn.system({ "tmux", "send-keys", "-t", id, "-l", text })
	end
	if enter then
		vim.fn.system({ "tmux", "send-keys", "-t", id, "Enter" })
	end
end
local function send_key(id, key)
	vim.fn.system({ "tmux", "send-keys", "-t", id, key })
end

-- pane picker (snacks w/ live preview, else vim.ui.select) -------------------
local function label(p)
	return string.format("%s  %s  %s", p.loc, p.cmd, vim.fn.fnamemodify(p.path, ":~"))
end

local function preview_lines(id)
	local out = capture(id)
	while #out > 0 and out[#out]:match("^%s*$") do
		table.remove(out)
	end
	if #out > 40 then
		out = vim.list_slice(out, #out - 39, #out)
	end
	return #out > 0 and out or { "(empty pane)" }
end

local function pick_pane(cb)
	local panes = list_panes()
	if not panes or #panes == 0 then
		notify("No other tmux panes found", vim.log.levels.WARN)
		return
	end
	if Snacks and Snacks.picker and Snacks.picker.pick then
		local items = {}
		for i, p in ipairs(panes) do
			items[i] = { idx = i, text = label(p), item = p }
		end
		Snacks.picker.pick({
			source = "justrun-panes",
			items = items,
			title = "Run in which tmux pane?",
			format = function(it)
				return { { it.text } }
			end,
			preview = function(ctx)
				ctx.preview:reset()
				ctx.preview:set_title(ctx.item.item.loc .. "  " .. ctx.item.item.cmd)
				ctx.preview:set_lines(preview_lines(ctx.item.item.id))
			end,
			confirm = function(picker, it)
				picker:close()
				if it and it.item then
					vim.schedule(function()
						cb(it.item)
					end)
				end
			end,
		})
	else
		vim.ui.select(panes, { prompt = "Run in which pane?", format_item = label }, function(c)
			if c then
				cb(c)
			end
		end)
	end
end

-- resolve the target pane: reuse the sticky one if still alive, else pick
local function resolve_pane(cb, repick)
	if repick then
		M.pane_id = nil
	end
	if M.pane_id then
		for _, p in ipairs(list_panes() or {}) do
			if p.id == M.pane_id then
				return cb(p)
			end
		end
		M.pane_id = nil -- it died
	end
	pick_pane(function(p)
		M.pane_id = p.id
		cb(p)
	end)
end

-- error scanner: file:line(:col) → quickfix items
local function parse_locations(out)
	local items, seen = {}, {}
	for _, line in ipairs(out) do
		for path, lnum, col in line:gmatch("([%w%._/%-]+%.%w+):(%d+):?(%d*)") do
			local key = path .. ":" .. lnum
			if not seen[key] and (vim.fn.filereadable(path) == 1 or vim.fn.filereadable(vim.fn.fnamemodify(path, ":p")) == 1) then
				seen[key] = true
				items[#items + 1] = {
					filename = path,
					lnum = tonumber(lnum),
					col = tonumber(col) or 1,
					text = vim.trim(line),
				}
			end
		end
	end
	return items
end

local function float(lines, title)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	local w, h = math.floor(vim.o.columns * 0.8), math.floor(vim.o.lines * 0.7)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = w,
		height = h,
		row = math.floor((vim.o.lines - h) / 2),
		col = math.floor((vim.o.columns - w) / 2),
		style = "minimal",
		border = "rounded",
		title = title or " pane ",
	})
	vim.bo[buf].filetype = "log"
	vim.bo[buf].modifiable = false
	vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf })
	vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", { buffer = buf })
	pcall(vim.api.nvim_win_set_cursor, win, { math.max(#lines, 1), 0 })
end

-- verbs ---------------------------------------------------------------------
-- run a just recipe (you pick which) in a tmux pane (you pick which)
function M.run_recipe()
	if not in_tmux() then
		return
	end
	vim.system({ "just", "--summary" }, { cwd = vim.fn.getcwd(), text = true }, vim.schedule_wrap(function(res)
		if res.code ~= 0 then
			notify("No justfile in cwd:\n" .. (res.stderr or ""), vim.log.levels.WARN)
			return
		end
		local recipes = vim.split(vim.trim(res.stdout or ""), "%s+")
		vim.ui.select(recipes, { prompt = "just ⟶ run which recipe?" }, function(r)
			if not r then
				return
			end
			resolve_pane(function(p)
				M.last_cmd = "just " .. r
				send_text(p.id, M.last_cmd, true)
				notify("▶ " .. M.last_cmd .. "   in " .. p.loc)
			end)
		end)
	end))
end

-- send an arbitrary command/line to the pane
function M.send()
	if not in_tmux() then
		return
	end
	vim.ui.input({ prompt = "send to pane ⟶ " }, function(cmd)
		if not cmd or cmd == "" then
			return
		end
		resolve_pane(function(p)
			M.last_cmd = cmd
			send_text(p.id, cmd, true)
			notify("▶ " .. cmd .. "   in " .. p.loc)
		end)
	end)
end

-- restart: C-c the pane, then re-run the last command we sent
function M.restart()
	if not in_tmux() then
		return
	end
	resolve_pane(function(p)
		send_key(p.id, "C-c")
		vim.defer_fn(function()
			if M.last_cmd then
				send_text(p.id, M.last_cmd, true)
			else
				send_key(p.id, "Up")
				send_key(p.id, "Enter")
			end
			notify("⟳ restart   in " .. p.loc)
		end, 250)
	end)
end

-- kill: send C-c to the pane
function M.kill()
	if not in_tmux() then
		return
	end
	resolve_pane(function(p)
		send_key(p.id, "C-c")
		notify("✗ C-c   in " .. p.loc)
	end)
end

-- logs: float the pane's recent scrollback
function M.logs()
	if not in_tmux() then
		return
	end
	resolve_pane(function(p)
		float(capture(p.id, 500), " " .. p.loc .. "  logs ")
	end)
end

-- jump to error: scan the pane output for file:line → quickfix
function M.errors()
	if not in_tmux() then
		return
	end
	resolve_pane(function(p)
		local items = parse_locations(capture(p.id, 1000))
		if #items == 0 then
			notify("No file:line found in pane output")
			return
		end
		vim.fn.setqflist({}, "r", { title = "Pane errors: " .. p.loc, items = items })
		vim.cmd("botright copen")
	end)
end

-- re-choose the target pane
function M.pick()
	if not in_tmux() then
		return
	end
	pick_pane(function(p)
		M.pane_id = p.id
		notify("pane set → " .. p.loc)
	end)
end

function M.setup()
	local map = vim.keymap.set
	map("n", "<leader>jr", M.run_recipe, { desc = "just: run recipe in a tmux pane" })
	map("n", "<leader>jc", M.send, { desc = "tmux: send command to pane" })
	map("n", "<leader>jx", M.restart, { desc = "tmux: restart (C-c + rerun) pane" })
	map("n", "<leader>jk", M.kill, { desc = "tmux: kill (C-c) pane" })
	map("n", "<leader>jl", M.logs, { desc = "tmux: pane logs (float)" })
	map("n", "<leader>je", M.errors, { desc = "tmux: pane errors → quickfix" })
	map("n", "<leader>jp", M.pick, { desc = "tmux: pick target pane" })
end

M.setup()
return M
