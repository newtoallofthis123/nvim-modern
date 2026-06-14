return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		preset = "helix",
		spec = {
			{ "<leader>a", group = "agent (claude/codex)" },
			{ "<leader>b", group = "buffer" },
			{ "<leader>c", group = "copy context (LLM)" },
			{ "<leader>f", group = "find / search" },
			{ "<leader>g", group = "git" },
			{ "<leader>h", group = "hunks (gitsigns)" },
			{ "<leader>l", group = "lsp" },
			{ "<leader>n", group = "notes" },
			{ "<leader>q", group = "session" },
			{ "<leader>t", group = "tab / toggle" },
			{ "<leader>u", group = "ui toggle" },
			{ "<leader>v", group = "diagnostics" },
			{ "<leader>w", group = "window" },
			{ "<leader>x", group = "tools" },
			{ "<leader>z", group = "harpoon nav" },
			{ "<leader>r", group = "refactor" },
			{ "<leader>s", group = "satchel" },
			{ "<leader>sa", group = "toss node" },
			{ "<leader>sA", group = "toss node → ticket" },
		},
	},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer Local Keymaps (which-key)",
		},
	},
}
