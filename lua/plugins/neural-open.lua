return {
	"dtormoen/neural-open.nvim",
	dependencies = { "folke/snacks.nvim" },
	lazy = false,
	keys = {
		{ "<leader>fe", function() require("neural-open").open() end, desc = "Neural Open Files" },
	},
	opts = {},
}
