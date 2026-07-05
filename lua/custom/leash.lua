-- leash — pin a reference to a corner float, then go wander anywhere.
--
-- <leader>L pins the current line's region (visual: the selection) into a small
-- float in the top-right corner. The float shows the REAL buffer windowed to the
-- pinned region — loupe's trick — so it stays live as you edit, even from another
-- file. A thumbtack, deliberately dumb.
--
-- The region is anchored with an EXTMARK, not a line number: add or remove lines
-- above it and the leash keeps showing the same logical content, re-derived from
-- the extmark each refresh. Pins stack downward from the corner, newest below.
--
--   <leader>L   pin the line/selection (INSIDE an existing pin → toggle it off)
--   :Leash      pin at cursor
--   :Leash x    clear every pin
--
-- No config, no persistence. The pin list is the single source of truth.

local M = {}

-- state: M.pins[i] = { buf, file, span, mark_id, win, cfg, view }
M.pins = {}

local ns = vim.api.nvim_create_namespace("leash")
local timer = nil

local MAXH = 12 -- float height cap (lines)
local PAD = 1 -- context lines shown each side of the region

-- helpers -------------------------------------------------------------------

local function float_width()
	return math.min(60, math.floor(vim.o.columns / 2))
end

-- live 0-indexed start row of a pin's region, or nil if the extmark is gone
local function mark_row(p)
	local m = vim.api.nvim_buf_get_extmark_by_id(p.buf, ns, p.mark_id, { details = true })
	if not m or not m[1] then
		return nil
	end
	if m[3] and m[3].invalid then
		return nil
	end
	return m[1]
end

local function stop_timer()
	if timer then
		timer:stop()
		timer:close()
		timer = nil
	end
end

local function ensure_timer()
	if timer then
		return
	end
	timer = (vim.uv or vim.loop).new_timer()
	timer:start(500, 500, vim.schedule_wrap(M.refresh))
end

-- drop / clear --------------------------------------------------------------

function M.drop(p)
	for i, q in ipairs(M.pins) do
		if q == p then
			table.remove(M.pins, i)
			break
		end
	end
	if p.win and vim.api.nvim_win_is_valid(p.win) then
		pcall(vim.api.nvim_win_close, p.win, true)
	end
	if vim.api.nvim_buf_is_valid(p.buf) then
		pcall(vim.api.nvim_buf_del_extmark, p.buf, ns, p.mark_id)
	end
	if #M.pins == 0 then
		stop_timer()
	end
end

function M.clear()
	while #M.pins > 0 do
		M.drop(M.pins[#M.pins])
	end
end

-- refresh -------------------------------------------------------------------

-- recompute every pin's float config + scroll from its extmark. Cheap: only
-- touches nvim when a value actually changed. Prunes dead pins as it goes.
function M.refresh()
	local width = float_width()
	local col = math.max(vim.o.columns - width - 2, 0)
	local row = 1
	for _, p in ipairs({ unpack(M.pins) }) do
		if not vim.api.nvim_buf_is_valid(p.buf) then
			M.drop(p)
		elseif not (p.win and vim.api.nvim_win_is_valid(p.win)) then
			M.drop(p) -- user closed the float manually
		else
			local srow = mark_row(p)
			if not srow then
				vim.notify("leash: reference gone", vim.log.levels.INFO)
				M.drop(p)
			else
				local height = math.min(p.span + 2 * PAD, MAXH)
				local lnum = srow + 1
				local cfg = {
					relative = "editor",
					row = row,
					col = col,
					width = width,
					height = height,
					style = "minimal",
					border = "rounded",
					focusable = false,
					title = string.format(" 🐕 %s:%d ", p.file, lnum),
					title_pos = "center",
				}
				local sig = table.concat({ row, col, width, height, cfg.title }, ":")
				if p.cfg ~= sig then
					pcall(vim.api.nvim_win_set_config, p.win, cfg)
					p.cfg = sig
				end
				-- window the float to the region with one context line above
				local view = { topline = math.max(srow, 1), lnum = lnum }
				local vsig = view.topline .. ":" .. view.lnum
				if p.view ~= vsig then
					pcall(vim.api.nvim_win_call, p.win, function()
						vim.fn.winrestview({ topline = view.topline, lnum = view.lnum, col = 0, leftcol = 0 })
					end)
					p.view = vsig
				end
				row = row + height + 2 -- + border
			end
		end
	end
end

-- pin -----------------------------------------------------------------------

-- if the cursor sits inside an existing pin of this buffer, drop it and report
local function toggle_at(buf, row0)
	for _, p in ipairs(M.pins) do
		if p.buf == buf then
			local srow = mark_row(p)
			if srow and row0 >= srow and row0 <= srow + p.span - 1 then
				M.drop(p)
				M.refresh()
				return true
			end
		end
	end
	return false
end

local function open_float(p)
	local width = float_width()
	local win = vim.api.nvim_open_win(p.buf, false, {
		relative = "editor",
		row = 1,
		col = math.max(vim.o.columns - width - 2, 0),
		width = width,
		height = math.min(p.span + 2 * PAD, MAXH),
		style = "minimal",
		border = "rounded",
		focusable = false,
		title = " 🐕 ",
		title_pos = "center",
		noautocmd = true,
	})
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].cursorline = false
	p.win = win
end

local function add_pin(buf, srow0, erow0)
	local span = erow0 - srow0 + 1
	-- anchor + subtly highlight the region with one extmark (Visual, low priority)
	local mark = vim.api.nvim_buf_set_extmark(buf, ns, srow0, 0, {
		end_row = erow0,
		end_col = 0,
		line_hl_group = "LeashRegion",
		priority = 50,
		invalidate = true,
	})
	local name = vim.api.nvim_buf_get_name(buf)
	local file = name ~= "" and vim.fn.fnamemodify(name, ":t") or "[No Name]"
	local p = { buf = buf, file = file, span = span, mark_id = mark }
	open_float(p)
	M.pins[#M.pins + 1] = p
	ensure_timer()
	M.refresh()
end

function M.pin_normal()
	local buf = vim.api.nvim_get_current_buf()
	local row0 = vim.api.nvim_win_get_cursor(0)[1] - 1
	if toggle_at(buf, row0) then
		return
	end
	add_pin(buf, row0, row0)
end

function M.pin_visual()
	local buf = vim.api.nvim_get_current_buf()
	local s, e = vim.fn.line("v") - 1, vim.fn.line(".") - 1
	if s > e then
		s, e = e, s
	end
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
	add_pin(buf, s, e)
end

-- setup ---------------------------------------------------------------------

function M.setup()
	vim.api.nvim_set_hl(0, "LeashRegion", { link = "Visual", default = true })

	vim.keymap.set("n", "<leader>L", M.pin_normal, { desc = "leash: pin line" })
	vim.keymap.set("x", "<leader>L", M.pin_visual, { desc = "leash: pin selection" })
	vim.keymap.set("n", "<leader>X", M.clear, { desc = "leash: clear all pins" })

	vim.api.nvim_create_user_command("Leash", function(a)
		if a.args == "x" then
			M.clear()
		else
			M.pin_normal()
		end
	end, { nargs = "?", desc = "leash: pin at cursor (x = clear all)" })

	local group = vim.api.nvim_create_augroup("Leash", { clear = true })
	vim.api.nvim_create_autocmd({ "VimResized", "BufWritePost" }, {
		group = group,
		callback = function()
			if #M.pins > 0 then
				M.refresh()
			end
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		callback = function(ev)
			for _, p in ipairs({ unpack(M.pins) }) do
				if p.buf == ev.buf then
					M.drop(p)
				end
			end
		end,
	})
end

M.setup()
return M
