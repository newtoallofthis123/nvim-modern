-- Diff review cockpit: the persistent changed-files panel that IS your
-- context when reviewing an LLM's uncommitted diff. Maintained fork of the
-- (frozen) sindrets/diffview.nvim — same commands, same API.
return {
	"dlyongemallo/diffview-plus.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	cmd = {
		"DiffviewOpen",
		"DiffviewClose",
		"DiffviewToggleFiles",
		"DiffviewFocusFiles",
		"DiffviewFileHistory",
	},
	keys = {
		{
			"<leader>gd",
			function()
				if next(require("diffview.lib").views) == nil then
					vim.cmd("DiffviewOpen")
				else
					vim.cmd("DiffviewClose")
				end
			end,
			desc = "Diff: review changes",
		},
		{ "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Diff: file history" },
		{ "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Diff: repo history" },
	},
	opts = {
		enhanced_diff_hl = true,
		view = {
			default = { winbar_info = true },
			merge_tool = { layout = "diff3_mixed" },
		},
		file_panel = {
			listing_style = "tree",
			win_config = { width = 32 },
		},
		keymaps = {
			view = {
				{ "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
			},
			file_panel = {
				{ "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
			},
		},
	},
}
