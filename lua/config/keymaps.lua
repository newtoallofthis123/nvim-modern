local keymap = vim.keymap

keymap.set("n", "<leader>nn", ":e <Space>", { noremap = true })

keymap.set({ "n", "v" }, "<leader>y", [["+y]])
keymap.set("n", "<leader>Y", [["+Y]])
keymap.set({ "n", "v" }, "<leader>p", [["+p]])

keymap.set("n", "J", "mzJ`z")
keymap.set("n", "n", "nzzzv")
keymap.set("n", "N", "Nzzzv")
keymap.set("n", "<C-d>", "<C-d>zz", { noremap = true })
keymap.set("n", "<C-u>", "<C-u>zz", { noremap = true })

keymap.set("n", "<leader>ra", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

-- Change the word under the cursor, then press `.` to repeat that same change
-- on the next match (and the next…). Surgical replace without :%s.
keymap.set("n", "<leader>cn", "*``cgn", { desc = "Change word → next match (dot-repeat)" })
keymap.set("n", "<leader>cN", "*``cgN", { desc = "Change word → prev match (dot-repeat)" })

-- Move the visual selection up/down (and reindent into its new context)
keymap.set("x", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
keymap.set("x", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Keep the selection after indenting so < / > repeat
keymap.set("x", "<", "<gv")
keymap.set("x", ">", ">gv")

-- Paste over a selection without clobbering what you yanked
keymap.set("x", "p", [["_dP]], { desc = "Paste without losing register" })

-- Jump between git conflict markers (centered)
keymap.set("n", "]x", [[/^\(<<<<<<<\|=======\|>>>>>>>\)<CR>zz]], { desc = "Next conflict marker" })
keymap.set("n", "[x", [[?^\(<<<<<<<\|=======\|>>>>>>>\)<CR>zz]], { desc = "Prev conflict marker" })

-- Native undo-tree visualizer (ships with nvim 0.12; fills the time-machine hole)
keymap.set("n", "<leader>U", function()
	vim.cmd("packadd nvim.undotree")
	vim.cmd("Undotree")
end, { desc = "Undo tree" })

keymap.set("n", "<leader>bn", ":bn<CR>", { noremap = true })
keymap.set("n", "<leader>bp", ":bp<CR>", { noremap = true })
keymap.set("n", "<leader>bb", ":ls<CR>:b ", { noremap = true, desc = "List buffers and switch" })

keymap.set("n", "<leader>tn", ":$tabnew<CR>", { noremap = true })
keymap.set("n", "<leader>tq", ":tabclose<CR>", { noremap = true })
keymap.set("n", "t<Left>", ":tabprevious<CR>", { noremap = true })
keymap.set("n", "t<Right>", ":+tabnext<CR>", { noremap = true })

keymap.set("n", "<leader>t1", "1gt", { desc = "Go to tab 1" })
keymap.set("n", "<leader>t2", "2gt", { desc = "Go to tab 2" })
keymap.set("n", "<leader>t3", "3gt", { desc = "Go to tab 3" })
keymap.set("n", "<leader>t4", "4gt", { desc = "Go to tab 4" })
keymap.set("n", "<leader>t5", "5gt", { desc = "Go to tab 5" })
keymap.set("n", "<leader>t6", "6gt", { desc = "Go to tab 6" })
keymap.set("n", "<leader>t7", "7gt", { desc = "Go to tab 7" })
keymap.set("n", "<leader>t8", "8gt", { desc = "Go to tab 8" })
keymap.set("n", "<leader>t9", "9gt", { desc = "Go to tab 9" })

-- Smart window navigation/creation
local function smart_split(direction)
	local current_win = vim.fn.winnr()
	vim.cmd("wincmd " .. direction)
	if vim.fn.winnr() == current_win then
		-- Didn't move, so create a new split
		if direction == "h" then
			vim.cmd("topleft vsplit")
		elseif direction == "l" then
			vim.cmd("botright vsplit")
		elseif direction == "k" then
			vim.cmd("topleft split")
		elseif direction == "j" then
			vim.cmd("botright split")
		end
	end
end

keymap.set("n", "<leader>wh", function()
	smart_split("h")
end, { desc = "Split/go left" })
keymap.set("n", "<leader>wj", function()
	smart_split("j")
end, { desc = "Split/go down" })
keymap.set("n", "<leader>wk", function()
	smart_split("k")
end, { desc = "Split/go up" })
keymap.set("n", "<leader>wl", function()
	smart_split("l")
end, { desc = "Split/go right" })

-- Window navigation with arrow keys
keymap.set("n", "<leader>w<Left>", "<C-w>h", { desc = "Go to left window" })
keymap.set("n", "<leader>w<Down>", "<C-w>j", { desc = "Go to window below" })
keymap.set("n", "<leader>w<Up>", "<C-w>k", { desc = "Go to window above" })
keymap.set("n", "<leader>w<Right>", "<C-w>l", { desc = "Go to right window" })

-- Window resize/maximize
-- Zoom: maximize this split; press again to restore the EXACT prior layout
local zoom_restore
keymap.set("n", "<leader>wm", function()
	if zoom_restore then
		vim.cmd(zoom_restore)
		zoom_restore = nil
	elseif vim.fn.winnr("$") > 1 then
		zoom_restore = vim.fn.winrestcmd()
		vim.cmd("wincmd _ | wincmd |")
	end
end, { desc = "Zoom split (maximize/restore)" })
keymap.set("n", "<leader>we", "<C-w>=", { desc = "Equalize split sizes" })
keymap.set("n", "<leader>wo", "<C-w>o", { desc = "Close all other splits" })
keymap.set("n", "<leader>wt", "<C-w>T", { desc = "Break split into a new tab" })

-- The flip family: jump to the OTHER one, no picker (cousins of <C-o>)
keymap.set("n", "<BS>", "<C-^>", { desc = "Flip to alternate file" })
keymap.set("n", "<C-w>p", "<C-w>p", { desc = "Flip to last window" })
keymap.set("n", "g<Tab>", "g<Tab>", { desc = "Flip to last tab" })

keymap.set("n", "<leader>vd", vim.diagnostic.open_float, { noremap = true, desc = "Open diagnostic float" })

-- Copy diagnostics on current line to clipboard
keymap.set("n", "<leader>vy", function()
	local diagnostics = vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 })
	if #diagnostics == 0 then
		vim.notify("No diagnostics on current line", vim.log.levels.INFO)
		return
	end
	local messages = {}
	for _, diag in ipairs(diagnostics) do
		table.insert(messages, diag.message)
	end
	local text = table.concat(messages, "\n")
	vim.fn.setreg("+", text)
	vim.notify("Copied diagnostics to clipboard", vim.log.levels.INFO)
end, { noremap = true, desc = "Copy diagnostics to clipboard" })

-- Open diagnostics in horizontal split
keymap.set("n", "<leader>vs", function()
	local diagnostics = vim.diagnostic.get(0, { lnum = vim.fn.line(".") - 1 })
	if #diagnostics == 0 then
		vim.notify("No diagnostics on current line", vim.log.levels.INFO)
		return
	end
	local messages = {}
	for _, diag in ipairs(diagnostics) do
		table.insert(
			messages,
			string.format(
				"[%s] %s",
				diag.severity == 1 and "ERROR"
					or diag.severity == 2 and "WARN"
					or diag.severity == 3 and "INFO"
					or "HINT",
				diag.message
			)
		)
	end

	-- Create a small horizontal split below
	vim.cmd("botright 10split")
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, buf)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, messages)
	vim.bo[buf].modifiable = false
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"

	-- Set a keymap to close the split easily
	vim.keymap.set("n", "q", ":q<CR>", { buffer = buf, noremap = true, silent = true })
end, { noremap = true, desc = "Open diagnostics in split" })

-- Git commands (note: <leader>gd is now Diffview review; PR/issue pickers
-- live under snacks; lazygit on <leader>gl)
vim.keymap.set("n", "<leader>gmc", function()
	vim.fn.setqflist({}, "r", {
		title = "Git Merge Conflicts",
		lines = vim.fn.systemlist("git jump --stdout merge"),
	})
	vim.cmd("copen")
end, { desc = "View git merge conflicts in quickfix" })

vim.keymap.set("n", "<leader>gr", function()
	vim.fn.system("gh repo view --web")
end, { desc = "Open repo in web browser" })
