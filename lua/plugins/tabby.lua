return {
	"nanozuki/tabby.nvim",
	event = "VeryLazy",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		local c = {
			gold = "#f6c177",
			muted = "#6e6a86",
			subtle = "#908caa",
			love = "#eb6f92",
		}

		require("tabby").setup({
			line = function(line)
				-- left: the active satchel ticket (muted name + gold count), if any
				local ticket = ""
				do
					local ok, s = pcall(require, "custom.satchel")
					if ok and s.is_active() then
						ticket = {
							{ "  " .. s.label() .. " ", hl = { fg = c.muted, bg = "NONE" } },
							{ s.count() .. "  ", hl = { fg = c.gold, bg = "NONE" } },
						}
					end
				end

				return {
					ticket,
					line.tabs().foreach(function(tab)
						local current = tab.is_current()
						local fg = current and c.gold or c.muted

						local icon, modified = "", ""
						local wins = line.wins_in_tab(tab.id)
						if #wins > 0 then
							local bufnr = wins[1].buf().id
							local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t")
							local ok, devicons = pcall(require, "nvim-web-devicons")
							if ok and filename ~= "" then
								local file_icon = devicons.get_icon(filename, vim.fn.fnamemodify(filename, ":e"), { default = true })
								icon = (file_icon or "") .. " "
							end
							if vim.api.nvim_get_option_value("modified", { buf = bufnr }) then
								modified = " ●"
							end
						end

						return {
							" ",
							tab.number(),
							icon,
							tab.name(),
							modified,
							" ",
							hl = { fg = fg, bg = "NONE", style = current and "bold" or nil },
							margin = " ",
						}
					end),
					line.spacer(),
					hl = { bg = "NONE" },
				}
			end,
		})

		-- transparent tabline groups
		for _, g in ipairs({ "TabLine", "TabLineFill", "TabLineSel" }) do
			vim.api.nvim_set_hl(0, g, { bg = "NONE" })
		end
	end,
	keys = {
		{ "<leader>tt", ":Tabby pick_window<CR>", desc = "Pick a window to focus" },
	},
}
