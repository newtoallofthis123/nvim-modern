return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		build = ":TSUpdate",
		dependencies = {
			{ "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" },
			"windwp/nvim-ts-autotag",
		},
		init = function()
			vim.api.nvim_create_autocmd("FileType", {
				callback = function()
					pcall(vim.treesitter.start)
					vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end,
			})
		end,
		config = function()
			local ts = require("nvim-treesitter")
			local cfg = require("nvim-treesitter.config")

			local ensure_installed = {
				"json",
				"javascript",
				"typescript",
				"tsx",
				"yaml",
				"html",
				"css",
				"prisma",
				"svelte",
				"graphql",
				"bash",
				"dockerfile",
				"gitignore",
			}
			local installed = cfg.get_installed()
			local to_install = vim.iter(ensure_installed)
				:filter(function(p)
					return not vim.tbl_contains(installed, p)
				end)
				:totable()
			if #to_install > 0 then
				ts.install(to_install)
			end
		end,
	},
}
