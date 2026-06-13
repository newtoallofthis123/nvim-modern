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
	end,
}
