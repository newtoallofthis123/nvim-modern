return {
	"trevorhauter/gitportal.nvim",
	keys = {
		{ "<leader>gO", mode = { "n", "v" }, desc = "GitPortal: open in browser" },
		{ "<leader>gL", mode = { "n", "v" }, desc = "GitPortal: copy link" },
		{ "<leader>ig", desc = "GitPortal: open from link" },
	},
	config = function()
		local gitportal = require("gitportal")

		gitportal.setup({})

		vim.keymap.set("n", "<leader>gO", gitportal.open_file_in_browser)
		vim.keymap.set("v", "<leader>gO", gitportal.open_file_in_browser)

		vim.keymap.set("n", "<leader>ig", gitportal.open_file_in_neovim)

		vim.keymap.set("n", "<leader>gL", gitportal.copy_link_to_clipboard)
		vim.keymap.set("v", "<leader>gL", gitportal.copy_link_to_clipboard)
	end,
}
