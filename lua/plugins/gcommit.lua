vim.api.nvim_create_autocmd("User", {
	pattern = "VeryLazy",
	callback = function()
		require("custom.gcommit").setup()
	end,
})

return {}
