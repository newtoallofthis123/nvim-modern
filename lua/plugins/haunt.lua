return {
	"TheNoeTrevino/haunt.nvim",
	opts = {
		sign = "󱙝",
		sign_hl = "DiagnosticInfo",
		virt_text_hl = "HauntAnnotation",
		annotation_prefix = " 󰆉 ",
		line_hl = nil,
		virt_text_pos = "eol",
		data_dir = nil,
		picker_keys = {
			delete = { key = "d", mode = { "n" } },
			edit_annotation = { key = "a", mode = { "n" } },
		},
	},
	-- recommended keymaps, with a helpful prefix alias
	init = function()
		local haunt = require("haunt.api")
		local haunt_picker = require("haunt.picker")
		local map = vim.keymap.set
		local prefix = "<leader>n"

		-- annotations
		map("n", prefix .. "a", function()
			haunt.annotate()
		end, { desc = "Annotate" })

		map("n", prefix .. "t", function()
			haunt.toggle_annotation()
		end, { desc = "Toggle annotation" })

		-- picker
		map("n", prefix .. "l", function()
			haunt_picker.show()
		end, { desc = "Show Picker" })
	end,
}
