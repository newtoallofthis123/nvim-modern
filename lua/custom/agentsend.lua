-- Send an @file ref straight into a Claude Code / Codex session living in tmux.
-- Reuses the ref formatters from custom.copy.
--
-- Variants (all normal + visual, all stage-only -- no auto Enter):
--   <leader>aa  ref                       @file#42
--   <leader>aA  ref + force re-pick the target session
--   <leader>ad  ref + LSP errors/warnings on the line/range
--   <leader>as  ref + fenced code snippet of the line/selection
--   <leader>ah  ref + the gitsigns hunk under cursor as a diff fence
--   <leader>aH  same + a one-line note typed first ("here's my objection")
--
-- Mechanism notes (why it's done this way):
--  * Hooks can't pre-fill an agent's composer -- they only react to events.
--    So injection has to come from outside, via tmux.
--  * Both TUIs open a fuzzy file-picker the instant they see a typed `@`.
--    Sending keystrokes would hijack into that picker. Bracketed paste
--    (`tmux paste-buffer -p`) is routed through a separate path that inserts
--    literal text without triggering it.
--  * claude understands `@file#line` / `@file#10-20`. codex has no line
--    syntax on input, so the line is appended as prose: `@file (line 42)`.
--  * Sessions are detected via the tmux `@app` pane option (set to "claude" /
--    "codex"), not `pane_current_command` -- the latter shows "node" when the
--    agent runs via the npm wrapper, `@app` is explicit and reliable.

local M = {}

local copy = require("custom.copy")

-- Sticky target: last pane we sent to. Reused while it's still a live
-- candidate; since candidates are cwd-narrowed, this is per-project in practice.
M.last_pane_id = nil

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "AgentSend" })
end

-- Base ref for the target agent. `line` is "42" or "10-20".
local function format_ref(agent, path, line)
	if agent == "codex" then
		local noun = line:find("-", 1, true) and "lines" or "line"
		return string.format("@%s (%s %s) ", path, noun, line)
	end
	-- claude (and default): native #line anchor
	return string.format("@%s#%s ", path, line)
end

-- Final payload = base ref + optional extra (diagnostic prose or code fence).
local function build_text(agent, ctx)
	local base = format_ref(agent, ctx.path, ctx.line)
	local extra = ctx.extra
	if not extra then
		return base
	end
	if extra.kind == "diag" then
		return base .. "— " .. extra.text .. " "
	elseif extra.kind == "snippet" then
		local fence = "```" .. (extra.lang ~= "" and extra.lang or "")
		return base .. "\n" .. fence .. "\n" .. table.concat(extra.lines, "\n") .. "\n```\n"
	elseif extra.kind == "hunk" then
		local note = extra.note and extra.note ~= "" and ("— " .. extra.note .. "\n") or ""
		return base .. note .. "\n```diff\n" .. table.concat(extra.lines, "\n") .. "\n```\n"
	end
	return base
end

-- The gitsigns hunk under the cursor, rendered as unified-diff lines.
-- Returns the diff lines + the added-side line range for the @ref, or nil.
local function capture_hunk()
	local ok, gitsigns = pcall(require, "gitsigns")
	if not ok then
		return nil
	end
	local hunks = gitsigns.get_hunks(vim.api.nvim_get_current_buf())
	if not hunks or #hunks == 0 then
		return nil
	end
	local lnum = vim.api.nvim_win_get_cursor(0)[1]
	for _, h in ipairs(hunks) do
		local start = h.added.start
		local fin = h.added.count > 0 and (start + h.added.count - 1) or start
		if (lnum >= start and lnum <= fin) or (h.added.count == 0 and lnum == start) then
			local diff = { h.head or "" }
			for _, l in ipairs(h.removed.lines or {}) do
				table.insert(diff, "-" .. l)
			end
			for _, l in ipairs(h.added.lines or {}) do
				table.insert(diff, "+" .. l)
			end
			local range = h.added.count > 1 and string.format("%d-%d", start, fin) or tostring(start)
			return { lines = diff, range = range }
		end
	end
	return nil
end

-- Capture the optional extra payload synchronously (before any async picker).
local function capture_extra(opts)
	local s, e = copy.get_line_range()
	if opts.with_diagnostic then
		local msgs = {}
		for _, d in ipairs(vim.diagnostic.get(0)) do
			local ln = d.lnum + 1
			if ln >= s and ln <= e and d.severity <= vim.diagnostic.severity.WARN then
				table.insert(msgs, vim.split(d.message, "\n", { plain = true })[1])
			end
		end
		if #msgs == 0 then
			notify("No errors/warnings here — sending plain ref")
			return nil
		end
		return { kind = "diag", text = table.concat(msgs, " · ") }
	elseif opts.with_snippet then
		return { kind = "snippet", lang = vim.bo.filetype, lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false) }
	end
	return nil
end

-- List every pane that has an `@app` set (across all windows/sessions),
-- excluding our own pane.
local function list_agent_panes()
	local self_pane = vim.env.TMUX_PANE
	local out = vim.fn.systemlist({
		"tmux",
		"list-panes",
		"-a",
		"-F",
		"#{@app}\t#{pane_id}\t#{session_name}:#{window_index}\t#{pane_current_path}",
		"-f",
		"#{!=:#{@app},}",
	})
	if vim.v.shell_error ~= 0 then
		return nil
	end

	local panes = {}
	for _, l in ipairs(out) do
		local parts = vim.split(l, "\t", { plain = true })
		local app, id, win, path = parts[1], parts[2], parts[3], parts[4]
		if id and app and app ~= "" and id ~= self_pane then
			table.insert(panes, { app = app, id = id, win = win or "", path = path })
		end
	end
	return panes
end

-- Soft-narrow to sessions launched in (or around) the current project.
local function narrow_to_cwd(panes)
	local cwd = vim.fn.getcwd()
	local matched = vim.tbl_filter(function(p)
		return p.path == cwd or vim.startswith(cwd, p.path .. "/") or vim.startswith(p.path, cwd .. "/")
	end, panes)
	return #matched > 0 and matched or panes
end

local function pane_label(p)
	return string.format("%s  %s  %s", p.app, p.win, vim.fn.fnamemodify(p.path, ":~"))
end

-- Tail of a pane's visible content, for the picker preview.
local function pane_preview_lines(id)
	local out = vim.fn.systemlist({ "tmux", "capture-pane", "-p", "-t", id })
	if vim.v.shell_error ~= 0 or #out == 0 then
		return { "(no preview)" }
	end
	while #out > 0 and out[#out]:match("^%s*$") do
		table.remove(out)
	end
	if #out > 40 then
		out = vim.list_slice(out, #out - 39, #out)
	end
	return out
end

-- Pick a pane. Uses the full snacks picker (with a live pane preview) when
-- available, else falls back to a plain select / vim.ui.select.
local function pick(panes, cb)
	if Snacks and Snacks.picker and Snacks.picker.pick then
		local items = {}
		for i, p in ipairs(panes) do
			items[i] = { idx = i, text = pane_label(p), item = p }
		end
		Snacks.picker.pick({
			source = "agentsend",
			items = items,
			title = "Send ref to agent",
			format = function(item)
				return { { item.text } }
			end,
			preview = function(ctx)
				ctx.preview:reset()
				ctx.preview:set_title(ctx.item.item.app .. "  " .. ctx.item.item.win)
				ctx.preview:set_lines(pane_preview_lines(ctx.item.item.id))
			end,
			confirm = function(picker, item)
				picker:close()
				if item and item.item then
					vim.schedule(function()
						cb(item.item)
					end)
				end
			end,
		})
		return
	end

	local select = (Snacks and Snacks.picker and Snacks.picker.select) or vim.ui.select
	select(panes, { prompt = "Send ref to which session?", format_item = pane_label }, function(choice)
		if choice then
			cb(choice)
		end
	end)
end

-- Resolve which pane to send to, honoring the sticky target.
local function resolve_target(panes, repick, cb)
	if repick then
		M.last_pane_id = nil
	end
	if M.last_pane_id then
		for _, p in ipairs(panes) do
			if p.id == M.last_pane_id then
				return cb(p)
			end
		end
	end
	if #panes == 1 then
		M.last_pane_id = panes[1].id
		return cb(panes[1])
	end
	pick(panes, function(choice)
		M.last_pane_id = choice.id
		cb(choice)
	end)
end

-- Paste payload into a pane as a bracketed paste (won't trigger the @ picker).
local function inject(pane, ctx)
	local text = build_text(pane.app, ctx)
	vim.fn.system({ "tmux", "set-buffer", "-b", "nvim-agentref", "--", text })
	vim.fn.system({ "tmux", "paste-buffer", "-p", "-d", "-b", "nvim-agentref", "-t", pane.id })
	if vim.v.shell_error ~= 0 then
		notify("Failed to paste into " .. pane.app, vim.log.levels.ERROR)
		return
	end
	notify(string.format("Sent to %s [%s]", pane.app, pane.win))
end

---@param opts? { repick?: boolean, with_diagnostic?: boolean, with_snippet?: boolean }
function M.send(opts)
	opts = opts or {}
	if not vim.env.TMUX then
		notify("Not inside tmux", vim.log.levels.WARN)
		return
	end

	-- Capture everything that depends on cursor/selection synchronously, before
	-- the picker can change mode/marks.
	local path = copy.get_relative_filepath()
	if path == "[No Name]" then
		notify("No file to reference", vim.log.levels.WARN)
		return
	end
	local ctx = { path = path, line = copy.get_current_line_or_range(), extra = capture_extra(opts) }
	if opts.with_hunk then
		local hunk = capture_hunk()
		if not hunk then
			notify("No hunk under cursor", vim.log.levels.WARN)
			return
		end
		ctx.line = hunk.range
		ctx.extra = { kind = "hunk", lines = hunk.lines }
	end

	local panes = list_agent_panes()
	if not panes then
		notify("tmux query failed", vim.log.levels.ERROR)
		return
	end
	if #panes == 0 then
		notify("No tagged agent session (@app) found", vim.log.levels.WARN)
		return
	end
	panes = narrow_to_cwd(panes)

	local function fire()
		resolve_target(panes, opts.repick, function(pane)
			inject(pane, ctx)
		end)
	end

	if opts.with_note then
		vim.ui.input({ prompt = "note for the agent: " }, function(note)
			if note == nil then
				return -- cancelled
			end
			ctx.extra.note = note
			fire()
		end)
		return
	end
	fire()
end

function M.setup()
	vim.api.nvim_create_user_command("AgentSendRef", function()
		M.send()
	end, { desc = "Send @file ref to a claude/codex session in tmux" })

	local map = vim.keymap.set
	map({ "n", "v" }, "<leader>aa", function()
		M.send()
	end, { desc = "Agent: send @file ref" })
	map({ "n", "v" }, "<leader>aA", function()
		M.send({ repick = true })
	end, { desc = "Agent: send ref (pick session)" })
	map({ "n", "v" }, "<leader>ad", function()
		M.send({ with_diagnostic = true })
	end, { desc = "Agent: send ref + diagnostic" })
	map({ "n", "v" }, "<leader>as", function()
		M.send({ with_snippet = true })
	end, { desc = "Agent: send ref + code snippet" })
	map("n", "<leader>ah", function()
		M.send({ with_hunk = true })
	end, { desc = "Agent: send hunk under cursor" })
	map("n", "<leader>aH", function()
		M.send({ with_hunk = true, with_note = true })
	end, { desc = "Agent: send hunk + note" })
end

return M
