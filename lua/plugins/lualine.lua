return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		-- Function to get colors based on current colorscheme and background
		local function get_colors()
			-- local colorscheme = vim.g.colors_name or "gruvbox"
			-- local background = vim.o.background or "dark"

			return {
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
		end

		local colors = get_colors()

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

		-- Blocky retro mode symbols with letters
		local mode_display = {
			n = "▓ N",
			i = "▌ I",
			v = "█ V",
			V = "█ V",
			[""] = "█ V",
			c = "▒ C",
			no = "▓ N",
			s = "▓ S",
			S = "▓ S",
			[""] = "▓ S",
			ic = "▌ I",
			R = "▓ R",
			Rv = "▓ R",
			cv = "▒ E",
			ce = "▒ E",
			r = "░ P",
			rm = "░ M",
			["r?"] = "░ ?",
			["!"] = "▒ !",
			t = "░ T",
		}

		local mode = {
			function()
				local mode_code = vim.fn.mode()
				return mode_display[mode_code] or "▓ N"
			end,
			color = function()
				local mode_code = vim.fn.mode()
				return {
					fg = mode_colors[mode_code] or colors.rose,
					bg = "NONE",
					gui = "bold",
				}
			end,
			padding = { left = 1, right = 1 },
		}

		local branch = {
			"branch",
			icon = "",
			color = { fg = colors.iris, gui = "bold" },
		}

		local separator_left = {
			function()
				return "["
			end,
			color = { fg = colors.muted },
			padding = { left = 1, right = 0 },
		}

		local separator_right = {
			function()
				return "]"
			end,
			color = { fg = colors.muted },
			padding = { left = 0, right = 1 },
		}

		local diff = {
			"diff",
			symbols = { added = "▓ ", modified = "▒ ", removed = "░ " },
			diff_color = {
				added = { fg = colors.foam },
				modified = { fg = colors.gold },
				removed = { fg = colors.love },
			},
		}

		local progress = {
			"progress",
			color = { fg = colors.subtle },
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
			function()
				local filepath = vim.fn.expand("%:p")
				if filepath == "" then
					return "[No Name]"
				end
				local cwd = vim.fn.getcwd()
				local relative_path = vim.fn.fnamemodify(filepath, ":~:.")

				-- If file is outside cwd, show path from home
				if not filepath:find(cwd, 1, true) then
					relative_path = vim.fn.fnamemodify(filepath, ":~")
				end

				-- Add status symbols
				local symbols = ""
				if vim.bo.modified then
					symbols = symbols .. "[+]"
				end
				if vim.bo.readonly then
					symbols = symbols .. "[-]"
				end
				if vim.bo.buftype == "nofile" then
					symbols = symbols .. "[New]"
				end

				return relative_path .. (symbols ~= "" and " " .. symbols or "")
			end,
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
					separator_left,
					lsp_status,
					diagnostics,
					separator_right,
				},
				lualine_c = {},
				lualine_x = {
					diff,
					separator_left,
					branch,
					separator_right,
					searchcount,
					separator_left,
					filename,
					progress,
					location,
					separator_right,
				},
				lualine_y = {},
				lualine_z = {},
			},
			winbar = {
				lualine_a = {},
				lualine_b = {},
				lualine_c = {},
				lualine_x = {},
				lualine_y = {},
				lualine_z = {},
			},
			inactive_winbar = {
				lualine_a = {},
				lualine_b = {},
				lualine_c = {},
				lualine_x = {},
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

		-- Refresh lualine when colorscheme changes
		vim.api.nvim_create_autocmd("ColorScheme", {
			pattern = "*",
			callback = function()
				-- Reload the entire config function to pick up new colors
				require("lualine").setup({
					options = {
						icons_enabled = true,
						theme = (function()
							local new_colors = get_colors()
							return {
								normal = {
									a = { fg = new_colors.base, bg = new_colors.rose, gui = "bold" },
									b = { fg = new_colors.text, bg = "NONE" },
									c = { fg = new_colors.text, bg = "NONE" },
								},
								insert = {
									a = { fg = new_colors.base, bg = new_colors.foam, gui = "bold" },
									b = { fg = new_colors.text, bg = "NONE" },
									c = { fg = new_colors.text, bg = "NONE" },
								},
								visual = {
									a = { fg = new_colors.base, bg = new_colors.iris, gui = "bold" },
									b = { fg = new_colors.text, bg = "NONE" },
									c = { fg = new_colors.text, bg = "NONE" },
								},
								replace = {
									a = { fg = new_colors.base, bg = new_colors.love, gui = "bold" },
									b = { fg = new_colors.text, bg = "NONE" },
									c = { fg = new_colors.text, bg = "NONE" },
								},
								command = {
									a = { fg = new_colors.base, bg = new_colors.gold, gui = "bold" },
									b = { fg = new_colors.text, bg = "NONE" },
									c = { fg = new_colors.text, bg = "NONE" },
								},
								inactive = {
									a = { fg = new_colors.muted, bg = "NONE" },
									b = { fg = new_colors.muted, bg = "NONE" },
									c = { fg = new_colors.muted, bg = "NONE" },
								},
							}
						end)(),
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
				})
			end,
		})
	end,
}
