return {
	"leonardcser/cursortab.nvim",
	build = "cd server && go build",
	config = function()
		require("cursortab").setup({
			provider = {
				type = "sweep",
				url = "http://localhost:8585",
				model = "sweep-next-edit-1.5b",
			},
		})
	end,
}
