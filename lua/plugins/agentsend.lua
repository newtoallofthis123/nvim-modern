vim.api.nvim_create_autocmd("User", {
	pattern = "VeryLazy",
	callback = function()
		require("custom.agentsend").setup()
	end,
})

return {}
