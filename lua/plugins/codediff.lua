-- VSCode-grade two-tier diffing. Standalone here (the review.nvim layer that
-- used to sit on top was removed; the PR hub now diffs PRs in Diffview).
--   <leader>rd  :CodeDiff             — git status diff explorer (working tree)
--   <leader>rD  :CodeDiff main...     — PR-style diff vs main/master (merge-base)
return {
	"esmuellert/codediff.nvim",
	cmd = "CodeDiff",
	keys = {
		{ "<leader>rd", "<cmd>CodeDiff<cr>", desc = "CodeDiff: explorer (working tree)" },
		{
			"<leader>rD",
			function()
				local base
				for _, b in ipairs({ "origin/main", "origin/master", "main", "master" }) do
					vim.fn.system("git rev-parse --verify " .. b)
					if vim.v.shell_error == 0 then
						base = b
						break
					end
				end
				if not base then
					vim.notify("No main/master branch found", vim.log.levels.WARN)
					return
				end
				vim.cmd("CodeDiff " .. base .. "...")
			end,
			desc = "CodeDiff: branch vs main (PR-style)",
		},
	},
	opts = {
		diff = {
			layout = "side-by-side",
			jump_to_first_change = true,
		},
		keymaps = {
			view = {
				next_file = "<Tab>", -- diffview muscle memory (default ]f)
				prev_file = "<S-Tab>", -- (default [f)
				show_help = "?", -- (default g?)
			},
		},
	},
}
