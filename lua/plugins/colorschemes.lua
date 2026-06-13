return {
	{
		"rose-pine/neovim",
		name = "rose-pine",
		priority = 1000,
		lazy = false,
		config = function()
			require("rose-pine").setup({
				variant = "auto",
				dark_variant = "main",
				dim_inactive_windows = true,
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

					-- Transparent cursorline: no full-width bar, just a bright
					-- line number to mark where you are
					CursorLine = { bg = "NONE" },
					CursorLineNr = { fg = "gold", bold = true },

					-- For good search highlights
					CurSearch = { fg = "base", bg = "leaf", inherit = false },
					Search = { fg = "text", bg = "leaf", blend = 20, inherit = false },
				},
			})

			vim.cmd("colorscheme rose-pine")
		end,
	},
}
