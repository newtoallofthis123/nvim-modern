local M = {}

-- Helper function to get relative filepath from pwd and convert to dot notation
local function get_relative_filepath()
	local filepath = vim.fn.expand("%:p")
	local cwd = vim.fn.getcwd()

	-- Remove the cwd from the filepath to get relative path
	local relative_path = filepath:gsub(vim.pesc(cwd .. "/"), "")

	if relative_path == "" or relative_path == filepath then
		return "[No Name]"
	end

	return relative_path
end

-- Helper function to get current line number or range in visual mode
local function get_current_line_or_range()
	local mode = vim.fn.mode()
	if mode == "v" or mode == "V" or mode == "\22" then -- visual modes
		local start_line = vim.fn.line("'<")
		local end_line = vim.fn.line("'>")
		if start_line == end_line then
			return tostring(start_line)
		else
			return start_line .. "-" .. end_line
		end
	else
		return tostring(vim.fn.line("."))
	end
end

-- Helper function to format buffer path as @relative/path
local function get_formatted_buffer_path()
	local relative_path = get_relative_filepath()
	if relative_path == "[No Name]" then
		return "@[No Name]"
	end
	return "@" .. relative_path
end

-- Helper function to format buffer path with line number/range as @relative/path#123 or @relative/path#123-125
local function get_formatted_buffer_path_with_line()
	local relative_path = get_relative_filepath()
	local line_info = get_current_line_or_range()
	if relative_path == "[No Name]" then
		return "@[No Name]#" .. line_info
	end
	return "@" .. relative_path .. "#" .. line_info
end

-- Copy current buffer path to clipboard (@filename format)
function M.copy_buffer_path()
	local formatted_path = get_formatted_buffer_path()
	vim.fn.setreg("+", formatted_path)
	vim.notify("Copied to clipboard: " .. formatted_path)
end

-- Copy current buffer path with line number/range to clipboard (@filename#123 or @filename#123-125 format)
function M.copy_buffer_path_with_line()
	local formatted_path = get_formatted_buffer_path_with_line()
	vim.fn.setreg("+", formatted_path)
	vim.notify("Copied to clipboard: " .. formatted_path)
end

-- Open cursor-agent in detour window
function M.open_cursor_agent_detour()
	local window_id = require("detour").Detour()
	if not window_id then
		return
	end

	vim.cmd.terminal("cursor-agent")
	vim.bo.bufhidden = "delete"
	vim.wo[window_id].signcolumn = "no"

	-- Map escape key back to itself for terminal interaction
	vim.keymap.set("t", "<Esc><Esc>", "<Esc>", { buffer = true })

	vim.cmd.startinsert()

	-- Handle terminal close
	vim.api.nvim_create_autocmd({ "TermClose" }, {
		buffer = vim.api.nvim_get_current_buf(),
		callback = function()
			vim.api.nvim_feedkeys("i", "n", false)
		end,
	})
end

-- Open cursor-agent in detour window with buffer file path prefilled
function M.open_cursor_agent_detour_with_buffer()
	local window_id = require("detour").Detour()
	if not window_id then
		return
	end

	local buffer_path = get_formatted_buffer_path()
	vim.cmd.terminal("cursor-agent")
	vim.bo.bufhidden = "delete"
	vim.wo[window_id].signcolumn = "no"

	-- Send the buffer path to the terminal
	vim.api.nvim_chan_send(vim.bo.channel, buffer_path)

	-- Map escape key back to itself for terminal interaction
	vim.keymap.set("t", "<Esc><Esc>", "<Esc>", { buffer = true })

	-- Handle terminal close
	vim.api.nvim_create_autocmd({ "TermClose" }, {
		buffer = vim.api.nvim_get_current_buf(),
		callback = function()
			vim.api.nvim_feedkeys("i", "n", false)
		end,
	})
end

-- Open cursor-agent in detour window with buffer file path and line number prefilled
function M.open_cursor_agent_detour_with_path_and_line()
	local window_id = require("detour").Detour()
	if not window_id then
		return
	end

	local buffer_path_with_line = get_formatted_buffer_path_with_line()
	vim.cmd.terminal("cursor-agent")
	vim.bo.bufhidden = "delete"
	vim.wo[window_id].signcolumn = "no"

	-- Send the buffer path with line number to the terminal
	vim.api.nvim_chan_send(vim.bo.channel, buffer_path_with_line)

	-- Map escape key back to itself for terminal interaction
	vim.keymap.set("t", "<Esc><Esc>", "<Esc>", { buffer = true })

	-- Handle terminal close
	vim.api.nvim_create_autocmd({ "TermClose" }, {
		buffer = vim.api.nvim_get_current_buf(),
		callback = function()
			vim.api.nvim_feedkeys("i", "n", false)
		end,
	})
end

-- Open cursor-agent in a new tab
function M.open_cursor_agent_tab()
	vim.cmd.tabnew()
	vim.cmd.terminal("cursor-agent")
	vim.bo.bufhidden = "delete"

	-- Map escape key back to itself for terminal interaction
	vim.keymap.set("t", "<Esc><Esc>", "<Esc>", { buffer = true })

	vim.cmd.startinsert()

	-- Handle terminal close
	vim.api.nvim_create_autocmd({ "TermClose" }, {
		buffer = vim.api.nvim_get_current_buf(),
		callback = function()
			vim.api.nvim_feedkeys("i", "n", false)
		end,
	})
end

-- Setup function to register commands and keybindings
function M.setup()
	-- Register commands
	vim.api.nvim_create_user_command("CopyBufferPath", M.copy_buffer_path, {
		desc = "Copy current buffer path to clipboard (@filename format)",
	})

	vim.api.nvim_create_user_command("CopyBufferPathWithLine", M.copy_buffer_path_with_line, {
		desc = "Copy current buffer path with line number to clipboard (@filename#123 format)",
	})

	vim.api.nvim_create_user_command("CursorAgentDetour", M.open_cursor_agent_detour, {
		desc = "Open cursor-agent in detour window",
	})

	vim.api.nvim_create_user_command("CursorAgentDetourWithBuffer", M.open_cursor_agent_detour_with_buffer, {
		desc = "Open cursor-agent in detour window with buffer path prefilled",
	})

	vim.api.nvim_create_user_command("CursorAgentDetourWithLine", M.open_cursor_agent_detour_with_path_and_line, {
		desc = "Open cursor-agent in detour window with buffer path and line number prefilled",
	})

	vim.api.nvim_create_user_command("CursorAgentTab", M.open_cursor_agent_tab, {
		desc = "Open cursor-agent in a new tab",
	})

	-- Set keybindings
	local keymap = vim.keymap.set
	keymap("n", "<leader>yp", M.copy_buffer_path, { desc = "Copy buffer path (@file)" })
	keymap("n", "<leader>yl", M.copy_buffer_path_with_line, { desc = "Copy buffer path with line (@file#123)" })
	keymap("v", "<leader>yl", M.copy_buffer_path_with_line, { desc = "Copy buffer path with line range" })

	-- Cursor-agent keybindings
	keymap("n", "<leader>a", M.open_cursor_agent_detour, { desc = "Open cursor-agent (detour)" })
	keymap("n", "<leader>ab", M.open_cursor_agent_detour_with_buffer, { desc = "Open cursor-agent with buffer" })
	keymap("n", "<leader>al", M.open_cursor_agent_detour_with_path_and_line, { desc = "Open cursor-agent with line" })
	keymap(
		"v",
		"<leader>al",
		M.open_cursor_agent_detour_with_path_and_line,
		{ desc = "Open cursor-agent with line range" }
	)
	keymap("n", "<leader>at", M.open_cursor_agent_tab, { desc = "Open cursor-agent (tab)" })
end

return M
