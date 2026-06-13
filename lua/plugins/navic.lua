-- LSP symbol breadcrumb for the STATUSLINE (dropbar is winbar-only; navic is
-- built for embedding in lualine). Attached manually from lspconfig's LspAttach.
return {
	"SmiteshP/nvim-navic",
	lazy = true,
	opts = {
		separator = " › ",
		highlight = true,
		depth_limit = 0,
		lsp = { auto_attach = false },
	},
	config = function(_, opts)
		require("nvim-navic").setup(opts)
		-- Quiet text + separators; kind-icons keep their meaningful color
		local function tune()
			vim.api.nvim_set_hl(0, "NavicText", { fg = "#908caa", bg = "NONE" })
			vim.api.nvim_set_hl(0, "NavicSeparator", { fg = "#6e6a86", bg = "NONE" })
		end
		tune()
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("navic-quiet", { clear = true }),
			callback = tune,
		})
	end,
}
