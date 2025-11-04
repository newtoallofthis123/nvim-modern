return {
	"stevearc/quicker.nvim",
	ft = "qf",
	opts = {},
	config = function(_, opts)
		require("quicker").setup(opts)
		vim.keymap.set("n", "<leader>qq", function()
			require("quicker").toggle()
		end, {
			desc = "Toggle quickfix",
		})
	end,
}
