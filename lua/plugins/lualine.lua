return {
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		local colors = {
			rose = "#ebbcba",
			pine = "#31748f",
			foam = "#9ccfd8",
			iris = "#c4a7e7",
			gold = "#f6c177",
			love = "#eb6f92",
			base = "#191724",
			muted = "#6e6a86",
			subtle = "#908caa",
			text = "#e0def4",
		}

		-- Blocky retro mode indicator (letter + shaded block), colored per mode
		local mode_colors = {
			n = colors.rose,
			i = colors.foam,
			v = colors.iris,
			V = colors.iris,
			[""] = colors.iris,
			c = colors.gold,
			s = colors.pine,
			S = colors.pine,
			R = colors.love,
			t = colors.pine,
			["!"] = colors.gold,
		}
		local mode_display = {
			n = "▓ N",
			i = "▌ I",
			v = "█ V",
			V = "█ V",
			[""] = "█ V",
			c = "▒ C",
			s = "▓ S",
			S = "▓ S",
			R = "▓ R",
			t = "░ T",
			["!"] = "▒ !",
		}

		local mode = {
			function()
				return mode_display[vim.fn.mode()] or "▓ N"
			end,
			color = function()
				return { fg = mode_colors[vim.fn.mode()] or colors.rose, bg = "NONE", gui = "bold" }
			end,
			padding = { left = 1, right = 1 },
		}

		local function bracket(char, fg)
			return {
				function()
					return char
				end,
				color = { fg = fg or colors.muted },
				padding = char == "[" and { left = 1, right = 0 } or { left = 0, right = 1 },
			}
		end

		-- Transparent theme (single definition — no reload hack needed now that
		-- rose-pine is the only colorscheme)
		local theme = {}
		for _, m in ipairs({ "normal", "insert", "visual", "replace", "command" }) do
			theme[m] = {
				a = { fg = colors.base, bg = colors.rose, gui = "bold" },
				b = { fg = colors.text, bg = "NONE" },
				c = { fg = colors.text, bg = "NONE" },
			}
		end
		theme.insert.a.bg = colors.foam
		theme.visual.a.bg = colors.iris
		theme.replace.a.bg = colors.love
		theme.command.a.bg = colors.gold
		theme.inactive = {
			a = { fg = colors.muted, bg = "NONE" },
			b = { fg = colors.muted, bg = "NONE" },
			c = { fg = colors.muted, bg = "NONE" },
		}

		require("lualine").setup({
			options = {
				theme = theme,
				component_separators = "",
				section_separators = "",
				globalstatus = true,
			},
			sections = {
				lualine_a = {},
				lualine_b = {
					mode,
					{ "filetype", colored = true, color = { fg = colors.subtle } },
					bracket("["),
					{ "lsp_status", color = { fg = colors.pine } },
					{ "diagnostics" },
					bracket("]"),
				},
				lualine_c = {},
				lualine_x = {
					{
						"diff",
						symbols = { added = "▓ ", modified = "▒ ", removed = "░ " },
						diff_color = {
							added = { fg = colors.foam },
							modified = { fg = colors.gold },
							removed = { fg = colors.love },
						},
					},
					bracket("["),
					{ "branch", icon = "", color = { fg = colors.iris, gui = "bold" } },
					bracket("]"),
					{ "searchcount", maxcount = 999, color = { fg = colors.gold } },
					bracket("["),
					{ "filename", path = 1, color = { fg = colors.text, gui = "bold" } },
					{ "progress", color = { fg = colors.subtle } },
					{ "location", color = { fg = colors.text } },
					bracket("]"),
				},
				lualine_y = {},
				lualine_z = {},
			},
			inactive_sections = {
				lualine_c = { { "filename", path = 1 } },
				lualine_x = { "location" },
			},
		})
	end,
}
