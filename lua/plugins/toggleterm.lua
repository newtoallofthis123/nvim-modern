return {
	"akinsho/toggleterm.nvim",
	version = "*",
	keys = {
		{ "<leader>cf", desc = "Claude (float)" },
		{ "<leader>cv", desc = "Claude (vertical)" },
		{ "<leader>ct", desc = "Claude (tab)" },
		{ "<leader>cq", desc = "Close Claude terms" },
		{ "<leader>`", "<cmd>ToggleTerm direction=horizontal<cr>", desc = "Toggle terminal (horizontal)" },
		{ "<leader>~", "<cmd>ToggleTerm direction=tab<cr>", desc = "Toggle terminal (tab)" },
	},
	config = function()
		require("toggleterm").setup({
			size = function(term)
				if term.direction == "horizontal" then
					return 15
				elseif term.direction == "vertical" then
					return vim.o.columns * 0.4
				end
			end,
			float_opts = {
				border = "curved",
				width = function() return math.floor(vim.o.columns * 0.85) end,
				height = function() return math.floor(vim.o.lines * 0.85) end,
			},
			shade_terminals = false,
			on_open = function(term)
				vim.api.nvim_buf_set_keymap(term.bufnr, "t", "<S-Esc>", [[<C-\><C-n>]], { noremap = true, silent = true })
			end,
		})

		local Terminal = require("toggleterm.terminal").Terminal

		local claude_float = Terminal:new({ cmd = "claude", direction = "float", hidden = true, display_name = "Claude" })
		local claude_vertical = Terminal:new({ cmd = "claude", direction = "vertical", hidden = true, display_name = "Claude" })
		local claude_tab = Terminal:new({ cmd = "claude", direction = "tab", hidden = true, display_name = "Claude" })

		local claude_terms = { claude_float, claude_vertical, claude_tab }

		local function toggle_claude(term)
			for _, t in ipairs(claude_terms) do
				if t ~= term and t:is_open() then
					t:close()
				end
			end
			term:toggle()
		end

		vim.keymap.set("n", "<leader>cf", function() toggle_claude(claude_float) end, { desc = "Claude (float)" })
		vim.keymap.set("n", "<leader>cv", function() toggle_claude(claude_vertical) end, { desc = "Claude (vertical)" })
		vim.keymap.set("n", "<leader>ct", function() toggle_claude(claude_tab) end, { desc = "Claude (tab)" })
		vim.keymap.set("n", "<leader>cq", function()
			for _, t in ipairs(claude_terms) do
				if t:is_open() then
					t:close()
				end
			end
		end, { desc = "Close Claude terms" })
	end,
}
