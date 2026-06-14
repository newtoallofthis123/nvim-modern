-- satchel — a ticket and its context bucket are the SAME thing.
--
-- <leader>sn names one → creates a markdown ticket (<ddmmyyyy>_<name>.md) AND a
-- bucket of @refs, linked. Toss refs while browsing code; <leader>sg jumps to
-- the ticket and dumps them in. Refs use @path#L40-58; selections carry a
-- fenced code block. Session-only (v1). Pickers reuse snacks; fmt reuses copy.
local copy = require("custom.copy")

local M = {}

-- state: M.buckets[name] = { items = {item,...}, ticket = "<file>.md", bufnr }
M.buckets = {}
M.active = nil

-- helpers -------------------------------------------------------------------
local function rel(abspath)
	local cwd = vim.fn.getcwd()
	return (abspath:gsub(vim.pesc(cwd .. "/"), ""))
end

function M.refresh()
	pcall(vim.cmd, "redrawstatus")
end
function M.set_active(name)
	M.active = name
	M.refresh()
end

local function bucket()
	return M.active and M.buckets[M.active]
end

local function add_item(name, item)
	table.insert(M.buckets[name].items, item)
	M.refresh()
end

local function toast(name)
	vim.notify(("🪣 %s ·%d"):format(name, #M.buckets[name].items))
end

local function render(item)
	local lines = { item.ref }
	if item.code and item.code ~= "" then
		lines[#lines + 1] = "```" .. (item.ft or "")
		for _, l in ipairs(vim.split(item.code, "\n", { plain = true })) do
			lines[#lines + 1] = l
		end
		lines[#lines + 1] = "```"
	end
	return lines
end

local function insert_inline(text)
	vim.api.nvim_put({ text }, "c", true, true)
end
local function insert_block(lines)
	if #lines > 0 then
		vim.api.nvim_put(lines, "l", true, true)
	end
end

local function blocks_of(items)
	local lines = {}
	for _, it in ipairs(items) do
		for _, l in ipairs(render(it)) do
			lines[#lines + 1] = l
		end
		lines[#lines + 1] = ""
	end
	if #lines > 0 then
		table.remove(lines)
	end
	return lines
end

-- a tiny list picker (snacks if present, else vim.ui.select) -----------------
local function pick_list(title, items, on_confirm, multi)
	if not (Snacks and Snacks.picker) then
		vim.ui.select(items, {
			prompt = title,
			format_item = function(i)
				return i.text
			end,
		}, function(c)
			if c then
				on_confirm({ c })
			end
		end)
		return
	end
	Snacks.picker.pick({
		title = title,
		items = items,
		format = function(item)
			return { { item.text } }
		end,
		confirm = function(picker, item)
			local sel = multi and picker:selected({ fallback = true }) or { item }
			picker:close()
			on_confirm(sel)
		end,
	})
end

-- ticket = bucket: create + open -------------------------------------------
local function make_bucket(name)
	local file = ("%s_%s.md"):format(vim.fn.strftime("%d%m%Y"), (name:gsub("%s+", "-")))
	M.buckets[name] = { items = {}, ticket = file, bufnr = nil }
	M.set_active(name)
	return file
end

function M.open_ticket(name)
	local b = M.buckets[name]
	if not b then
		return
	end
	-- already open in a window (any tab)? jump to it.
	if b.bufnr and vim.api.nvim_buf_is_valid(b.bufnr) then
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_get_buf(win) == b.bufnr then
				vim.api.nvim_set_current_win(win)
				return
			end
		end
		-- exists but hidden → bring it up in a new tab
		vim.cmd("tabnew")
		vim.cmd("buffer " .. b.bufnr)
		return
	end
	-- fresh ticket → new tab
	vim.cmd("tabnew")
	local buf = vim.api.nvim_get_current_buf()
	pcall(vim.api.nvim_buf_set_name, buf, b.ticket)
	vim.bo.filetype = "markdown"
	b.bufnr = buf
end

-- <leader>sn : name → new ticket+bucket, opens the ticket
function M.new_ticket()
	vim.ui.input({ prompt = "Ticket name: " }, function(name)
		if not name or name == "" then
			return
		end
		local file = make_bucket(name)
		M.open_ticket(name)
		vim.notify("🪣📝 " .. name .. "  →  " .. file)
	end)
end

-- create a bucket WITHOUT stealing focus (used mid-toss from a code buffer)
local function prompt_make(after)
	vim.ui.input({ prompt = "Ticket name: " }, function(name)
		if not name or name == "" then
			return
		end
		local file = make_bucket(name)
		vim.notify("🪣 " .. name .. "  →  " .. file)
		if after then
			after(name)
		end
	end)
end

function M.enter_bucket()
	local names = vim.tbl_keys(M.buckets)
	if #names == 0 then
		return M.new_ticket()
	end
	local items = {}
	for _, n in ipairs(names) do
		items[#items + 1] = { text = n, name = n }
	end
	items[#items + 1] = { text = "＋ new ticket…", new = true }
	pick_list("Enter bucket", items, function(sel)
		local it = sel and sel[1]
		if not it then
			return
		end
		if it.new then
			M.new_ticket()
		else
			M.set_active(it.name)
			M.open_ticket(it.name)
			vim.notify("🪣 " .. it.name)
		end
	end)
end

function M.leave_bucket()
	if not M.active then
		return
	end
	local n = M.active
	M.set_active(nil)
	vim.notify("left bucket: " .. n)
end

-- resolve target for TOSSING (active, else pick/create — never steals focus)
function M.with_bucket(cb)
	if bucket() then
		return cb(M.active)
	end
	local names = vim.tbl_keys(M.buckets)
	if #names == 0 then
		return prompt_make(cb)
	end
	local items = {}
	for _, n in ipairs(names) do
		items[#items + 1] = { text = n, name = n }
	end
	items[#items + 1] = { text = "＋ new ticket…", new = true }
	pick_list("Toss into", items, function(sel)
		local it = sel and sel[1]
		if not it then
			return
		end
		if it.new then
			prompt_make(cb)
		else
			M.set_active(it.name)
			cb(it.name)
		end
	end)
end

-- resolve an EXISTING bucket for drop/dump/manage/go
function M.with_existing(cb)
	if bucket() then
		return cb(M.active)
	end
	local names = vim.tbl_keys(M.buckets)
	if #names == 0 then
		vim.notify("no tickets yet — <leader>sn", vim.log.levels.WARN)
		return
	end
	local items = {}
	for _, n in ipairs(names) do
		items[#items + 1] = { text = n, name = n }
	end
	pick_list("Use bucket", items, function(sel)
		local it = sel and sel[1]
		if it then
			M.set_active(it.name)
			cb(it.name)
		end
	end)
end

-- capture -------------------------------------------------------------------
function M.toss_file()
	local r = copy.get_relative_filepath()
	if r == "[No Name]" then
		vim.notify("no file here", vim.log.levels.WARN)
		return
	end
	M.with_bucket(function(name)
		add_item(name, { ref = "@" .. r })
		toast(name)
	end)
end

function M.toss_selection()
	local r = copy.get_relative_filepath()
	if r == "[No Name]" then
		return
	end
	local s, e = vim.fn.line("v"), vim.fn.line(".")
	if s > e then
		s, e = e, s
	end
	local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
	local ref = (s == e) and ("@%s#L%d"):format(r, s) or ("@%s#L%d-%d"):format(r, s, e)
	local ft = vim.bo.filetype
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
	M.with_bucket(function(name)
		add_item(name, { ref = ref, code = table.concat(lines, "\n"), ft = ft })
		toast(name)
	end)
end

-- insert --------------------------------------------------------------------
function M.insert_file_ref()
	if not (Snacks and Snacks.picker) then
		vim.notify("snacks picker not available", vim.log.levels.WARN)
		return
	end
	Snacks.picker.files({
		confirm = function(picker, item)
			picker:close()
			local p = item.file or item.text
			insert_inline("@" .. rel(vim.fn.fnamemodify(p, ":p")))
		end,
	})
end

local function insert_all(name)
	local items = M.buckets[name].items
	if #items == 0 then
		vim.notify("bucket is empty")
		return
	end
	insert_block(blocks_of(items))
end

function M.drop()
	M.with_existing(function(name)
		local items = M.buckets[name].items
		if #items == 0 then
			vim.notify("bucket is empty")
			return
		end
		local list = {}
		for _, it in ipairs(items) do
			list[#list + 1] = { text = it.ref, item = it }
		end
		pick_list("Drop from " .. name, list, function(sel)
			local picked = {}
			for _, s in ipairs(sel) do
				picked[#picked + 1] = s.item
			end
			insert_block(blocks_of(picked))
		end, true)
	end)
end

function M.dump()
	M.with_existing(function(name)
		insert_all(name)
	end)
end

-- <leader>sg : go to the ticket buffer and dump the whole bucket at the end
function M.go_dump()
	M.with_existing(function(name)
		M.open_ticket(name)
		vim.cmd("normal! G")
		insert_all(name)
	end)
end

function M.manage()
	M.with_existing(function(name)
		local items = M.buckets[name].items
		if #items == 0 then
			vim.notify("bucket is empty")
			return
		end
		local list = {}
		for i, it in ipairs(items) do
			list[#list + 1] = { text = it.ref, idx = i }
		end
		pick_list("Remove from " .. name, list, function(sel)
			local idxs = {}
			for _, s in ipairs(sel) do
				idxs[#idxs + 1] = s.idx
			end
			table.sort(idxs, function(a, c)
				return a > c
			end)
			for _, i in ipairs(idxs) do
				table.remove(items, i)
			end
			vim.notify(("removed %d from %s"):format(#idxs, name))
			M.refresh()
		end, true)
	end)
end

-- <leader>sc : empty the bucket (keeps the ticket + active state)
function M.clear()
	M.with_existing(function(name)
		local n = #M.buckets[name].items
		if n == 0 then
			vim.notify("bucket already empty")
			return
		end
		if vim.fn.confirm(("Clear %d refs from %s?"):format(n, name), "&Yes\n&No", 2) == 1 then
			M.buckets[name].items = {}
			M.refresh()
			vim.notify("cleared " .. name)
		end
	end)
end

-- lualine surface -----------------------------------------------------------
function M.is_active()
	return M.active ~= nil and M.buckets[M.active] ~= nil
end
function M.label()
	return M.is_active() and ("🪣 " .. M.active) or ""
end
function M.count()
	return M.is_active() and ("·" .. #M.buckets[M.active].items) or ""
end

-- setup ---------------------------------------------------------------------
function M.setup()
	local map = vim.keymap.set
	local nx = { "n", "x" }
	map(nx, "<leader>sn", M.new_ticket, { desc = "Satchel: new ticket+bucket" })
	map(nx, "<leader>se", M.enter_bucket, { desc = "Satchel: enter ticket" })
	map(nx, "<leader>sx", M.leave_bucket, { desc = "Satchel: leave ticket" })
	-- toss is the one that differs by mode: file in normal, selection in visual
	map("n", "<leader>st", M.toss_file, { desc = "Satchel: toss current file" })
	map("x", "<leader>st", M.toss_selection, { desc = "Satchel: toss selection" })
	map(nx, "<leader>sf", M.insert_file_ref, { desc = "Satchel: insert file ref" })
	map(nx, "<leader>sd", M.drop, { desc = "Satchel: drop refs (pick)" })
	map(nx, "<leader>sD", M.dump, { desc = "Satchel: dump at cursor" })
	map(nx, "<leader>sg", M.go_dump, { desc = "Satchel: go to ticket + dump" })
	map(nx, "<leader>ss", M.manage, { desc = "Satchel: manage ticket" })
	map(nx, "<leader>sc", M.clear, { desc = "Satchel: clear bucket" })
end

M.setup()
return M
