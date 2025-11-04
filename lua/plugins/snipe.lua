return {
	{
		"leath-dub/snipe.nvim",
		keys = {
			{
				"<leader>'",
				function()
					require("snipe").open_buffer_menu()
				end,
				desc = "Open Snipe buffer menu",
			},
		},
		opts = {},
	},
	{
		{
			"kungfusheep/snipe-lsp.nvim",
			event = "VeryLazy",
			dependencies = "leath-dub/snipe.nvim",
			opts = {
				keymap = {
					open_symbols_menu = "<leader>O",
				},
			},
		},
	},
}
