local keymap = vim.keymap

keymap.set("n", "<leader>n", ":e <Space>", { noremap = true })

keymap.set({ "n", "v" }, "<leader>y", [["+y]])
keymap.set("n", "<leader>Y", [["+Y]])
keymap.set({ "n", "v" }, "<leader>p", [["+p]])

keymap.set("n", "J", "mzJ`z")
keymap.set("n", "n", "nzzzv")
keymap.set("n", "N", "Nzzzv")
keymap.set("n", "<C-d>", "<C-d>zz", { noremap = true })
keymap.set("n", "<C-u>", "<C-u>zz", { noremap = true })

keymap.set("n", "<leader>ra", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])

keymap.set("n", "<leader>bn", ":bn<CR>", { noremap = true })
keymap.set("n", "<leader>bp", ":bp<CR>", { noremap = true })

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
