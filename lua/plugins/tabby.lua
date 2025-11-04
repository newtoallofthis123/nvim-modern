return {
	"nanozuki/tabby.nvim",
	config = function()
		local theme = {
			fill = "TabLineFill",
			head = "TabLine",
			current_tab = "TabLineSel",
			tab = "TabLine",
			win = "TabLine",
			tail = "TabLine",
		}

		require("tabby").setup({
			line = function(line)
				return {
					{
						{ "NOOBSCIENCE ", hl = theme.head },
						line.sep(" ", theme.head, theme.fill),
					},
					line.tabs().foreach(function(tab)
						local hl = tab.is_current() and theme.current_tab or theme.tab
						return {
							-- tab.is_current() and "󱐋" or "",
							tab.number(),
							tab.name(),
							tab.close_btn(""),
							line.sep(" ", theme.tab, theme.fill),
							hl = hl,
							margin = " ",
						}
					end),
					line.spacer(),
					line.wins_in_tab(line.api.get_current_tab()).foreach(function(win)
						return {
							win.buf_name(),
							line.sep(" ", theme.tab, theme.fill),
							hl = theme.win,
							margin = " ",
						}
					end),
					{
						{ "", hl = theme.tail },
					},
					hl = theme.fill,
				}
			end,
		})
	end,
	keys = {
		{ "<leader>tt", ":Tabby pick_window<CR>", desc = "Pick a window to focus" },
	},
}
