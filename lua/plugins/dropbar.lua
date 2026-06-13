-- Winbar breadcrumb: dimmed path + bright filename + LSP symbol trail.
-- Answers "where am I" at a glance. Zero-dependency, native LSP + treesitter.
return {
	"Bekaboo/dropbar.nvim",
	event = { "BufReadPost", "BufNewFile" },
	keys = {
		{
			"<leader>;",
			function()
				require("dropbar.api").pick()
			end,
			desc = "Winbar: pick / jump context",
		},
	},
	opts = {
		bar = {
			-- keep it quiet in special buffers
			enable = function(buf, win, _)
				if vim.bo[buf].buftype ~= "" or vim.fn.win_gettype(win) ~= "" then
					return false
				end
				return vim.bo[buf].buflisted and vim.api.nvim_buf_get_name(buf) ~= ""
			end,
		},
		icons = {
			ui = { bar = { separator = "  ", extends = "…" } },
		},
	},
	config = function(_, opts)
		require("dropbar").setup(opts)

		-- Transparent winbar (it otherwise inherits StatusLine's background)
		local function transparent()
			for _, g in ipairs({ "WinBar", "WinBarNC", "DropBarCurrentContext", "DropBarMenuCurrentContext" }) do
				vim.api.nvim_set_hl(0, g, { bg = "NONE" })
			end
		end
		transparent()
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("dropbar-transparent", { clear = true }),
			callback = transparent,
		})
	end,
}
