-- Loads the PR hub (custom/pr.lua) once the UI is up. setup() is idempotent;
-- lualine also calls it for the statusline component.
vim.api.nvim_create_autocmd("User", {
	pattern = "VeryLazy",
	callback = function()
		require("custom.pr").setup()
	end,
})

return {}
