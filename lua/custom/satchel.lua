-- satchel — a ticket-writer's context basket.
--
-- You work in named *buckets*. "Enter" a bucket and everything you toss flows
-- into it silently; while writing the ticket, drop those refs at your cursor.
-- Refs use your @path#L40-58 convention; selections carry a fenced code block.
-- Session-only (v1). Pickers reuse snacks; formatting reuses custom/copy.
local copy = require("custom.copy")

local M = {}

-- state ---------------------------------------------------------------------
M.buckets = {} -- { [name] = { item, item, ... } }   item = {ref, code?, ft?}
M.active = nil -- name | nil

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

local function add_item(name, item)
	table.insert(M.buckets[name], item)
	M.refresh()
end

local function toast(name)
	vim.notify(("🪣 %s ·%d"):format(name, #M.buckets[name]))
end

-- render an item into ticket lines: the ref, then an optional fenced block
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

-- a tiny list picker (snacks if present, else vim.ui.select) -----------------
local function pick_list(title, items, on_confirm, multi)
	if not (Snacks and Snacks.picker) then
		vim.ui.select(items, {
			prompt = title,
			format_item = function(i)
				return i.text
			end,
		}, function(choice)
			if choice then
				on_confirm({ choice })
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

-- bucket lifecycle ----------------------------------------------------------
function M.create_bucket(after)
	vim.ui.input({ prompt = "New bucket name: " }, function(name)
		if not name or name == "" then
			return
		end
		M.buckets[name] = M.buckets[name] or {}
		M.set_active(name)
		vim.notify("🪣 entered bucket: " .. name)
		if after then
			after(name)
		end
	end)
end

function M.enter_bucket()
	local names = vim.tbl_keys(M.buckets)
	if #names == 0 then
		return M.create_bucket()
	end
	local items = {}
	for _, n in ipairs(names) do
		items[#items + 1] = { text = n, name = n }
	end
	items[#items + 1] = { text = "＋ new bucket…", new = true }
	pick_list("Enter bucket", items, function(sel)
		local it = sel and sel[1]
		if not it then
			return
		end
		if it.new then
			M.create_bucket()
		else
			M.set_active(it.name)
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

-- resolve a target bucket for TOSSING (active, else pick or create) ----------
function M.with_bucket(cb)
	if M.active and M.buckets[M.active] then
		return cb(M.active)
	end
	local names = vim.tbl_keys(M.buckets)
	if #names == 0 then
		return M.create_bucket(cb)
	end
	local items = {}
	for _, n in ipairs(names) do
		items[#items + 1] = { text = n, name = n }
	end
	items[#items + 1] = { text = "＋ new bucket…", new = true }
	pick_list("Toss into", items, function(sel)
		local it = sel and sel[1]
		if not it then
			return
		end
		if it.new then
			M.create_bucket(cb)
		else
			M.set_active(it.name)
			cb(it.name)
		end
	end)
end

-- resolve a target bucket for DROP/DUMP/MANAGE (must already exist) ----------
function M.with_existing(cb)
	if M.active and M.buckets[M.active] then
		return cb(M.active)
	end
	local names = vim.tbl_keys(M.buckets)
	if #names == 0 then
		vim.notify("no buckets yet — toss something first", vim.log.levels.WARN)
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
-- instant: pick any file, drop its @ref at the cursor (no bucket needed)
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

local function blocks_of(items)
	local lines = {}
	for _, it in ipairs(items) do
		for _, l in ipairs(render(it)) do
			lines[#lines + 1] = l
		end
		lines[#lines + 1] = ""
	end
	if #lines > 0 then
		table.remove(lines) -- drop trailing blank
	end
	return lines
end

function M.drop()
	M.with_existing(function(name)
		local b = M.buckets[name]
		if #b == 0 then
			vim.notify("bucket is empty")
			return
		end
		local items = {}
		for _, it in ipairs(b) do
			items[#items + 1] = { text = it.ref, item = it }
		end
		pick_list("Drop from " .. name, items, function(sel)
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
		local b = M.buckets[name]
		if #b == 0 then
			vim.notify("bucket is empty")
			return
		end
		insert_block(blocks_of(b))
	end)
end

function M.manage()
	M.with_existing(function(name)
		local b = M.buckets[name]
		if #b == 0 then
			vim.notify("bucket is empty")
			return
		end
		local items = {}
		for i, it in ipairs(b) do
			items[#items + 1] = { text = it.ref, idx = i }
		end
		pick_list("Remove from " .. name, items, function(sel)
			local idxs = {}
			for _, s in ipairs(sel) do
				idxs[#idxs + 1] = s.idx
			end
			table.sort(idxs, function(a, c)
				return a > c
			end)
			for _, i in ipairs(idxs) do
				table.remove(b, i)
			end
			vim.notify(("removed %d from %s"):format(#idxs, name))
			M.refresh()
		end, true)
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
	return M.is_active() and ("·" .. #M.buckets[M.active]) or ""
end

-- setup ---------------------------------------------------------------------
function M.setup()
	local map = vim.keymap.set
	map("n", "<leader>sn", M.create_bucket, { desc = "Satchel: new bucket" })
	map("n", "<leader>se", M.enter_bucket, { desc = "Satchel: enter bucket" })
	map("n", "<leader>sx", M.leave_bucket, { desc = "Satchel: leave bucket" })
	map("n", "<leader>st", M.toss_file, { desc = "Satchel: toss current file" })
	map("x", "<leader>st", M.toss_selection, { desc = "Satchel: toss selection" })
	map("n", "<leader>sf", M.insert_file_ref, { desc = "Satchel: insert file ref" })
	map("n", "<leader>sd", M.drop, { desc = "Satchel: drop refs" })
	map("n", "<leader>sD", M.dump, { desc = "Satchel: dump bucket" })
	map("n", "<leader>ss", M.manage, { desc = "Satchel: manage bucket" })
end

M.setup()
return M
