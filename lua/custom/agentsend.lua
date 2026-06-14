-- Send an @file ref straight into a Claude Code / Codex session living in the
-- same tmux window. Reuses the ref formatters from custom.copy.
--
-- Mechanism notes (why it's done this way):
--  * Hooks can't pre-fill an agent's composer -- they only react to events.
--    So injection has to come from outside, via tmux.
--  * Both TUIs open a fuzzy file-picker the instant they see a typed `@`.
--    Sending keystrokes would hijack into that picker. Bracketed paste
--    (`tmux paste-buffer -p`) is routed through a separate path that inserts
--    literal text without triggering it.
--  * claude understands `@file#line` / `@file#10-20`. codex has no line
--    syntax on input, so the line is appended as prose: `@file (line 42)`.

local M = {}

local copy = require("custom.copy")

-- Agents we know how to talk to, keyed by tmux `pane_current_command`.
local AGENTS = { claude = true, codex = true }

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "AgentSend" })
end

-- Format the ref for the target agent. `line` is "42" or "10-20".
local function format_ref(agent, path, line)
	if agent == "codex" then
		local noun = line:find("-", 1, true) and "lines" or "line"
		return string.format("@%s (%s %s) ", path, noun, line)
	end
	-- claude (and default): native #line anchor
	return string.format("@%s#%s ", path, line)
end

-- List agent panes in the current tmux window, excluding our own pane.
local function list_agent_panes()
	local self_pane = vim.env.TMUX_PANE
	local out = vim.fn.systemlist({
		"tmux",
		"list-panes",
		"-F",
		"#{pane_id}\t#{pane_current_command}\t#{pane_current_path}\t#{pane_title}",
	})
	if vim.v.shell_error ~= 0 then
		return nil
	end

	local panes = {}
	for _, l in ipairs(out) do
		local parts = vim.split(l, "\t", { plain = true })
		local id, cmd, path, title = parts[1], parts[2], parts[3], parts[4]
		if id and AGENTS[cmd] and id ~= self_pane then
			table.insert(panes, { id = id, cmd = cmd, path = path, title = title or "" })
		end
	end
	return panes
end

-- Soft-narrow to sessions launched in (or around) the current project.
local function narrow_to_cwd(panes)
	local cwd = vim.fn.getcwd()
	local matched = vim.tbl_filter(function(p)
		return p.path == cwd or vim.startswith(cwd, p.path .. "/") or vim.startswith(p.path, cwd .. "/")
	end, panes)
	-- only narrow if it leaves something; otherwise keep the full list
	return #matched > 0 and matched or panes
end

-- Paste text into a pane as a bracketed paste (won't trigger the @ picker).
local function inject(pane, path, line)
	local text = format_ref(pane.cmd, path, line)
	vim.fn.system({ "tmux", "set-buffer", "-b", "nvim-agentref", "--", text })
	vim.fn.system({ "tmux", "paste-buffer", "-p", "-d", "-b", "nvim-agentref", "-t", pane.id })
	if vim.v.shell_error ~= 0 then
		notify("Failed to paste into " .. pane.cmd, vim.log.levels.ERROR)
		return
	end
	notify(string.format("Sent %sto %s [%s]", text, pane.cmd, pane.id))
end

function M.send()
	if not vim.env.TMUX then
		notify("Not inside tmux", vim.log.levels.WARN)
		return
	end

	-- Capture path + line synchronously, before any picker changes mode/marks.
	local path = copy.get_relative_filepath()
	if path == "[No Name]" then
		notify("No file to reference", vim.log.levels.WARN)
		return
	end
	local line = copy.get_current_line_or_range()

	local panes = list_agent_panes()
	if not panes then
		notify("tmux query failed", vim.log.levels.ERROR)
		return
	end
	if #panes == 0 then
		notify("No claude/codex session in this window", vim.log.levels.WARN)
		return
	end

	panes = narrow_to_cwd(panes)

	if #panes == 1 then
		inject(panes[1], path, line)
		return
	end

	local picker = (Snacks and Snacks.picker and Snacks.picker.select) or vim.ui.select
	picker(panes, {
		prompt = "Send ref to which session?",
		format_item = function(p)
			return string.format("%s  %s", p.cmd, vim.fn.fnamemodify(p.path, ":~"))
		end,
	}, function(choice)
		if choice then
			inject(choice, path, line)
		end
	end)
end

function M.setup()
	vim.api.nvim_create_user_command("AgentSendRef", M.send, {
		desc = "Send @file#line ref to a claude/codex session in this tmux window",
	})

	vim.keymap.set({ "n", "v" }, "<leader>aa", M.send, { desc = "Send @file ref to agent session" })
end

return M
