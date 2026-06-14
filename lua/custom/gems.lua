-- Bespoke power tools, in the spirit of <leader>ra.
local map = vim.keymap.set

----------------------------------------------------------------------
-- Flip the thing under the cursor (case-preserved)
--   booleans/keywords: true<->false, and<->or, let<->const, ...
--   operators:         == <-> !=, && <-> ||, <= <-> >=
----------------------------------------------------------------------
local base = {
	["true"] = "false",
	["yes"] = "no",
	["on"] = "off",
	["and"] = "or",
	["let"] = "const",
	["enable"] = "disable",
	["enabled"] = "disabled",
	["show"] = "hide",
	["min"] = "max",
	["width"] = "height",
	["before"] = "after",
	["first"] = "last",
	["left"] = "right",
	["up"] = "down",
}
local word_flips = {}
for a, b in pairs(base) do
	word_flips[a] = b
	word_flips[b] = a
end

local function apply_case(src, dst)
	if src:match("^%u+$") then
		return dst:upper()
	elseif src:match("^%u") then
		return dst:sub(1, 1):upper() .. dst:sub(2)
	end
	return dst
end

local op_flips = {
	["=="] = "!=",
	["!="] = "==",
	["&&"] = "||",
	["||"] = "&&",
	["<="] = ">=",
	[">="] = "<=",
}

local function flip()
	local cword = vim.fn.expand("<cword>")
	local hit = word_flips[cword:lower()]
	if hit then
		vim.cmd("normal! ciw" .. apply_case(cword, hit))
		return
	end
	-- operator at/just-before the cursor
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2] + 1
	for _, c in ipairs({ col, col - 1 }) do
		local two = line:sub(c, c + 1)
		if op_flips[two] then
			vim.api.nvim_set_current_line(line:sub(1, c - 1) .. op_flips[two] .. line:sub(c + 2))
			return
		end
	end
	vim.notify("Nothing to flip here", vim.log.levels.INFO)
end
map("n", "<leader>cf", flip, { desc = "Flip word/operator under cursor" })

----------------------------------------------------------------------
-- Visual * / # : search the EXACT selection (escaped, literal)
----------------------------------------------------------------------
map("x", "*", [[y/\V<C-r>=escape(@", '/\')<CR><CR>]], { desc = "Search selection →" })
map("x", "#", [[y?\V<C-r>=escape(@", '?\')<CR><CR>]], { desc = "Search selection ←" })

----------------------------------------------------------------------
-- Visual <leader>rv : the visual twin of <leader>ra — substitute the
-- selection across the file, cursor parked to type the replacement.
----------------------------------------------------------------------
map("x", "<leader>rv", [[y:%s/\V<C-r>=escape(@", '/\')<CR>//gI<Left><Left><Left>]], {
	desc = "Substitute selection in file",
})

----------------------------------------------------------------------
-- Sort / dedupe a visual selection
----------------------------------------------------------------------
map("x", "<leader>so", ":sort<CR>", { desc = "Sort selection" })
map("x", "<leader>su", ":sort u<CR>", { desc = "Sort selection (unique)" })

----------------------------------------------------------------------
-- Filter a selection through a shell command (in place).
-- Leaves you at `:'<,'>!` — type `jq .`, `sort -u`, `column -t`, ...
----------------------------------------------------------------------
map("x", "<leader>r!", ":!", { desc = "Filter selection → shell cmd" })

----------------------------------------------------------------------
-- :Redir <cmd> — capture any ex/lua command's output in a scratch split.
--   :Redir map          :Redir hi Normal      :Redir lua=vim.lsp.get_clients()
----------------------------------------------------------------------
vim.api.nvim_create_user_command("Redir", function(ctx)
	local ok, res = pcall(vim.api.nvim_exec2, ctx.args, { output = true })
	local out = ok and res.output or tostring(res)
	vim.cmd("botright vsplit")
	vim.cmd("enew")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(out, "\n", { plain = true }))
	vim.bo.buftype = "nofile"
	vim.bo.bufhidden = "wipe"
	vim.bo.swapfile = false
	vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = true, silent = true })
end, { nargs = "+", complete = "command", desc = "Capture command output in a scratch split" })

----------------------------------------------------------------------
-- Scratch pad — a throwaway markdown buffer for jotting while reviewing.
-- Reused for the session; toggles a bottom split.
----------------------------------------------------------------------
local scratch_buf
map("n", "<leader>ns", function()
	if scratch_buf and vim.api.nvim_buf_is_valid(scratch_buf) then
		local win = vim.fn.bufwinid(scratch_buf)
		if win ~= -1 then
			vim.api.nvim_win_close(win, false) -- already visible → toggle off
			return
		end
		vim.cmd("botright 12split")
		vim.api.nvim_set_current_buf(scratch_buf)
	else
		vim.cmd("botright 12split")
		scratch_buf = vim.api.nvim_create_buf(true, true)
		vim.api.nvim_set_current_buf(scratch_buf)
		vim.bo[scratch_buf].filetype = "markdown"
		pcall(vim.api.nvim_buf_set_name, scratch_buf, "scratch")
	end
end, { desc = "Scratch pad (toggle)" })
