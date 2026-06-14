-- Markdown: a calm prose surface for writing tickets/plans.
-- (spell + textwidth=80 come from the prose autocmd; render-markdown owns conceal)
local opt = vim.opt_local
opt.wrap = true -- soft-wrap long lines
opt.linebreak = true -- break at word boundaries, never mid-word
opt.breakindent = true -- wrapped lines keep their indent
opt.formatoptions:remove("t") -- soft-wrap only; gq still reflows on demand

local map = vim.keymap.set

-- move by VISUAL line when wrapped — but a count still moves real lines (3j)
for _, k in ipairs({ "j", "k" }) do
	map({ "n", "x" }, k, ("v:count == 0 ? 'g%s' : '%s'"):format(k, k), { buffer = true, expr = true })
end

-- emphasis: visual-select, then \b \i \c \s  (change-and-reinsert, no plugin)
map("x", "<localleader>b", [[c**<C-r>"**<Esc>]], { buffer = true, desc = "MD bold" })
map("x", "<localleader>i", [[c*<C-r>"*<Esc>]], { buffer = true, desc = "MD italic" })
map("x", "<localleader>c", [[c`<C-r>"`<Esc>]], { buffer = true, desc = "MD inline code" })
map("x", "<localleader>s", [[c~~<C-r>"~~<Esc>]], { buffer = true, desc = "MD strikethrough" })

-- promote / demote the heading on the current line
local function heading(delta)
	local line = vim.api.nvim_get_current_line()
	local hashes, rest = line:match("^(#*)%s*(.*)$")
	local n = math.min(6, math.max(0, #hashes + delta))
	vim.api.nvim_set_current_line((n > 0 and string.rep("#", n) .. " " or "") .. rest)
end
map("n", "<localleader>=", function()
	heading(1)
end, { buffer = true, desc = "MD heading deeper" })
map("n", "<localleader>-", function()
	heading(-1)
end, { buffer = true, desc = "MD heading shallower" })

-- navigate a long plan/ticket: jump between headings, centered
local function goto_heading(flags)
	return function()
		vim.fn.search([[^#\+\s]], flags)
		vim.cmd("normal! zz")
	end
end
map({ "n", "x" }, "]]", goto_heading("W"), { buffer = true, desc = "Next heading" })
map({ "n", "x" }, "[[", goto_heading("bW"), { buffer = true, desc = "Prev heading" })

-- outline: every heading → location list (indented by depth), jump from there
map("n", "<localleader>o", function()
	local buf = vim.api.nvim_get_current_buf()
	local items = {}
	for lnum, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		local hashes, text = line:match("^(#+)%s+(.+)")
		if hashes then
			items[#items + 1] = { bufnr = buf, lnum = lnum, text = string.rep("  ", #hashes - 1) .. text }
		end
	end
	if #items == 0 then
		vim.notify("no headings")
		return
	end
	vim.fn.setloclist(0, {}, " ", { title = "Outline", items = items })
	vim.cmd("lopen")
end, { buffer = true, desc = "MD outline → loclist" })
