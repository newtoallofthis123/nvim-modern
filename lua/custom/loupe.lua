-- loupe — recursive inline call-graph peek.
--
-- <leader>k drills into the definition of the symbol under the cursor and
-- floats it in a stacked overlay, WITHOUT moving your cursor out of where you
-- are. Drill again from inside an overlay and it stacks deeper, each frame
-- offset down-right, dimmed behind the top one. The window title is the
-- breadcrumb of the path you took:  render ▸ build_marks ▸ hl_for_age
--
-- The overlays show the REAL target buffers (bufload, not copies) so LSP keeps
-- working inside them — you can keep drilling from a definition you're peeking.
--
--   <leader>k  drill into the definition under the cursor (deeper if in a frame)
--   q / <BS>   pop the top frame, refocus the one below (or your origin window)
--   Q          collapse the whole stack, cursor untouched
--   <CR>       collapse, then jump the origin window to the top frame's location
--
-- The stack is the single source of truth; everything derives from it.

local M = {}

-- state: M.stack = { {win, buf, symbol, pos = {line0, col0}, maps = {...}}, ... }
-- M.origin = { win, buf } — where the drill began (never a loupe frame).
M.stack = {}
M.origin = nil

local NS_TITLE = "Loupe"
local MAX_DEPTH = 8
local FALLBACK_LINES = 15

-- helpers -------------------------------------------------------------------

local function top()
	return M.stack[#M.stack]
end

-- is `win` one of our live frame windows?
local function frame_of_win(win)
	for _, f in ipairs(M.stack) do
		if f.win == win then
			return f
		end
	end
end

-- the word under the cursor in a given window (the drill's symbol label)
local function word_under(win)
	local buf = vim.api.nvim_win_get_buf(win)
	local pos = vim.api.nvim_win_get_cursor(win)
	local line = vim.api.nvim_buf_get_lines(buf, pos[1] - 1, pos[1], false)[1] or ""
	local col = pos[2] + 1
	-- scan word tokens; return the one covering the cursor column
	local init = 1
	while true do
		local s, e = line:find("[%w_]+", init)
		if not s then
			return nil
		end
		if col >= s and col <= e + 1 then
			return line:sub(s, e)
		end
		init = e + 1
	end
end

-- breadcrumb built from every frame's symbol
local function breadcrumb()
	local names = {}
	for _, f in ipairs(M.stack) do
		names[#names + 1] = f.symbol or "?"
	end
	return " " .. table.concat(names, " ▸ ") .. " "
end

-- treesitter extent (0-indexed inclusive line span) of the enclosing function
-- at (line0, col0) in buf; nil if unavailable.
local function fn_extent(buf, line0, col0)
	local ok, parser = pcall(vim.treesitter.get_parser, buf)
	if not ok or not parser then
		return nil
	end
	parser:parse({ line0, line0 })
	local node = vim.treesitter.get_node({ bufnr = buf, pos = { line0, col0 } })
	while node do
		local t = node:type()
		if t:find("function") or t:find("method") or t:find("declaration") then
			local sr, _, er = node:range()
			return sr, er
		end
		node = node:parent()
	end
	return nil
end

-- dim (or un-dim) a frame's floating window
local function set_dim(f, dim)
	if not (f.win and vim.api.nvim_win_is_valid(f.win)) then
		return
	end
	local hl = dim and "NormalFloat:LoupeDim,FloatBorder:LoupeDim" or "NormalFloat:NormalFloat,FloatBorder:FloatBorder"
	vim.wo[f.win].winhighlight = hl
end

-- re-title every frame with the current breadcrumb; dim all but the top
local function restyle()
	local crumb = breadcrumb()
	for i, f in ipairs(M.stack) do
		if f.win and vim.api.nvim_win_is_valid(f.win) then
			pcall(vim.api.nvim_win_set_config, f.win, { title = crumb, title_pos = "center" })
			set_dim(f, i ~= #M.stack)
		end
	end
end

-- frame maps ----------------------------------------------------------------

-- buffer-local maps live only while the buf is a frame; we track & delete them
-- on pop/close since these are real buffers the user edits elsewhere.
local function set_frame_maps(f)
	local opts = { buffer = f.buf, nowait = true }
	vim.keymap.set("n", "<BS>", M.pop, vim.tbl_extend("force", opts, { desc = "loupe: pop frame" }))
	vim.keymap.set("n", "q", M.pop, vim.tbl_extend("force", opts, { desc = "loupe: pop frame" }))
	vim.keymap.set("n", "Q", M.collapse, vim.tbl_extend("force", opts, { desc = "loupe: collapse stack" }))
	vim.keymap.set("n", "<CR>", M.take_me_there, vim.tbl_extend("force", opts, { desc = "loupe: jump there" }))
	f.maps = { "<BS>", "q", "Q", "<CR>" }
end

local function clear_frame_maps(f)
	if not (f.maps and vim.api.nvim_buf_is_valid(f.buf)) then
		return
	end
	-- only strip our maps if no OTHER live frame shares this buffer
	for _, other in ipairs(M.stack) do
		if other ~= f and other.buf == f.buf then
			return
		end
	end
	for _, lhs in ipairs(f.maps) do
		pcall(vim.keymap.del, "n", lhs, { buffer = f.buf })
	end
	f.maps = nil
end

-- open / close frames -------------------------------------------------------

-- push a frame showing `buf` at (line0, col0), symbol-labelled. Returns frame.
local function push_frame(buf, line0, col0, symbol)
	local depth = #M.stack
	local ed_w, ed_h = vim.o.columns, vim.o.lines

	-- size to the enclosing function's extent, capped at 60% of the editor
	local sr, er = fn_extent(buf, line0, col0)
	local span = (sr and er) and (er - sr + 1) or FALLBACK_LINES
	local h = math.min(math.max(span + 1, 5), math.floor(ed_h * 0.6))
	local w = math.min(math.max(math.floor(ed_w * 0.5), 40), math.floor(ed_w * 0.6))

	-- stagger each deeper frame down-right from the last
	local base_row = math.floor(ed_h * 0.12)
	local base_col = math.floor(ed_w * 0.12)
	local row = math.min(base_row + depth * 2, ed_h - h - 2)
	local col = math.min(base_col + depth * 4, ed_w - w - 2)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.max(row, 0),
		col = math.max(col, 0),
		width = w,
		height = h,
		style = "minimal",
		border = "rounded",
		title = breadcrumb(),
		title_pos = "center",
	})
	vim.wo[win].number = true
	vim.wo[win].cursorline = true
	vim.wo[win].signcolumn = "no"

	-- place cursor on the definition and scroll it near the top
	pcall(vim.api.nvim_win_set_cursor, win, { line0 + 1, col0 })
	vim.api.nvim_win_call(win, function()
		vim.cmd("normal! zt")
	end)

	local f = { win = win, buf = buf, symbol = symbol, pos = { line0, col0 } }
	M.stack[#M.stack + 1] = f
	set_frame_maps(f)
	restyle()
	vim.api.nvim_set_current_win(win)
	return f
end

-- close one frame's window (buffer is real — never wiped)
local function close_frame(f)
	clear_frame_maps(f)
	if f.win and vim.api.nvim_win_is_valid(f.win) then
		pcall(vim.api.nvim_win_close, f.win, true)
	end
end

-- refocus whatever should hold focus now (top frame, else origin window)
local function refocus()
	local t = top()
	if t and vim.api.nvim_win_is_valid(t.win) then
		vim.api.nvim_set_current_win(t.win)
	elseif M.origin and vim.api.nvim_win_is_valid(M.origin.win) then
		vim.api.nvim_set_current_win(M.origin.win)
	end
end

-- public: pop / collapse / jump ---------------------------------------------

function M.pop()
	local f = table.remove(M.stack)
	if not f then
		return
	end
	close_frame(f)
	if #M.stack == 0 then
		M.origin = nil
	else
		restyle()
	end
	refocus()
end

function M.collapse()
	local origin = M.origin
	while #M.stack > 0 do
		close_frame(table.remove(M.stack))
	end
	M.origin = nil
	if origin and vim.api.nvim_win_is_valid(origin.win) then
		vim.api.nvim_set_current_win(origin.win)
	end
end

-- collapse the stack, then jump the origin window to the top frame's location
function M.take_me_there()
	local t = top()
	if not t then
		return
	end
	local target_buf, pos = t.buf, t.pos
	local origin = M.origin
	M.collapse()
	if not (origin and vim.api.nvim_win_is_valid(origin.win)) then
		return
	end
	vim.api.nvim_set_current_win(origin.win)
	vim.cmd("normal! m'") -- seed the jumplist so <C-o> comes back
	vim.api.nvim_win_set_buf(origin.win, target_buf)
	pcall(vim.api.nvim_win_set_cursor, origin.win, { pos[1] + 1, pos[2] })
	vim.cmd("normal! zz")
end

-- drill ---------------------------------------------------------------------

-- already have a frame at this exact (buf, line0, col0)? refocus it if so.
local function existing_frame(buf, line0)
	for _, f in ipairs(M.stack) do
		if f.buf == buf and f.pos[1] == line0 then
			return f
		end
	end
end

local function on_definition(cur_win, symbol, result)
	if not result or vim.tbl_isempty(result) then
		vim.notify("loupe: no definition", vim.log.levels.INFO)
		return
	end
	-- LSP servers return either a single Location or a list of them
	local loc = result[1] or result
	if not loc.uri and not loc.targetUri then
		vim.notify("loupe: no definition", vim.log.levels.INFO)
		return
	end
	local uri = loc.targetUri or loc.uri
	local range = loc.targetSelectionRange or loc.targetRange or loc.range
	local buf = vim.uri_to_bufnr(uri)
	vim.fn.bufload(buf)
	local line0 = range.start.line
	local col0 = range.start.character

	-- "already here": resolves to the cursor position we drilled from
	local cur_buf = vim.api.nvim_win_get_buf(cur_win)
	local cur_pos = vim.api.nvim_win_get_cursor(cur_win)
	if buf == cur_buf and line0 == cur_pos[1] - 1 then
		vim.notify("loupe: already here", vim.log.levels.INFO)
		return
	end

	-- cycle protection: same location already stacked → refocus it
	local hit = existing_frame(buf, line0)
	if hit then
		vim.api.nvim_set_current_win(hit.win)
		return
	end

	if #M.stack >= MAX_DEPTH then
		vim.notify("loupe: max depth", vim.log.levels.WARN)
		return
	end

	push_frame(buf, line0, col0, symbol)
end

-- <leader>k — drill. Works from a normal buffer (opens the stack) or from
-- within a loupe frame (stacks deeper). One global map handles both.
function M.drill()
	local cur_win = vim.api.nvim_get_current_win()
	-- establish origin the first time, from a non-frame window
	if #M.stack == 0 then
		M.origin = { win = cur_win, buf = vim.api.nvim_win_get_buf(cur_win) }
	end
	local symbol = word_under(cur_win) or "?"
	local buf = vim.api.nvim_win_get_buf(cur_win)
	local params = vim.lsp.util.make_position_params(cur_win, "utf-16")

	vim.lsp.buf_request(buf, "textDocument/definition", params, function(err, result)
		if err then
			vim.notify("loupe: " .. tostring(err.message or err), vim.log.levels.WARN)
			return
		end
		-- the window may have changed between request and response; only act if
		-- the drill origin window is still current-ish (guard against surprises)
		if not vim.api.nvim_win_is_valid(cur_win) then
			return
		end
		on_definition(cur_win, symbol, result)
	end)
end

-- guard: user closed a frame window manually → prune the stack -------------
local function prune()
	local pruned = false
	for i = #M.stack, 1, -1 do
		local f = M.stack[i]
		if not (f.win and vim.api.nvim_win_is_valid(f.win)) then
			clear_frame_maps(f)
			table.remove(M.stack, i)
			pruned = true
		end
	end
	if pruned then
		if #M.stack == 0 then
			M.origin = nil
		else
			restyle()
		end
	end
end

-- setup ---------------------------------------------------------------------

function M.setup()
	vim.api.nvim_set_hl(0, "LoupeDim", { fg = "#6e6a86", bg = "NONE", default = true })

	vim.keymap.set("n", "<leader>k", M.drill, { desc = "loupe: drill into definition" })

	local group = vim.api.nvim_create_augroup("Loupe", { clear = true })
	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		callback = function(ev)
			-- WinClosed fires with the closing win still listed; defer the prune
			local closing = tonumber(ev.match)
			if closing and frame_of_win(closing) then
				vim.schedule(prune)
			end
		end,
	})
end

M.setup()
return M
