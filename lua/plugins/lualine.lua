return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		-- Rosé Pine inspired colors for each mode
		local colors = {
			rose = "#ebbcba",
			pine = "#31748f",
			foam = "#9ccfd8",
			iris = "#c4a7e7",
			gold = "#f6c177",
			love = "#eb6f92",
			base = "#191724",
			surface = "#1f1d2e",
			overlay = "#26233a",
			muted = "#6e6a86",
			subtle = "#908caa",
			text = "#e0def4",
		}

		-- Mode colors configuration
		local mode_colors = {
			n = colors.rose, -- Normal
			i = colors.foam, -- Insert
			v = colors.iris, -- Visual
			V = colors.iris, -- Visual Line
			c = colors.gold, -- Command
			no = colors.rose, -- Normal Operator
			s = colors.pine, -- Select
			S = colors.pine, -- Select Line
			ic = colors.foam, -- Insert completion
			R = colors.love, -- Replace
			Rv = colors.love, -- Virtual Replace
			cv = colors.gold, -- Vim Ex
			ce = colors.gold, -- Ex
			r = colors.foam, -- Prompt
			rm = colors.foam, -- More
			["r?"] = colors.foam, -- Confirm
			["!"] = colors.gold, -- Shell
			t = colors.pine, -- Terminal
		}

		local mode = {
			"mode",
			fmt = function(str)
				return str
			end,
			color = function()
				local mode_code = vim.fn.mode()
				return {
					fg = mode_colors[mode_code] or colors.rose,
					bg = "NONE",
					gui = "bold",
				}
			end,
		}

		local branch = {
			"branch",
			icon = "",
			color = { fg = colors.iris, gui = "bold" },
		}

		local separator = {
			function()
				return "<>"
			end,
			color = { fg = colors.muted },
			padding = { left = 1, right = 1 },
		}

		local lsp_status = {
			"lsp_status",
			color = { fg = colors.pine },
		}

		local diagnostics = {
			"diagnostics",
			color = { fg = colors.base },
		}

		local location = {
			"location",
			color = { fg = colors.text },
		}

		local filename = {
			"filename",
			file_status = true,
			newfile_status = true,
			path = 1, -- 0 = just filename, 1 = relative path, 2 = absolute path
			symbols = {
				modified = "[+]",
				readonly = "[-]",
				unnamed = "[No Name]",
				newfile = "[New]",
			},
			color = { fg = colors.text, gui = "bold" },
		}

		local filetype = {
			"filetype",
			colored = true,
			icon_only = false,
			color = { fg = colors.subtle },
		}

		local searchcount = {
			"searchcount",
			maxcount = 999,
			timeout = 500,
			color = { fg = colors.gold },
		}

		-- Custom theme with transparent backgrounds
		local custom_theme = {
			normal = {
				a = { fg = colors.base, bg = colors.rose, gui = "bold" },
				b = { fg = colors.text, bg = "NONE" },
				c = { fg = colors.text, bg = "NONE" },
			},
			insert = {
				a = { fg = colors.base, bg = colors.foam, gui = "bold" },
				b = { fg = colors.text, bg = "NONE" },
				c = { fg = colors.text, bg = "NONE" },
			},
			visual = {
				a = { fg = colors.base, bg = colors.iris, gui = "bold" },
				b = { fg = colors.text, bg = "NONE" },
				c = { fg = colors.text, bg = "NONE" },
			},
			replace = {
				a = { fg = colors.base, bg = colors.love, gui = "bold" },
				b = { fg = colors.text, bg = "NONE" },
				c = { fg = colors.text, bg = "NONE" },
			},
			command = {
				a = { fg = colors.base, bg = colors.gold, gui = "bold" },
				b = { fg = colors.text, bg = "NONE" },
				c = { fg = colors.text, bg = "NONE" },
			},
			inactive = {
				a = { fg = colors.muted, bg = "NONE" },
				b = { fg = colors.muted, bg = "NONE" },
				c = { fg = colors.muted, bg = "NONE" },
			},
		}

		require("lualine").setup({
			options = {
				icons_enabled = true,
				theme = custom_theme,
				component_separators = { left = "", right = "" },
				section_separators = { left = "", right = "" },
				disabled_filetypes = {
					statusline = {},
					winbar = {},
				},
				ignore_focus = {},
				always_divide_middle = true,
				globalstatus = true,
				refresh = {
					statusline = 1000,
					tabline = 1000,
					winbar = 1000,
				},
			},
			sections = {
				lualine_a = {},
				lualine_b = {
					mode,
					filetype,
					separator,
					lsp_status,
					diagnostics,
				},
				lualine_c = {},
				lualine_x = {
					branch,
					searchcount,
					filename,
					location,
				},
				lualine_y = {},
				lualine_z = {},
			},
			inactive_sections = {
				lualine_a = {},
				lualine_b = {},
				lualine_c = { "filename" },
				lualine_x = { "location" },
				lualine_y = {},
				lualine_z = {},
			},
			tabline = {},
			winbar = {},
			inactive_winbar = {},
			extensions = {},
		})
	end,
}
