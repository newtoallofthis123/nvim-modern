return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		-- Function to get colors based on current colorscheme and background
		local function get_colors()
			local colorscheme = vim.g.colors_name or "gruvbox"
			local background = vim.o.background or "dark"

			if colorscheme == "gruvbox" then
				if background == "light" then
					-- Gruvbox light colors
					return {
						rose = "#cc241d",
						pine = "#458588",
						foam = "#689d6a",
						iris = "#b16286",
						gold = "#d79921",
						love = "#cc241d",
						base = "#fbf1c7",
						surface = "#f9f5d7",
						overlay = "#ebdbb2",
						muted = "#928374",
						subtle = "#7c6f64",
						text = "#3c3836",
					}
				else
					-- Gruvbox dark colors
					return {
						rose = "#fb4934",
						pine = "#83a598",
						foam = "#8ec07c",
						iris = "#d3869b",
						gold = "#fabd2f",
						love = "#fb4934",
						base = "#282828",
						surface = "#32302f",
						overlay = "#504945",
						muted = "#928374",
						subtle = "#665c54",
						text = "#ebdbb2",
					}
				end
			elseif colorscheme == "lunaperche" then
				if background == "light" then
					-- Lunaperche light mode
					return {
						rose = "#FFD700",
						pine = "#87CEEB",
						foam = "#87CEEB",
						iris = "#C0C0C0",
						gold = "#FFD700",
						love = "#FFD700",
						base = "#FFFFFF",
						surface = "#F0F0F0",
						overlay = "#E0E0E0",
						muted = "#AAAAAA",
						subtle = "#777777",
						text = "#000000",
					}
				else
					-- Lunaperche dark mode
					return {
						rose = "#FFD700",
						pine = "#87CEEB",
						foam = "#87CEEB",
						iris = "#C0C0C0",
						gold = "#FFD700",
						love = "#FFD700",
						base = "#000000",
						surface = "#111111",
						overlay = "#1A1A1A",
						muted = "#555555",
						subtle = "#888888",
						text = "#FFFFFF",
					}
				end
			else
				-- Gruvbox dark (default)
				return {
					rose = "#fb4934",
					pine = "#83a598",
					foam = "#8ec07c",
					iris = "#d3869b",
					gold = "#fabd2f",
					love = "#fb4934",
					base = "#282828",
					surface = "#32302f",
					overlay = "#504945",
					muted = "#928374",
					subtle = "#665c54",
					text = "#ebdbb2",
				}
			end
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
