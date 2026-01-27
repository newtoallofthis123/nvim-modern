return {
	"MeanderingProgrammer/render-markdown.nvim",
	dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
	opts = {
		-- Render in normal and visual modes only
		render_modes = { "n", "v" },

		-- Heading configuration - elegant and minimal
		heading = {
			-- Beautiful minimal icons that match Rosé Pine vibe
			icons = { "󰎤 ", "󰎧 ", "󰎪 ", "󰎭 ", "󰎱 ", "󰎳 " },
			-- No sign column indicators
			sign = false,
			-- Overlay icons on the heading marker
			position = "overlay",
			-- Full width backgrounds for a cleaner look
			width = "full",
			-- Minimal padding
			left_pad = 1,
			right_pad = 1,
			-- No borders - keeping it clean
			border = false,
			-- Custom backgrounds per heading level (Rosé Pine inspired)
			backgrounds = {
				"RenderMarkdownH1Bg",
				"RenderMarkdownH2Bg",
				"RenderMarkdownH3Bg",
				"RenderMarkdownH4Bg",
				"RenderMarkdownH5Bg",
				"RenderMarkdownH6Bg",
			},
			foregrounds = {
				"RenderMarkdownH1",
				"RenderMarkdownH2",
				"RenderMarkdownH3",
				"RenderMarkdownH4",
				"RenderMarkdownH5",
				"RenderMarkdownH6",
			},
		},

		-- Code blocks - clean and minimal
		code = {
			-- Clean borders
			border = "thin",
			-- Show language name
			language_name = true,
			-- Icon position
			position = "left",
			-- Full width for consistency
			width = "full",
			-- Padding
			left_pad = 2,
			right_pad = 2,
			-- Disable background for certain languages if needed
			disable_background = {},
		},

		-- Elegant bullet points
		bullet = {
			-- Rosé Pine inspired bullet characters
			icons = { "◆", "◇", "▪", "▫" },
			left_pad = 0,
			right_pad = 1,
			highlight = "RenderMarkdownBullet",
		},

		-- Checkbox styling
		checkbox = {
			unchecked = { icon = "󰄱 " },
			checked = { icon = "󰱒 " },
			custom = {
				todo = { raw = "[-]", rendered = "󰥔 ", highlight = "RenderMarkdownTodo" },
			},
		},

		-- Quote blocks
		quote = {
			icon = "▋",
			repeat_linebreak = true,
		},

		-- Cleaner pipe tables
		pipe_table = {
			preset = "round",
			cell = "padded",
		},

		-- Anti-conceal on cursor line
		anti_conceal = {
			enabled = true,
		},
	},
	config = function(_, opts)
		require("render-markdown").setup(opts)

		-- Custom Rosé Pine color highlights
		vim.api.nvim_set_hl(0, "RenderMarkdownH1", { fg = "#eb6f92", bold = true })
		vim.api.nvim_set_hl(0, "RenderMarkdownH1Bg", { bg = "NONE" })

		vim.api.nvim_set_hl(0, "RenderMarkdownH2", { fg = "#f6c177", bold = true })
		vim.api.nvim_set_hl(0, "RenderMarkdownH2Bg", { bg = "NONE" })

		vim.api.nvim_set_hl(0, "RenderMarkdownH3", { fg = "#c4a7e7", bold = true })
		vim.api.nvim_set_hl(0, "RenderMarkdownH3Bg", { bg = "NONE" })

		vim.api.nvim_set_hl(0, "RenderMarkdownH4", { fg = "#9ccfd8", bold = true })
		vim.api.nvim_set_hl(0, "RenderMarkdownH4Bg", { bg = "NONE" })

		vim.api.nvim_set_hl(0, "RenderMarkdownH5", { fg = "#ebbcba", bold = true })
		vim.api.nvim_set_hl(0, "RenderMarkdownH5Bg", { bg = "NONE" })

		vim.api.nvim_set_hl(0, "RenderMarkdownH6", { fg = "#31748f", bold = true })
		vim.api.nvim_set_hl(0, "RenderMarkdownH6Bg", { bg = "NONE" })

		-- Code block styling
		vim.api.nvim_set_hl(0, "RenderMarkdownCode", { bg = "NONE" })
		vim.api.nvim_set_hl(0, "RenderMarkdownCodeInline", { bg = "#26233a", fg = "#c4a7e7" })

		-- Bullet and list styling
		vim.api.nvim_set_hl(0, "RenderMarkdownBullet", { fg = "#c4a7e7" })

		-- Checkbox styling
		vim.api.nvim_set_hl(0, "RenderMarkdownChecked", { fg = "#31748f" })
		vim.api.nvim_set_hl(0, "RenderMarkdownUnchecked", { fg = "#6e6a86" })
		vim.api.nvim_set_hl(0, "RenderMarkdownTodo", { fg = "#f6c177" })

		-- Quote styling
		vim.api.nvim_set_hl(0, "RenderMarkdownQuote", { fg = "#908caa" })
	end,
	enabled = false,
}
