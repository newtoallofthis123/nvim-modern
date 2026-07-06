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
-- Markdown checkbox toggle — tear through an AI's task list.
--   - [ ] todo   <leader>cc ->   - [x] todo   (and back)
--   plain list item gains a [ ]; works over a visual range too.
----------------------------------------------------------------------
local function toggle_checkbox(line)
	if line:match("%[ %]") then
		return (line:gsub("%[ %]", "[x]", 1))
	elseif line:match("%[[xX]%]") then
		return (line:gsub("%[[xX]%]", "[ ]", 1))
	end
	local added = line:gsub("^(%s*[-*+]%s+)", "%1[ ] ", 1)
	if added ~= line then
		return added
	end
	return (line:gsub("^(%s*)", "%1- [ ] ", 1))
end
map("n", "<leader>cc", function()
	vim.api.nvim_set_current_line(toggle_checkbox(vim.api.nvim_get_current_line()))
end, { desc = "Toggle markdown checkbox" })
map("x", "<leader>cc", function()
	local s, e = vim.fn.line("v"), vim.fn.line(".")
	if s > e then
		s, e = e, s
	end
	local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
	for i, l in ipairs(lines) do
		lines[i] = toggle_checkbox(l)
	end
	vim.api.nvim_buf_set_lines(0, s - 1, e, false, lines)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end, { desc = "Toggle markdown checkboxes" })

----------------------------------------------------------------------
-- Copy selection as a fenced code block (with the source filetype tag),
-- straight to the clipboard — ready to drop into a ticket / PR / the LLM.
-- Does NOT touch the buffer.
----------------------------------------------------------------------
map("x", "<leader>cb", function()
	local s, e = vim.fn.line("v"), vim.fn.line(".")
	if s > e then
		s, e = e, s
	end
	local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
	local block = "```" .. vim.bo.filetype .. "\n" .. table.concat(lines, "\n") .. "\n```"
	vim.fn.setreg("+", block)
	vim.notify("Copied " .. (e - s + 1) .. " lines as a code block")
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end, { desc = "Copy selection as fenced code block" })

----------------------------------------------------------------------
-- Follow a `path:line` token under the cursor (native gF) and center it.
-- Land on src/foo.rs:42 in a plan, press gF, you're there.
----------------------------------------------------------------------
map("n", "gF", "gFzz", { desc = "Open file:line under cursor (centered)" })

----------------------------------------------------------------------
-- Add a blank line below / above without leaving normal mode or moving.
----------------------------------------------------------------------
map("n", "]<Space>", function()
	local r = vim.api.nvim_win_get_cursor(0)[1]
	vim.api.nvim_buf_set_lines(0, r, r, false, { "" })
end, { desc = "Blank line below" })
map("n", "[<Space>", function()
	local pos = vim.api.nvim_win_get_cursor(0)
	vim.api.nvim_buf_set_lines(0, pos[1] - 1, pos[1] - 1, false, { "" })
	vim.api.nvim_win_set_cursor(0, { pos[1] + 1, pos[2] })
end, { desc = "Blank line above" })

----------------------------------------------------------------------
-- Sweep a substitution across every file in the quickfix list.
-- Populate the quickfix first (grep / LSP references), then <leader>cr.
-- The AI renamed something repo-wide and missed spots — this finishes it.
----------------------------------------------------------------------
map("n", "<leader>cr", function()
	if vim.fn.getqflist({ size = 0 }).size == 0 then
		vim.notify("Quickfix is empty — grep or find references first", vim.log.levels.WARN)
		return
	end
	local pat = vim.fn.input("Sweep quickfix files — pattern: ")
	if pat == "" then
		return
	end
	local rep = vim.fn.input("Replace with: ")
	vim.cmd(("cfdo %%s/%s/%s/ge | update"):format(pat, rep))
end, { desc = "Substitute across quickfix files" })

----------------------------------------------------------------------
-- Markdown link ergonomics (buffer-local to markdown — gf/<CR> must not
-- be shadowed everywhere).
--   <C-l> (visual)  wrap the selection in a link from the clipboard URL
--                     → [selection](https://…)
--   gf / <CR>       follow the link under the cursor:
--                     [[name]]        → name.md next to this file (created)
--                     [txt](./rel.md) → that relative file (created if .md)
--                     [txt](https://) → opens in the browser
--                   no link under the cursor → the default gf / newline.
----------------------------------------------------------------------
local function link_selection()
	local url = vim.trim(vim.fn.getreg("+"))
	if not url:match("^https?://%S+$") then
		vim.notify("clipboard is not a URL", vim.log.levels.WARN)
		return
	end
	local save, savet = vim.fn.getreg("v"), vim.fn.getregtype("v")
	vim.cmd('noautocmd normal! "vy')
	local text = vim.fn.getreg("v")
	vim.fn.setreg("v", ("[%s](%s)"):format(text, url), "c")
	vim.cmd('noautocmd normal! gv"vp')
	vim.fn.setreg("v", save, savet)
end

local function link_under_cursor()
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2] + 1
	for s, name, e in line:gmatch("()%[%[([^%]]+)%]%]()") do
		if col >= s and col < e then
			return { kind = "wiki", value = vim.trim(name) }
		end
	end
	for s, url, e in line:gmatch("()%[[^%]]*%]%(([^)]+)%)()") do
		if col >= s and col < e then
			return { kind = "link", value = vim.trim(url) }
		end
	end
end

local function open_or_create(path)
	path = vim.fn.fnamemodify(path, ":p")
	if vim.fn.filereadable(path) == 0 then
		vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
		local title = vim.fn.fnamemodify(path, ":t:r"):gsub("[-_]", " ")
		vim.fn.writefile({ "# " .. title, "" }, path)
	end
	vim.cmd.edit(vim.fn.fnameescape(path))
end

local function follow_link(fallback)
	local t = link_under_cursor()
	if not t then
		pcall(vim.cmd, "normal! " .. fallback)
		return
	end
	local base = vim.fn.expand("%:p:h")
	if t.kind == "link" then
		if t.value:match("^%w+://") then
			vim.ui.open(t.value)
		else
			open_or_create(base .. "/" .. t.value)
		end
	else
		open_or_create(base .. "/" .. (t.value:match("%.md$") and t.value or t.value .. ".md"))
	end
end

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("GemsMarkdown", { clear = true }),
	pattern = "markdown",
	callback = function(ev)
		local o = { buffer = ev.buf, silent = true }
		map("x", "<C-l>", link_selection, vim.tbl_extend("force", o, { desc = "Wrap selection as link" }))
		map("n", "gf", function()
			follow_link("gf")
		end, vim.tbl_extend("force", o, { desc = "Follow markdown link" }))
		map("n", "<cr>", function()
			follow_link("+")
		end, vim.tbl_extend("force", o, { desc = "Follow markdown link" }))
	end,
})
