-- crossfire.lua — every callsite of a symbol, on screen at once.
--
-- LSP "find references" dumps you in a quickfix list you page through one at a
-- time, losing the shape of the thing. crossfire fires <leader>m and tiles the
-- editor with live mini-windows — one per callsite, each scrolled so the call
-- sits centred and lit. Read them all in a glance; press a digit to leap to
-- one (jumplist-safe), ]p/[p to page when there are more than nine, q/<Esc> to
-- fold it all away. 0 refs → a note; 1 ref → just jump, no ceremony.
--
-- Cells are non-focusable in v1: the interaction is jump-or-close, so window
-- management stays trivial. No external dependencies.

local M = {}

local ns = vim.api.nvim_create_namespace("crossfire")

-- live grid state, or nil when nothing is up
-- { refs = {...}, page = 0, wins = {win,...}, bufs = {[buf]=true},
--   origin = win, saved = { [key] = maparg|false } }
local M_state = nil

local GAP = 1 -- gutter (rows/cols) between cells

-- layouts by page size: {cols, rows}, capacity cols*rows, max 9 -------------
local function layout_for(n)
	if n <= 2 then
		return 2, 1
	elseif n <= 4 then
		return 2, 2
	elseif n <= 6 then
		return 3, 2
	else
		return 3, 3
	end
end

local function page_size()
	return 9
end

-- normalise LSP Location / LocationLink into { uri, line0, col0 } -------------
local function norm_location(loc)
	local uri = loc.uri or loc.targetUri
	local range = loc.range or loc.targetSelectionRange or loc.targetRange
	if not (uri and range) then
		return nil
	end
	return { uri = uri, line0 = range.start.line, col0 = range.start.character }
end

-- ── highlight groups ────────────────────────────────────────────────
local function set_hl()
	-- dim the surrounding buffer text; let the callsite line pop
	vim.api.nvim_set_hl(0, "CrossfireDim", { link = "Comment", default = true })
	vim.api.nvim_set_hl(0, "CrossfireHit", { link = "Visual", default = true })
	vim.api.nvim_set_hl(0, "CrossfireTitle", { link = "Title", default = true })
end

-- ── teardown ─────────────────────────────────────────────────────────
-- One close() to rule them all: kill wins, clear extmarks, restore maps.
-- Every path (q, <Esc>, digit-jump, WinClosed, VimResized) funnels here.
local function restore_maps(st)
	for key, prev in pairs(st.saved) do
		pcall(vim.keymap.del, "n", key)
		if type(prev) == "table" and prev.rhs then
			pcall(vim.keymap.set, "n", key, prev.rhs, {
				silent = prev.silent == 1,
				noremap = prev.noremap == 1,
				expr = prev.expr == 1,
				desc = prev.desc,
			})
		elseif type(prev) == "table" and prev.callback then
			pcall(vim.keymap.set, "n", key, prev.callback, { silent = prev.silent == 1, desc = prev.desc })
		end
	end
end

local function close()
	if not M_state then
		return
	end
	local st = M_state
	M_state = nil -- flip first so autocmds/WinClosed don't re-enter
	if st.aug then
		pcall(vim.api.nvim_del_augroup_by_id, st.aug)
	end
	for _, win in ipairs(st.wins) do
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end
	for buf in pairs(st.bufs) do
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_clear_namespace, buf, ns, 0, -1)
		end
	end
	restore_maps(st)
end

-- ── grid geometry ─────────────────────────────────────────────────────
-- Tile the editor area (below tabline, above cmdline) into cols×rows cells
-- with GAP-wide gutters. Returns a list of {row,col,width,height}.
local function cells(cols, rows, count)
	local total_w = vim.o.columns
	local total_h = vim.o.lines - vim.o.cmdheight - 1 -- leave the statusline row
	local cell_w = math.floor((total_w - GAP * (cols + 1)) / cols)
	local cell_h = math.floor((total_h - GAP * (rows + 1)) / rows)
	local out = {}
	for i = 0, count - 1 do
		local r = math.floor(i / cols)
		local c = i % cols
		out[#out + 1] = {
			col = GAP + c * (cell_w + GAP),
			row = GAP + r * (cell_h + GAP),
			width = math.max(cell_w, 10),
			height = math.max(cell_h, 3),
		}
	end
	return out
end

-- ── render one page ───────────────────────────────────────────────────
local function render()
	local st = M_state
	-- close existing windows / clear old highlights before re-tiling
	for _, win in ipairs(st.wins) do
		if vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end
	for buf in pairs(st.bufs) do
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_clear_namespace, buf, ns, 0, -1)
		end
	end
	st.wins = {}
	st.bufs = {}

	local per = page_size()
	local pages = math.ceil(#st.refs / per)
	local start = st.page * per
	local shown = math.min(per, #st.refs - start)
	local cols, rows = layout_for(shown)
	local geom = cells(cols, rows, shown)

	for i = 1, shown do
		local ref = st.refs[start + i]
		local g = geom[i]
		local fname = vim.uri_to_fname(ref.uri)
		local buf = vim.fn.bufadd(fname)
		vim.fn.bufload(buf)
		st.bufs[buf] = true

		local n_lines = vim.api.nvim_buf_line_count(buf)
		local line1 = math.min(ref.line0 + 1, n_lines)
		local title = (" %d · %s:%d "):format(start + i, vim.fn.fnamemodify(fname, ":t"), line1)
		local footer = (pages > 1) and (" page %d/%d "):format(st.page + 1, pages) or nil

		local win = vim.api.nvim_open_win(buf, false, {
			relative = "editor",
			row = g.row,
			col = g.col,
			width = g.width,
			height = g.height,
			focusable = false,
			style = "minimal",
			border = "rounded",
			title = title,
			title_pos = "left",
			footer = footer,
			footer_pos = footer and "right" or nil,
			noautocmd = true,
		})
		st.wins[#st.wins + 1] = win

		-- centre the callsite line, dim everything but it
		vim.api.nvim_win_set_cursor(win, { line1, 0 })
		vim.api.nvim_win_call(win, function()
			vim.cmd("normal! zz")
		end)
		vim.wo[win].winhighlight = "Normal:CrossfireDim,NormalNC:CrossfireDim,FloatBorder:CrossfireTitle,FloatTitle:CrossfireTitle"
		vim.wo[win].cursorline = false
		vim.wo[win].number = true
		vim.wo[win].relativenumber = false
		-- light the callsite line via a window-local line highlight
		vim.api.nvim_buf_set_extmark(buf, ns, line1 - 1, 0, {
			line_hl_group = "CrossfireHit",
			hl_eol = true,
		})
	end

	if pages > 1 then
		vim.notify(("crossfire: page %d/%d"):format(st.page + 1, pages))
	end
end

-- ── jump / paging ─────────────────────────────────────────────────────
local function jump(idx)
	local st = M_state
	local ref = st.refs[idx]
	if not ref then
		return
	end
	local win = st.origin
	close()
	if not (win and vim.api.nvim_win_is_valid(win)) then
		win = vim.api.nvim_get_current_win()
	end
	vim.api.nvim_set_current_win(win)
	vim.cmd("normal! m'") -- jumplist first
	vim.cmd.edit(vim.fn.fnameescape(vim.uri_to_fname(ref.uri)))
	pcall(vim.api.nvim_win_set_cursor, 0, { ref.line0 + 1, ref.col0 })
	vim.cmd("normal! zz")
end

local function page(delta)
	local st = M_state
	local pages = math.ceil(#st.refs / page_size())
	local np = st.page + delta
	if np < 0 or np >= pages then
		return
	end
	st.page = np
	render()
end

-- ── temporary global maps while the grid is up ────────────────────────
local function bind(key, fn)
	M_state.saved[key] = vim.fn.maparg(key, "n", false, true)
	if vim.tbl_isempty(M_state.saved[key]) then
		M_state.saved[key] = false
	end
	vim.keymap.set("n", key, fn, { silent = true, desc = "crossfire" })
end

local function open(refs, origin)
	M_state = {
		refs = refs,
		page = 0,
		wins = {},
		bufs = {},
		origin = origin,
		saved = {},
	}
	for d = 1, 9 do
		bind(tostring(d), function()
			-- digit is relative to the current page
			jump(M_state.page * page_size() + d)
		end)
	end
	bind("]p", function()
		page(1)
	end)
	bind("[p", function()
		page(-1)
	end)
	bind("q", close)
	bind("<Esc>", close)

	local aug = vim.api.nvim_create_augroup("Crossfire", { clear = true })
	M_state.aug = aug
	vim.api.nvim_create_autocmd("VimResized", { group = aug, callback = close })
	vim.api.nvim_create_autocmd("WinClosed", {
		group = aug,
		callback = function(ev)
			if not M_state then
				return
			end
			local w = tonumber(ev.match)
			for _, win in ipairs(M_state.wins) do
				if win == w then
					-- one of ours vanished (user or system) → tear down
					vim.schedule(close)
					return
				end
			end
		end,
	})

	render()
end

-- ── entrypoint: <leader>m ─────────────────────────────────────────────
function M.fire()
	if M_state then
		close()
		return
	end
	local params = vim.lsp.util.make_position_params(0, "utf-8")
	params.context = { includeDeclaration = false }
	local origin = vim.api.nvim_get_current_win()
	vim.lsp.buf_request(0, "textDocument/references", params, function(err, result)
		if err then
			vim.notify("crossfire: " .. tostring(err.message or err), vim.log.levels.ERROR)
			return
		end
		local refs = {}
		for _, loc in ipairs(result or {}) do
			local n = norm_location(loc)
			if n then
				refs[#refs + 1] = n
			end
		end
		if #refs == 0 then
			vim.notify("crossfire: no callsites", vim.log.levels.INFO)
			return
		end
		if #refs == 1 then
			local r = refs[1]
			vim.cmd("normal! m'")
			vim.cmd.edit(vim.fn.fnameescape(vim.uri_to_fname(r.uri)))
			pcall(vim.api.nvim_win_set_cursor, 0, { r.line0 + 1, r.col0 })
			vim.cmd("normal! zz")
			return
		end
		open(refs, origin)
	end)
end

function M.setup()
	set_hl()
	vim.api.nvim_create_autocmd("ColorScheme", { callback = set_hl })
	vim.keymap.set("n", "<leader>m", M.fire, { desc = "crossfire: callsite grid" })
end

M.setup()
return M
