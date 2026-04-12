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
				width = function()
					return math.floor(vim.o.columns * 0.85)
				end,
				height = function()
					return math.floor(vim.o.lines * 0.85)
				end,
			},
			shade_terminals = false,
		})

		local Terminal = require("toggleterm.terminal").Terminal

		local function on_open(term)
			local bopts = { noremap = true, silent = true }
			local bmap = function(lhs, rhs)
				vim.api.nvim_buf_set_keymap(term.bufnr, "t", lhs, rhs, bopts)
			end
			bmap("<C-_>", [[<C-\><C-n>]])
			bmap("<C-t>n", [[<C-\><C-n>]])
			bmap("<C-t><Right>", [[<cmd>tabnext<cr>]])
			bmap("<C-t><Left>", [[<cmd>tabprevious<cr>]])
			for i = 1, 9 do
				bmap("<C-t>" .. i, "<cmd>tabn " .. i .. "<cr>")
			end
		end

		local claude_float =
			Terminal:new({ cmd = "claude", direction = "float", hidden = true, display_name = "Claude", on_open = on_open })
		local claude_vertical =
			Terminal:new({ cmd = "claude", direction = "vertical", hidden = true, display_name = "Claude", on_open = on_open })
		local claude_tab = Terminal:new({ cmd = "claude", direction = "tab", hidden = true, display_name = "Claude", on_open = on_open })

		local claude_terms = { claude_float, claude_vertical, claude_tab }

		local function toggle_claude(term)
			for _, t in ipairs(claude_terms) do
				if t ~= term and t:is_open() then
					t:close()
				end
			end
			term:toggle()
		end

		vim.keymap.set("n", "<leader>cf", function()
			toggle_claude(claude_float)
		end, { desc = "Claude (float)" })
		vim.keymap.set("n", "<leader>cv", function()
			toggle_claude(claude_vertical)
		end, { desc = "Claude (vertical)" })
		vim.keymap.set("n", "<leader>ct", function()
			toggle_claude(claude_tab)
		end, { desc = "Claude (tab)" })
		vim.keymap.set("n", "<leader>cq", function()
			for _, t in ipairs(claude_terms) do
				if t:is_open() then
					t:close()
				end
			end
		end, { desc = "Close Claude terms" })
	end,
}
