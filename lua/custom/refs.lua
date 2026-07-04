-- refs.lua — make @file#Lnn refs first-class citizens.
--
-- The whole toolchain speaks `@path#L12-20` (copy.lua writes them, satchel
-- tickets collect them, agents receive them) but nvim couldn't FOLLOW one.
-- Now it can:
--   gf          on an @ref → jump to that file:line (falls back to native gf)
--   <leader>nr  load every @ref in the buffer into quickfix — a ticket
--               becomes a navigable worklist
--
-- Accepted forms: @path, @path#12, @path#L12, @path#12-20, @path#L12-20.
-- Paths resolve against cwd first, then the git root.

local M = {}

-- Parse one ref out of a string. Returns path, start-line (or nil).
local function parse(str)
	local path, anchor = str:match("^@([^%s#]+)#L?(%d+)")
	if path then
		return path, tonumber(anchor)
	end
	path = str:match("^@([^%s#]+)")
	return path, nil
end

local function resolve(path)
	if vim.fn.filereadable(path) == 1 then
		return path
	end
	local root = vim.fs.root(0, ".git")
	if root then
		local p = root .. "/" .. path
		if vim.fn.filereadable(p) == 1 then
			return p
		end
	end
	return nil
end

-- The @ref token under the cursor, if any.
local function ref_under_cursor()
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2] + 1
	-- scan @-tokens; pick the one whose span covers the cursor
	local init = 1
	while true do
		local s, e = line:find("@[^%s]+", init)
		if not s then
			return nil
		end
		if col >= s and col <= e then
			return line:sub(s, e)
		end
		init = e + 1
	end
end

function M.follow()
	local token = ref_under_cursor()
	if token then
		local path, lnum = parse(token)
		local file = path and resolve(path)
		if file then
			vim.cmd.edit(vim.fn.fnameescape(file))
			if lnum then
				pcall(vim.api.nvim_win_set_cursor, 0, { lnum, 0 })
				vim.cmd("normal! zz")
			end
			return
		end
	end
	-- not an @ref (or unresolvable) → behave like plain gf
	local ok, err = pcall(vim.cmd, "normal! gf")
	if not ok then
		vim.notify(err:gsub("^Vim[^:]*:", ""), vim.log.levels.WARN)
	end
end

-- Every @ref in the buffer → quickfix, in order of appearance.
function M.buffer_to_qf()
	local items = {}
	for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
		for token in line:gmatch("@[^%s]+") do
			local path, lnum = parse(token)
			local file = path and resolve(path)
			if file then
				table.insert(items, {
					filename = file,
					lnum = lnum or 1,
					text = ("%s (ref at line %d)"):format(token, i),
				})
			end
		end
	end
	if #items == 0 then
		vim.api.nvim_echo({ { "refs: no resolvable @refs in buffer", "Comment" } }, false, {})
		return
	end
	vim.fn.setqflist({}, " ", { title = "@refs: " .. vim.fn.expand("%:t"), items = items })
	vim.cmd.copen()
end

-- ── Live link highlighting ───────────────────────────────────────────
-- In markdown/gitcommit buffers, @refs render as hyperlinks: iris +
-- underline when the path resolves, muted + strikethrough when it
-- doesn't (dead-link detection while you type the ticket). Tokens that
-- don't look like paths (no "/" — e.g. "@noob") are left alone.

local ns = vim.api.nvim_create_namespace("refs_links")

local function set_hl()
	vim.api.nvim_set_hl(0, "RefsLink", { fg = "#c4a7e7", underline = true })
	vim.api.nvim_set_hl(0, "RefsBroken", { fg = "#6e6a86", strikethrough = true })
end

local function highlight_buf(buf)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		local init = 1
		while true do
			local s, e = line:find("@[^%s]+", init)
			if not s then
				break
			end
			local token = line:sub(s, e)
			local path = parse(token)
			if path and path:find("/", 1, true) then
				vim.api.nvim_buf_set_extmark(buf, ns, i - 1, s - 1, {
					end_col = e,
					hl_group = resolve(path) and "RefsLink" or "RefsBroken",
				})
			end
			init = e + 1
		end
	end
end

local function attach_links(buf)
	highlight_buf(buf)
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = buf,
		group = vim.api.nvim_create_augroup("RefsLinks" .. buf, { clear = true }),
		callback = function()
			highlight_buf(buf)
		end,
	})
end

function M.setup()
	vim.keymap.set("n", "gf", M.follow, { desc = "Go to file / @ref under cursor" })
	vim.keymap.set("n", "<leader>nr", M.buffer_to_qf, { desc = "@refs in buffer → quickfix" })

	set_hl()
	local group = vim.api.nvim_create_augroup("RefsSetup", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_hl })
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = { "markdown", "gitcommit" },
		callback = function(ev)
			attach_links(ev.buf)
		end,
	})
end

return M
