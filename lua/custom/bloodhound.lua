-- bloodhound — feed it a stack trace, it takes you hunting.
--
-- :Bloodhound        parse the + register (clipboard)
-- :Bloodhound a      parse a single-char register instead (a, ", 0, …)
-- :'<,'>Bloodhound   parse the selected lines
--
-- Every frame becomes a quickfix entry; the window opens and the cursor lands
-- on the first RESOLVED project frame. Formats (python/elixir/js/go/rust) are
-- auto-detected by running every parser and keeping the one with most hits;
-- a generic file:line sweep is the fallback when nothing specific bites.
-- The qf list is always deepest-frame-first (python's order gets reversed).
-- Paths are dragged out of container/CI prefixes by stripping leading dirs
-- and, as a last resort, a basename findfile.

local M = {}

-- path resolution -----------------------------------------------------------
-- alien prefixes from containers/CI: /app/lib/foo.ex must find lib/foo.ex.
local function resolve(path)
	if not path or path == "" then
		return nil
	end
	if vim.fn.filereadable(path) == 1 then
		return path
	end
	local cwd = vim.fn.getcwd()
	local rel = cwd .. "/" .. path
	if vim.fn.filereadable(rel) == 1 then
		return rel
	end
	-- strip leading components one at a time, test remainder against cwd
	local parts = vim.split(path, "/", { plain = true })
	for i = 2, math.min(#parts, 7) do
		local sub = table.concat(vim.list_slice(parts, i, #parts), "/")
		local cand = cwd .. "/" .. sub
		if vim.fn.filereadable(cand) == 1 then
			return cand
		end
	end
	-- last resort: basename with one parent dir, searched anywhere below cwd
	local base = vim.fn.fnamemodify(path, ":t")
	local parent = vim.fn.fnamemodify(path, ":h:t")
	local needle = (parent ~= "" and parent ~= ".") and (parent .. "/" .. base) or base
	local found = vim.fn.findfile(needle, "**")
	if found ~= "" then
		return found
	end
	return nil
end

local DEP_PAT = { "/deps/", "node_modules", "site%-packages", "%.cargo" }
local function is_dep(path)
	for _, pat in ipairs(DEP_PAT) do
		if path:find(pat) then
			return true
		end
	end
	return false
end

-- parsers: each returns frames {path, lnum, col?, text} deepest-frame-first --
local function parse_python(lines)
	local frames = {}
	for i, line in ipairs(lines) do
		local path, lnum = line:match('^%s*File "([^"]+)", line (%d+)')
		if path then
			local func = line:match(", in (.+)$")
			local src = lines[i + 1]
			local ctx = func or ""
			if src and not src:match('^%s*File "') and vim.trim(src) ~= "" then
				ctx = (func and (func .. " — ") or "") .. vim.trim(src)
			end
			frames[#frames + 1] = { path = path, lnum = tonumber(lnum), text = vim.trim(ctx) }
		end
	end
	-- python lists the deepest frame LAST → reverse to deepest-first
	local rev = {}
	for i = #frames, 1, -1 do
		rev[#rev + 1] = frames[i]
	end
	return rev
end

local function parse_elixir(lines)
	local frames = {}
	for _, line in ipairs(lines) do
		local path, lnum, rest = line:match("([%w%._/%-]+%.exs?):(%d+):?%s*(.*)")
		if path then
			frames[#frames + 1] = { path = path, lnum = tonumber(lnum), text = vim.trim(rest) }
		end
	end
	return frames -- elixir already lists deepest-first
end

local function strip_webpack(p)
	p = p:gsub("^webpack%-internal:///?", "")
	p = p:gsub("^webpack://[^/]*/?%.?/?", "")
	return p
end

local function parse_js(lines)
	local frames = {}
	for _, line in ipairs(lines) do
		if line:match("^%s*at%s") then
			local func, loc = line:match("^%s*at%s+(.-)%s*%((.-)%)%s*$")
			if not loc then
				loc = line:match("^%s*at%s+(.+)$")
				func = nil
			end
			if loc then
				loc = strip_webpack(loc)
				local path, lnum, col = loc:match("^(.+):(%d+):(%d+)$")
				if not path then
					path, lnum = loc:match("^(.+):(%d+)$")
				end
				if path then
					frames[#frames + 1] =
						{ path = path, lnum = tonumber(lnum), col = tonumber(col), text = vim.trim(func or "") }
				end
			end
		end
	end
	return frames -- js lists the innermost frame first
end

local function parse_go(lines)
	local frames = {}
	for i, line in ipairs(lines) do
		local path, lnum = line:match("([%w%._/%-]+%.go):(%d+)")
		if path then
			local prev = lines[i - 1]
			frames[#frames + 1] = { path = path, lnum = tonumber(lnum), text = prev and vim.trim(prev) or "" }
		end
	end
	return frames -- go lists deepest-first
end

local function parse_rust(lines)
	local frames = {}
	for i, line in ipairs(lines) do
		local path, lnum, col = line:match("at%s+([%w%._/%-]+%.rs):(%d+):?(%d*)")
		if path then
			local prev = lines[i - 1]
			local func = prev and prev:match("^%s*%d+:%s*(.+)$")
			frames[#frames + 1] =
				{ path = path, lnum = tonumber(lnum), col = tonumber(col), text = vim.trim(func or "") }
		end
	end
	return frames -- rust backtrace frame 0 is deepest, listed first
end

local function parse_generic(lines)
	local frames = {}
	for _, line in ipairs(lines) do
		for path, lnum in line:gmatch("([%w_./%-]+%.%w+):(%d+)") do
			frames[#frames + 1] = { path = path, lnum = tonumber(lnum), text = vim.trim(line) }
		end
	end
	return frames
end

local PARSERS = {
	{ name = "python", fn = parse_python },
	{ name = "elixir", fn = parse_elixir },
	{ name = "javascript", fn = parse_js },
	{ name = "go", fn = parse_go },
	{ name = "rust", fn = parse_rust },
}

local function detect(lines)
	local best, best_name, best_n = {}, "none", 0
	for _, p in ipairs(PARSERS) do
		local frames = p.fn(lines)
		if #frames > best_n then
			best, best_name, best_n = frames, p.name, #frames
		end
	end
	-- generic sweep only when no specific format scored ≥2 frames
	if best_n < 2 then
		local g = parse_generic(lines)
		if #g > best_n then
			return g, "generic"
		end
	end
	return best, best_name
end

-- build qf items, preserving order; pick the auto-jump target --------------
local function build(frames)
	local items = {}
	local first_proj, first_dep = nil, nil
	for idx, f in ipairs(frames) do
		local resolved = resolve(f.path)
		items[#items + 1] = {
			filename = resolved or f.path,
			lnum = f.lnum or 1,
			col = f.col or 0,
			text = (f.text and f.text ~= "") and f.text or f.path,
			valid = resolved and 1 or 0,
		}
		if resolved then
			if is_dep(resolved) or is_dep(f.path) then
				first_dep = first_dep or idx
			else
				first_proj = first_proj or idx
			end
		end
	end
	return items, first_proj or first_dep
end

-- entry ---------------------------------------------------------------------
local function run(opts)
	local lines
	if opts.range and opts.range > 0 then
		lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
	else
		local reg = (opts.fargs and opts.fargs[1]) or "+"
		lines = vim.split(vim.fn.getreg(reg) or "", "\n", { plain = true })
	end

	local frames, fmt = detect(lines)
	if #frames == 0 then
		vim.notify("bloodhound: no trace scent", vim.log.levels.WARN)
		return
	end

	local items, target = build(frames)
	local resolved_n = 0
	for _, it in ipairs(items) do
		resolved_n = resolved_n + it.valid
	end

	local first = ""
	for _, l in ipairs(lines) do
		if vim.trim(l) ~= "" then
			first = vim.trim(l)
			break
		end
	end
	vim.fn.setqflist({}, " ", { title = "bloodhound: " .. first:sub(1, 60), items = items })
	vim.cmd("copen")
	pcall(vim.cmd, target and ("cc " .. target) or "cfirst")

	vim.notify(("🐕 bloodhound: %d frames (%s), %d resolved"):format(#items, fmt, resolved_n))
end

function M.setup()
	vim.api.nvim_create_user_command("Bloodhound", run, {
		nargs = "?",
		range = true,
		desc = "Parse a stack trace into quickfix and jump to the top frame",
	})
end

M.setup()
return M
