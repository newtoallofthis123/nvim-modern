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

			-- vim.cmd("colorscheme rose-pine")
		end,
	},
	{
		"ellisonleao/gruvbox.nvim",
		priority = 1000,
		config = function()
			require("gruvbox").setup({
				terminal_colors = true,
				invert_selection = true,
				bold = true,
				italic = {
					strings = true,
					emphasis = true,
					comments = true,
					operators = false,
					folds = false,
				},
				contrast = "hard",
				palette_overrides = {},
				overrides = {
					WhichKey = { bg = "NONE" },
					WhichKeyNormal = { bg = "NONE" },
					NormalFloat = { bg = "NONE" },
					BlinkCmpMenu = { bg = "NONE" },
					Pmenu = { bg = "NONE" },
					PmenuThumb = { bg = "NONE" },
				},
				dim_inactive = true,
				transparent_mode = true,
			})
			-- vim.cmd("colorscheme gruvbox")
		end,
	},
	{
		"loctvl842/monokai-pro.nvim",
		priority = 1000,
		config = function()
			require("monokai-pro").setup({
				transparent_background = true,
				filter = "spectrum",
				background_clear = {
					"telescope",
					"which-key",
					"nvim-tree",
					"bufferline",
					"float_win",
					"renamer",
					"toggleterm",
					"blink",
				},
				override = function()
					return {
						Pmenu = { bg = "NONE" },
						PmenuThumb = { bg = "NONE" },
						BlinkCmpMenu = { bg = "NONE" },
					}
				end,
			})
			vim.cmd([[colorscheme monokai-pro-spectrum]])
		end,
	},
}
