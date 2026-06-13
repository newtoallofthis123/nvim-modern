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
	keys = {
		{
			"<leader>na",
			function()
				require("haunt.api").annotate()
			end,
			desc = "Haunt: annotate",
		},
		{
			"<leader>nt",
			function()
				require("haunt.api").toggle_annotation()
			end,
			desc = "Haunt: toggle annotation",
		},
		{
			"<leader>nl",
			function()
				require("haunt.picker").show()
			end,
			desc = "Haunt: show picker",
		},
	},
}
