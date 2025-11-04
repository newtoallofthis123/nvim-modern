return {
	"saghen/blink.cmp",
	dependencies = {
		"rafamadriz/friendly-snippets",
		"fang2hou/blink-copilot",
		"saghen/blink.compat",
		"moyiz/blink-emoji.nvim",
	},
	version = "1.*",
	opts = {
		keymap = {
			preset = "default",
			["<CR>"] = { "accept", "fallback" },
			["<S-Tab>"] = { "snippet_backward", "fallback" },
			["<Tab>"] = {
				function(cmp)
					if cmp.snippet_active() then
						return cmp.accept()
					else
						return cmp.select_and_accept()
					end
				end,
				function()
					if vim.fn.pumvisible() == 1 then
						vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-y>", true, false, true), "n", false)
						return true
					else
						return false
					end
				end,
				"snippet_forward",
				"fallback",
			},
		},

		appearance = {
			use_nvim_cmp_as_default = true,
			nerd_font_variant = "mono",
		},

		completion = {
			documentation = { auto_show = false, window = { border = "single" } },
			menu = {
				border = "single",
				auto_show = function(ctx)
					return ctx.mode ~= "cmdline" or not vim.tbl_contains({ "/", "?" }, vim.fn.getcmdtype())
				end,
			},
		},

		sources = {
			default = { "copilot", "lsp", "snippets", "buffer", "emoji", "path" },
			providers = {
				copilot = {
					name = "copilot",
					module = "blink-copilot",
					score_offset = 100,
					async = true,
				},
				emoji = {
					module = "blink-emoji",
					name = "Emoji",
					opts = {
						insert = true,
						trigger = function()
							return { ":" }
						end,
					},
					should_show_items = function()
						return vim.tbl_contains({ "gitcommit", "markdown" }, vim.o.filetype)
					end,
				},
			},
		},

		fuzzy = { implementation = "prefer_rust_with_warning" },
		signature = { window = { border = "single" } },
	},
	opts_extend = { "sources.default" },
}
