return {
	"nvim-mini/mini.nvim",
	event = "VeryLazy",
	config = function()
		local ai = require("mini.ai")
		ai.setup({
			custom_textobjects = {
				-- treesitter-aware: vaf/vif (function), vac/vic (class),
				-- vao/vio (loop/conditional). `a` (argument) is built in.
				f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
				c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
				o = ai.gen_spec.treesitter({
					a = { "@conditional.outer", "@loop.outer" },
					i = { "@conditional.inner", "@loop.inner" },
				}),
			},
		})

		-- Operators: gx{motion} twice = exchange two regions (args, blocks,
		-- paragraphs — no register juggling); gs{motion} = sort lines/args.
		-- The other three (replace/multiply/evaluate) stay off: gr belongs
		-- to LSP, and unused operators are just keymap noise.
		require("mini.operators").setup({
			exchange = { prefix = "gx" },
			sort = { prefix = "gs" },
			replace = { prefix = "" },
			multiply = { prefix = "" },
			evaluate = { prefix = "" },
		})
	end,
}
