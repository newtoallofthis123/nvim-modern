return {
	"zbirenbaum/copilot.lua",
	cmd = "Copilot",
	event = "InsertEnter",
	dependencies = {
		"copilotlsp-nvim/copilot-lsp",
	},
	config = function()
		require("copilot").setup({
			suggestion = {
				enabled = false,
			},
			nes = {
				enabled = false, -- requires copilot-lsp as a dependency
				auto_trigger = false,
				keymap = {
					accept_and_goto = "<leader>c",
					accept = false,
					dismiss = "<Esc>",
				},
			},
		})
	end,
}
