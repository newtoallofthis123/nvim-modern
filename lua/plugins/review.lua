-- VSCode-grade two-tier diffing (codediff.nvim) plus a review layer on top
-- (review.nvim) that lets you annotate hunks and EXPORT the annotated
-- review as AI-ready markdown — the actual point of installing this.
--
-- Nested under the existing <leader>r ("refactor") group since every other
-- single-letter leader is already spoken for:
--   <leader>rd  :CodeDiff             — git status diff explorer (working tree)
--   <leader>rD  :CodeDiff main...     — PR-style diff vs main/master (merge-base)
--   <leader>rr  :Review               — open review session (staged/unstaged)
--   <leader>rR  :Review commits       — pick commit(s) to review
--
-- Once inside a review session, review.nvim's own keymaps take over:
--   i add comment · d delete · e edit · c list all · ]n/[n jump between
--   C export to clipboard · S send to sidekick.nvim · q close + export
-- `:Review export` / `:Review preview` also work from the command line.
return {
	{
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
		},
	},
	{
		"georgeguimaraes/review.nvim",
		version = "v*",
		dependencies = {
			"esmuellert/codediff.nvim",
			"MunifTanjim/nui.nvim",
		},
		cmd = { "Review" },
		keys = {
			{ "<leader>rr", "<cmd>Review<cr>", desc = "Review: open (staged/unstaged)" },
			{ "<leader>rR", "<cmd>Review commits<cr>", desc = "Review: pick commit(s)" },
		},
		opts = {},
	},
}
