return {
	"folke/persistence.nvim",
	event = "BufReadPre",
	opts = {},
	config = function(_, opts)
		require("persistence").setup(opts)

		vim.keymap.set("n", "<leader>qs", function()
			require("persistence").load()
		end, { desc = "Load session for current directory" })

		vim.keymap.set("n", "<leader>qS", function()
			require("persistence").select()
		end, { desc = "Select session to load" })

		vim.keymap.set("n", "<leader>ql", function()
			require("persistence").load({ last = true })
		end, { desc = "Load last session" })

		vim.keymap.set("n", "<leader>qd", function()
			require("persistence").stop()
		end, { desc = "Stop session persistence" })
	end,
}
