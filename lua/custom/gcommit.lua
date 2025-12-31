local M = {}

local function run_gcommit()
	local handle = io.popen("gcommit 2>&1")
	if not handle then
		vim.notify("Failed to run gcommit command", vim.log.levels.ERROR)
		return nil
	end

	local result = handle:read("*a")
	local success = handle:close()

	if not success then
		vim.notify("gcommit command failed: " .. result, vim.log.levels.ERROR)
		return nil
	end

	-- Trim whitespace
	result = result:gsub("^%s*(.-)%s*$", "%1")

	if result == "" then
		vim.notify("gcommit returned empty result", vim.log.levels.WARN)
		return nil
	end

	return result
end

local function run_gcommit_branch()
	local handle = io.popen("gcommit -b 2>&1")
	if not handle then
		vim.notify("Failed to run gcommit -b command", vim.log.levels.ERROR)
		return nil
	end

	local result = handle:read("*a")
	local success = handle:close()

	if not success then
		vim.notify("gcommit -b command failed: " .. result, vim.log.levels.ERROR)
		return nil
	end

	-- Trim whitespace
	result = result:gsub("^%s*(.-)%s*$", "%1")

	if result == "" then
		vim.notify("gcommit -b returned empty result", vim.log.levels.WARN)
		return nil
	end

	return result
end

function M.gcommit_copy()
	local commit_msg = run_gcommit()
	if not commit_msg then
		return
	end

	-- Copy to clipboard using pbcopy
	local handle = io.popen("pbcopy", "w")
	if not handle then
		vim.notify("Failed to access clipboard", vim.log.levels.ERROR)
		return
	end

	handle:write(commit_msg)
	handle:close()

	vim.notify("Commit message copied to clipboard: " .. commit_msg, vim.log.levels.INFO)
end

function M.gcommit()
	-- Check if we're in a git repository
	local git_check = vim.fn.system("git rev-parse --is-inside-work-tree 2>/dev/null")
	if vim.v.shell_error ~= 0 then
		vim.notify("Not in a git repository", vim.log.levels.ERROR)
		return
	end

	-- First open the Git commit buffer
	vim.cmd("Git commit")

	-- Then generate the commit message
	local commit_msg = run_gcommit()
	if not commit_msg then
		return
	end

	-- Split commit message into lines for proper insertion
	local lines = {}
	local i = 1
	for line in commit_msg:gmatch("[^\n]+") do
		table.insert(lines, line)
		-- Add blank line after the first line (commit title)
		if i == 1 then
			table.insert(lines, "")
		end
		i = i + 1
	end

	-- Insert the commit message at the cursor position in the commit buffer
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, lines)

	-- Move cursor to the end of inserted text
	local last_line_length = #lines[#lines]
	vim.api.nvim_win_set_cursor(0, {row + #lines - 1, col + last_line_length})

	vim.notify("Commit message inserted", vim.log.levels.INFO)
end

function M.gcommit_branch()
	local branch_name = run_gcommit_branch()
	if not branch_name then
		return
	end

	-- Check if we're in a git repository
	local git_check = vim.fn.system("git rev-parse --is-inside-work-tree 2>/dev/null")
	if vim.v.shell_error ~= 0 then
		vim.notify("Not in a git repository", vim.log.levels.ERROR)
		return
	end

	-- Use vim.ui.input to show the branch name and allow editing
	vim.ui.input({
		prompt = "Branch name: ",
		default = branch_name,
	}, function(input)
		if input and input ~= "" then
			-- Create the branch with git switch -c
			local result = vim.fn.system("git switch -c " .. vim.fn.shellescape(input))
			if vim.v.shell_error ~= 0 then
				vim.notify("Failed to create branch: " .. result, vim.log.levels.ERROR)
			else
				vim.notify("Created and switched to branch: " .. input, vim.log.levels.INFO)
			end
		end
	end)
end

function M.setup()
	-- Register commands
	vim.api.nvim_create_user_command("GcommitCopy", M.gcommit_copy, {
		desc = "Generate commit message with gcommit and copy to clipboard",
	})

	vim.api.nvim_create_user_command("Gcommit", M.gcommit, {
		desc = "Open Git commit and insert generated commit message",
	})

	vim.api.nvim_create_user_command("GcommitBranch", M.gcommit_branch, {
		desc = "Generate branch name with gcommit -b and create new branch",
	})

	-- Set keybindings
	local keymap = vim.keymap.set
	keymap("n", "<leader>gc", M.gcommit_copy, { desc = "Generate commit message and copy to clipboard" })
	keymap("n", "<leader>gC", M.gcommit, { desc = "Open Git commit with generated message" })
	keymap("n", "<leader>gn", M.gcommit_branch, { desc = "Generate branch name and create new branch" })
end

return M
