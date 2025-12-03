return {
	"A7Lavinraj/fyler.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	branch = "stable",
	config = function()
		require("fyler").setup({
			icon = "nvim_web_devicons",
		})

		-- vim.keymap.set("n", "-", "<CMD>Fyler kind=split_right_most<CR>", { desc = "Open parent directory" })
		-- vim.keymap.set("n", "<leader>e", "<CMD>Fyler<CR>", { desc = "Open parent directory" })
	end,
	enabled = false,
}
