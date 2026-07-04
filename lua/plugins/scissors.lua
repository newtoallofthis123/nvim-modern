return {
	"chrisgrieser/nvim-scissors",
	dependencies = "nvim-telescope/telescope.nvim",
	keys = {
		{
			"<leader>xs",
			function()
				require("scissors").editSnippet()
			end,
			desc = "Snippet: Edit",
		},
		{
			"<leader>xS",
			mode = { "n", "x" },
			function()
				require("scissors").addNewSnippet()
			end,
			desc = "Snippet: Add",
		},
	},
	opts = {
		snippetDir = vim.fn.stdpath("config") .. "/snippets",
	},
}
