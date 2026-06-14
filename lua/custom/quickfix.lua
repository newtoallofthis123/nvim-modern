-- Quickfix power layer. quicker.nvim already owns the display + <leader>qq
-- toggle; this adds the picker-free ways to FILL and WALK it.
vim.o.grepprg = "rg --vimgrep --smart-case"
vim.o.grepformat = "%f:%l:%c:%m"

local map = vim.keymap.set

local function grep(word)
	if word and word ~= "" then
		vim.cmd("silent grep! " .. vim.fn.shellescape(word))
	end
end

-- grep the word under the cursor (or the selection) into the quickfix — no picker
map("n", "<leader>*", function()
	grep(vim.fn.expand("<cword>"))
end, { desc = "Grep word under cursor → quickfix" })
map("x", "<leader>*", function()
	local save, savet = vim.fn.getreg("v"), vim.fn.getregtype("v")
	vim.cmd('noautocmd normal! "vy')
	local sel = vim.fn.getreg("v")
	vim.fn.setreg("v", save, savet)
	grep(sel)
end, { desc = "Grep selection → quickfix" })

-- walk the list, centered + wrapping
local function qnav(forward)
	local ok = pcall(vim.cmd, forward and "cnext" or "cprev")
	if not ok then
		pcall(vim.cmd, forward and "cfirst" or "clast") -- wrap at the ends
	end
	pcall(vim.cmd, "normal! zz")
end
map("n", "]q", function()
	qnav(true)
end, { desc = "Next quickfix (centered)" })
map("n", "[q", function()
	qnav(false)
end, { desc = "Prev quickfix (centered)" })
map("n", "]Q", "<cmd>clast<CR>zz", { desc = "Last quickfix" })
map("n", "[Q", "<cmd>cfirst<CR>zz", { desc = "First quickfix" })

-- pop the quickfix open the moment a grep/make fills it
vim.api.nvim_create_autocmd("QuickFixCmdPost", {
	group = vim.api.nvim_create_augroup("qf_autoopen", { clear = true }),
	pattern = "[^l]*", -- :grep / :make, not the :lgrep location-list variants
	callback = function()
		vim.cmd("botright copen")
	end,
})
