return {
	"aserowy/tmux.nvim",
	event = "VeryLazy",
	opts = {
		swap = {
			cycle_navigation = true,
		},
		copy_sync = {
			-- these keymaps hijack " and <C-R>, clobbering registers.nvim's popup
			sync_registers_keymap_put = false,
			sync_registers_keymap_reg = false,
		},
	},
}
