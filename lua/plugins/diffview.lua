-- Diff review cockpit: the persistent changed-files panel that IS your
-- context when reviewing an LLM's uncommitted diff. Maintained fork of the
-- (frozen) sindrets/diffview.nvim — same commands, same API.
return {
	"dlyongemallo/diffview-plus.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	cmd = {
		"DiffviewOpen",
		"DiffviewClose",
		"DiffviewToggleFiles",
		"DiffviewFocusFiles",
		"DiffviewFileHistory",
	},
	keys = {
		{
			"<leader>gd",
			function()
				if next(require("diffview.lib").views) == nil then
					vim.cmd("DiffviewOpen")
				else
					vim.cmd("DiffviewClose")
				end
			end,
			desc = "Diff: review changes",
		},
		{
			"<leader>gD",
			function()
				-- Review the whole branch against its base — everything the LLM
				-- built here, INCLUDING brand-new files it hasn't committed yet.
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
				-- merge-base, so main's own newer commits don't show as reverse
				-- diffs. Opened as a single-rev WORKING-TREE view (not a `a...b`
				-- commit range): a range can only show committed trees, so new
				-- untracked/uncommitted files are invisible. The working-tree view
				-- diffs merge-base → your real files and includes untracked ones.
				local mb = vim.fn.systemlist("git merge-base " .. base .. " HEAD")[1]
				if not mb or mb == "" then
					mb = base
				end
				vim.cmd("DiffviewOpen " .. mb .. " --untracked-files=all")
			end,
			desc = "Diff: branch vs main (incl. new files)",
		},
		{ "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Diff: file history" },
		{ "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Diff: repo history" },
	},
	opts = {
		enhanced_diff_hl = true,
		-- Soft-wrap inside every diff window (long agent-written lines stay on
		-- screen instead of scrolling off the right edge). linebreak/breakindent
		-- keep the wrap tidy and aligned.
		hooks = {
			diff_buf_win_enter = function(_, winid)
				vim.wo[winid].wrap = true
				vim.wo[winid].linebreak = true
				vim.wo[winid].breakindent = true
			end,
		},
		view = {
			default = { winbar_info = true },
			merge_tool = { layout = "diff3_mixed" },
		},
		file_panel = {
			listing_style = "tree",
			win_config = { width = 32 },
		},
		keymaps = {
			view = {
				{ "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
			},
			file_panel = {
				{ "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close diffview" } },
			},
		},
	},
}
