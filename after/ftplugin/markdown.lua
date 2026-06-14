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
