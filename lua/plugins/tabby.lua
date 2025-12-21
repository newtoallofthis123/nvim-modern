	return {
		"nanozuki/tabby.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			local theme = {
				fill = "TabLineFill",
				head = "TabLineHeader",
				current_tab = "TabLineSel",
				tab = "TabLine",
				win = "TabLine",
				tail = "TabLine",
			}

			require("tabby").setup({
				line = function(line)
					return {
						{
							{ " ▌NOOBSCIENCE  ", hl = theme.head },
						},
						line.tabs().foreach(function(tab)
							local hl = tab.is_current() and theme.current_tab or theme.tab

							-- Get info for current tab
							local wins = line.wins_in_tab(tab.id)
							local icon = ""
							local modified = ""

							if #wins > 0 then
								local bufnr = wins[1].buf().id
								local bufname = vim.api.nvim_buf_get_name(bufnr)
								local filename = vim.fn.fnamemodify(bufname, ":t")
								local is_modified = vim.api.nvim_get_option_value("modified", { buf = bufnr })

								-- Get file icon
								local ok, devicons = pcall(require, "nvim-web-devicons")
								if ok and filename ~= "" then
									local file_icon =
										devicons.get_icon(filename, vim.fn.fnamemodify(filename, ":e"), { default = true })
									icon = (file_icon or "") .. " "
								end

								-- Modified indicator (blocky)
								modified = is_modified and " ▓" or ""
							end

							return {
								"|",
								tab.number(),
								" ",
								icon,
								tab.name(),
								modified,
								"|",
								hl = hl,
								margin = "  ",
							}
						end),
						line.spacer(),
						{
							{ " ", hl = theme.tail },
						},
						hl = theme.fill,
					}
				end,
			})

			-- Set transparent tab highlights
			vim.api.nvim_set_hl(0, "TabLine", { bg = "NONE" })
			vim.api.nvim_set_hl(0, "TabLineFill", { bg = "NONE" })
			vim.api.nvim_set_hl(0, "TabLineSel", { bg = "NONE" })

			-- Custom header highlight with yellow color
			vim.api.nvim_set_hl(0, "TabLineHeader", { fg = "#f6c177", bg = "NONE", bold = true })

			-- Transparent winbar
			vim.api.nvim_set_hl(0, "WinBar", { bg = "NONE" })
			vim.api.nvim_set_hl(0, "WinBarNC", { bg = "NONE" })
		end,
		keys = {
			{ "<leader>tt", ":Tabby pick_window<CR>", desc = "Pick a window to focus" },
		},
	}
