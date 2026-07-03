-- Fire the current review.nvim session's exported markdown into the agent
-- pane as its next brief.
--
-- Calls review.nvim's own markdown generator (review.export.generate_markdown)
-- directly -- a real module function, not clipboard-scraping behind
-- `:Review export`. Reuses custom.agentsend's pane-resolution + bracketed-
-- paste plumbing so targeting (current window, then session, sticky target)
-- matches every other agent-paste path in this config.

local M = {}

local agentsend = require("custom.agentsend")

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "ReviewBridge" })
end

local HEADER = "Review feedback on this worktree's changes — address each comment:\n\n"

---@param opts? { repick?: boolean }
function M.send_brief(opts)
	opts = opts or {}
	if not vim.env.TMUX then
		notify("Not inside tmux", vim.log.levels.WARN)
		return
	end

	local ok_export, review_export = pcall(require, "review.export")
	if not ok_export then
		notify("review.nvim not installed", vim.log.levels.ERROR)
		return
	end

	local ok_store, store = pcall(require, "review.store")
	if ok_store and store.count() == 0 then
		notify("No review comments to send", vim.log.levels.WARN)
		return
	end

	local markdown = review_export.generate_markdown()
	if markdown == "No comments yet." then
		notify("No review comments to send", vim.log.levels.WARN)
		return
	end

	local text = HEADER .. markdown

	local panes = agentsend.list_agent_panes()
	if not panes then
		notify("tmux query failed", vim.log.levels.ERROR)
		return
	end
	if #panes == 0 then
		notify("No tagged agent session (@app) found", vim.log.levels.WARN)
		return
	end
	panes = agentsend.narrow_to_cwd(panes)

	agentsend.resolve_target(panes, opts.repick, function(pane)
		agentsend.paste_raw(pane, text)
	end)
end

function M.setup()
	vim.keymap.set("n", "<leader>rb", function()
		M.send_brief()
	end, { desc = "Review: send export as agent brief" })
end

return M
