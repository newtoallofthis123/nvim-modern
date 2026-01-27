return {
	"serhez/bento.nvim",
	event = "VeryLazy",
	opts = {
		-- Main keymap to toggle bento menu
		main_keymap = "<leader>bm",

		-- Automatic buffer cleanup - keeps up to 20 buffers open
		-- This helps prevent buffer clutter without manual management
		max_open_buffers = 20,

		-- Use frecency (frequency + recency) for smart buffer deletion
		-- Buffers you use often are kept, rarely-used ones are auto-deleted
		buffer_deletion_metric = "frecency_access",

		-- Order buffers by access time (most recently used first)
		ordering_metric = "access",

		ui = {
			-- Use floating window to match your other plugins (snipe, harpoon)
			mode = "floating",
		},
	},
	keys = {
		{
			"<leader>bm",
			desc = "Open Bento buffer menu",
		},
		-- Quick buffer deletion from normal mode
		{
			"<leader>bd",
			function()
				-- Open bento in delete mode
				require("bento").open()
				-- Simulate pressing backspace to enter delete mode
				vim.defer_fn(function()
					vim.api.nvim_feedkeys(
						vim.api.nvim_replace_termcodes("<BS>", true, false, true),
						"n",
						false
					)
				end, 50)
			end,
			desc = "Delete buffers (Bento)",
		},
	},
}
