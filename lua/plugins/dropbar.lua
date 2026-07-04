-- Winbar breadcrumb: dimmed path + bright filename + LSP symbol trail.
-- DISABLED experiment: symbols moved to the statusline via nvim-navic to
-- declutter the top (tabline + winbar felt crowded). Flip enabled=true to
-- bring the winbar back.
return {
	enabled = false,
	"Bekaboo/dropbar.nvim",
	event = { "BufReadPost", "BufNewFile" },
	keys = {
		{
			"<leader>;",
			function()
				require("dropbar.api").pick()
			end,
			desc = "Winbar: pick / jump context",
		},
	},
	opts = {
		bar = {
			-- keep it quiet in special buffers
			enable = function(buf, win, _)
				if vim.bo[buf].buftype ~= "" or vim.fn.win_gettype(win) ~= "" then
					return false
				end
				return vim.bo[buf].buflisted and vim.api.nvim_buf_get_name(buf) ~= ""
			end,
		},
		icons = {
			ui = { bar = { separator = "  ", extends = "…" } },
		},
	},
}
