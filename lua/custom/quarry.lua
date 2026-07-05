-- quarry — quickfix lists as named, persistent, composable objects.
--
-- A quickfix list is a set of file:line hits. quarry lets you name one, keep
-- it across sessions, and do set algebra on it:
--   :Quarry save auth-callers          snapshot the current qflist under a name
--   :Quarry load auth-callers + db - x  union/subtract/intersect named lists
--   :Quarry list                        floating browser (CR loads, dd deletes)
--   :Quarry drop auth-callers           delete a saved list
--
-- In an expression, operands are saved names or `%` (the CURRENT qflist);
-- operators are + (union) - (subtract) ^ (intersect), left-to-right, no
-- precedence. Entry identity for set ops is `filename:lnum`. Lists live under
-- stdpath("data")/quarry/<hash-of-cwd>/<name>.json, so they're per-project.

local M = {}

-- storage -------------------------------------------------------------------
local function root()
	local dir = vim.fn.stdpath("data") .. "/quarry/" .. vim.fn.sha256(vim.fn.getcwd())
	vim.fn.mkdir(dir, "p")
	return dir
end

local function path_of(name)
	return root() .. "/" .. name .. ".json"
end

-- current saved-list names for this project, sorted
local function names()
	local out = {}
	for _, f in ipairs(vim.fn.readdir(root())) do
		local n = f:match("^(.*)%.json$")
		if n then
			out[#out + 1] = n
		end
	end
	table.sort(out)
	return out
end

-- read a saved list → array of {filename, lnum, col, text}, or nil if missing
local function read(name)
	local p = path_of(name)
	if vim.fn.filereadable(p) == 0 then
		return nil
	end
	local ok, data = pcall(vim.fn.json_decode, table.concat(vim.fn.readfile(p), "\n"))
	return ok and data or nil
end

local function write(name, entries)
	vim.fn.writefile({ vim.fn.json_encode(entries) }, path_of(name))
end

-- convert the live qflist (bufnr-based) → filename-based entries we can persist
local function qf_entries()
	local out = {}
	for _, e in ipairs(vim.fn.getqflist()) do
		out[#out + 1] = {
			filename = e.bufnr > 0 and vim.api.nvim_buf_get_name(e.bufnr) or "",
			lnum = e.lnum,
			col = e.col,
			text = e.text,
		}
	end
	return out
end

-- set ops -------------------------------------------------------------------
local function key(e)
	return e.filename .. ":" .. e.lnum
end

-- keep original order/entries; dedupe by key
local function dedupe(entries)
	local seen, out = {}, {}
	for _, e in ipairs(entries) do
		local k = key(e)
		if not seen[k] then
			seen[k] = true
			out[#out + 1] = e
		end
	end
	return out
end

local function union(a, b)
	local out = {}
	vim.list_extend(out, a)
	vim.list_extend(out, b)
	return dedupe(out)
end

local function subtract(a, b)
	local drop = {}
	for _, e in ipairs(b) do
		drop[key(e)] = true
	end
	local out = {}
	for _, e in ipairs(a) do
		if not drop[key(e)] then
			out[#out + 1] = e
		end
	end
	return out
end

local function intersect(a, b)
	local keep = {}
	for _, e in ipairs(b) do
		keep[key(e)] = true
	end
	local out = {}
	for _, e in ipairs(a) do
		if keep[key(e)] then
			out[#out + 1] = e
		end
	end
	return dedupe(out)
end

local OPS = { ["+"] = union, ["-"] = subtract, ["^"] = intersect }

-- resolve one operand (a saved name or `%`) → entries, or error string
local function operand(tok)
	if tok == "%" then
		return qf_entries()
	end
	local e = read(tok)
	if not e then
		return nil, "quarry: unknown list '" .. tok .. "'"
	end
	return e
end

-- evaluate `a + b - c` left-to-right. Returns entries or nil, err.
local function evaluate(expr)
	local toks = vim.split(vim.trim(expr), "%s+", { trimempty = true })
	if #toks == 0 then
		return nil, "quarry: empty expression"
	end
	local acc, err = operand(toks[1])
	if not acc then
		return nil, err
	end
	local i = 2
	while i <= #toks do
		local op = OPS[toks[i]]
		if not op then
			return nil, "quarry: expected operator (+ - ^), got '" .. toks[i] .. "'"
		end
		local rhs = toks[i + 1]
		if not rhs then
			return nil, "quarry: operator '" .. toks[i] .. "' needs a right-hand operand"
		end
		local b
		b, err = operand(rhs)
		if not b then
			return nil, err
		end
		acc = op(acc, b)
		i = i + 2
	end
	return acc
end

-- push entries into the qflist under a title and open the qf window
local function set_qf(entries, title)
	vim.fn.setqflist({}, " ", { title = title, items = entries })
	vim.cmd.copen()
end

-- subcommands ---------------------------------------------------------------
local function save(name)
	if not name or name == "" then
		vim.notify("quarry: save needs a name", vim.log.levels.WARN)
		return
	end
	local entries = qf_entries()
	write(name, entries)
	vim.notify(("quarry: saved %s (%d)"):format(name, #entries))
end

local function load(expr)
	if not expr or expr == "" then
		vim.notify("quarry: load needs a name or expression", vim.log.levels.WARN)
		return
	end
	local entries, err = evaluate(expr)
	if not entries then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end
	set_qf(entries, "quarry: " .. expr)
end

local function drop(name)
	if not name or name == "" then
		vim.notify("quarry: drop needs a name", vim.log.levels.WARN)
		return
	end
	if vim.fn.filereadable(path_of(name)) == 0 then
		vim.notify("quarry: unknown list '" .. name .. "'", vim.log.levels.WARN)
		return
	end
	vim.fn.delete(path_of(name))
	vim.notify("quarry: dropped " .. name)
end

-- relative age of a saved list, from file mtime
local function age(name)
	local secs = os.time() - vim.fn.getftime(path_of(name))
	if secs < 60 then
		return secs .. "s"
	elseif secs < 3600 then
		return math.floor(secs / 60) .. "m"
	elseif secs < 86400 then
		return math.floor(secs / 3600) .. "h"
	else
		return math.floor(secs / 86400) .. "d"
	end
end

-- floating browser ----------------------------------------------------------
local function list()
	local ns = names()
	if #ns == 0 then
		vim.notify("quarry: no saved lists for this project")
		return
	end
	local rows, lines = {}, {}
	for _, n in ipairs(ns) do
		local count = #(read(n) or {})
		rows[#rows + 1] = n
		lines[#lines + 1] = ("%-30s %4d  %s"):format(n, count, age(n))
	end

	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, #l)
	end
	width = math.max(width + 2, 30)
	local height = #lines

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " quarry ",
	})

	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end

	local function name_here()
		return rows[vim.api.nvim_win_get_cursor(win)[1]]
	end

	vim.keymap.set("n", "q", close, { buffer = buf })
	vim.keymap.set("n", "<Esc>", close, { buffer = buf })
	vim.keymap.set("n", "<CR>", function()
		local n = name_here()
		close()
		if n then
			load(n)
		end
	end, { buffer = buf })
	vim.keymap.set("n", "dd", function()
		local n = name_here()
		if not n then
			return
		end
		drop(n)
		local row = vim.api.nvim_win_get_cursor(win)[1]
		table.remove(rows, row)
		table.remove(lines, row)
		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.bo[buf].modifiable = false
		if #rows == 0 then
			close()
		end
	end, { buffer = buf })
end

-- command + completion ------------------------------------------------------
local SUBS = { "save", "load", "list", "drop" }

local function dispatch(opts)
	local args = opts.fargs
	local sub = args[1]
	local rest = table.concat(vim.list_slice(args, 2), " ")
	if sub == "save" then
		save(rest)
	elseif sub == "load" then
		load(rest)
	elseif sub == "list" then
		list()
	elseif sub == "drop" then
		drop(rest)
	else
		vim.notify("quarry: usage — save|load|list|drop", vim.log.levels.WARN)
	end
end

local function complete(arglead, cmdline)
	local parts = vim.split(vim.trim(cmdline), "%s+", { trimempty = true })
	-- completing the subcommand itself
	if #parts <= 1 or (#parts == 2 and arglead ~= "") then
		return vim.tbl_filter(function(s)
			return s:find(arglead, 1, true) == 1
		end, SUBS)
	end
	-- load/drop take saved-list names
	local sub = parts[2]
	if sub == "load" or sub == "drop" then
		local out = {}
		for _, n in ipairs(names()) do
			if n:find(arglead, 1, true) == 1 then
				out[#out + 1] = n
			end
		end
		return out
	end
	return {}
end

vim.api.nvim_create_user_command("Quarry", dispatch, {
	nargs = "*",
	complete = complete,
	desc = "Named, persistent, composable quickfix lists",
})

return M
