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
				-- langs you actually use
				"lua",
				"luadoc",
				"rust",
				"go",
				"gomod",
				"gosum",
				"gowork",
				"elixir",
				"heex",
				"eex",
				"python",
				"markdown",
				"markdown_inline",
				-- web
				"json",
				"json5",
				"javascript",
				"typescript",
				"tsx",
				"html",
				"css",
				"scss",
				"prisma",
				"svelte",
				"graphql",
				"yaml",
				"toml",
				-- shell / infra / git / nvim
				"bash",
				"dockerfile",
				"gitignore",
				"gitcommit",
				"git_rebase",
				"diff",
				"regex",
				"comment",
				"query",
				"vim",
				"vimdoc",
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

			-- Text objects: move between + swap (selection af/if etc. is handled
			-- by mini.ai with treesitter specs — see mini.lua)
			require("nvim-treesitter-textobjects").setup({
				move = { set_jumps = true },
			})

			local move = require("nvim-treesitter-textobjects.move")
			local swap = require("nvim-treesitter-textobjects.swap")
			local map = vim.keymap.set

			map({ "n", "x", "o" }, "]f", function()
				move.goto_next_start("@function.outer", "textobjects")
			end, { desc = "Next function" })
			map({ "n", "x", "o" }, "[f", function()
				move.goto_previous_start("@function.outer", "textobjects")
			end, { desc = "Prev function" })
			map({ "n", "x", "o" }, "]a", function()
				move.goto_next_start("@parameter.inner", "textobjects")
			end, { desc = "Next argument" })
			map({ "n", "x", "o" }, "[a", function()
				move.goto_previous_start("@parameter.inner", "textobjects")
			end, { desc = "Prev argument" })

			map("n", "<leader>rs", function()
				swap.swap_next("@parameter.inner")
			end, { desc = "Swap argument with next" })
			map("n", "<leader>rS", function()
				swap.swap_previous("@parameter.inner")
			end, { desc = "Swap argument with prev" })
		end,
	},
}
