return {
	{
		"rose-pine/neovim",
		name = "rose-pine",
		priority = 1000,
		config = function()
			require("rose-pine").setup({
				variant = "auto",
				dark_variant = "main",
				dim_inactive_windows = false,
				extend_background_behind_borders = true,
				styles = {
					bold = true,
					italic = false,
					transparency = true,
				},
				highlight_groups = {
					Pmenu = { bg = "NONE" },
					PmenuThumb = { bg = "NONE" },
					BlinkCmpMenu = { bg = "NONE" },

					-- For good search highlights
					CurSearch = { fg = "base", bg = "leaf", inherit = false },
					Search = { fg = "text", bg = "leaf", blend = 20, inherit = false },
				},
			})

			vim.cmd("colorscheme rose-pine")
		end,
	},
}
