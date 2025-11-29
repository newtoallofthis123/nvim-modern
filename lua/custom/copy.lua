local M = {}

local function get_relative_filepath()
	local filepath = vim.fn.expand("%:p")
	local cwd = vim.fn.getcwd()

	local relative_path = filepath:gsub(vim.pesc(cwd .. "/"), "")

	if relative_path == "" or relative_path == filepath then
		return "[No Name]"
	end

	return relative_path
end

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

local function get_formatted_buffer_path()
	local relative_path = get_relative_filepath()
	if relative_path == "[No Name]" then
		return "@[No Name]"
	end
	return "@" .. relative_path
end

local function get_formatted_buffer_path_with_line()
	local relative_path = get_relative_filepath()
	local line_info = get_current_line_or_range()
	if relative_path == "[No Name]" then
		return "@[No Name]#" .. line_info
	end
	return "@" .. relative_path .. "#" .. line_info
end

function M.copy_buffer_path()
	local formatted_path = get_formatted_buffer_path()
	vim.fn.setreg("+", formatted_path)
	vim.notify("Copied to clipboard: " .. formatted_path)
end

function M.copy_buffer_path_with_line()
	local formatted_path = get_formatted_buffer_path_with_line()
	vim.fn.setreg("+", formatted_path)
	vim.notify("Copied to clipboard: " .. formatted_path)
end

function M.setup()
	-- Register commands
	vim.api.nvim_create_user_command("CopyBufferPath", M.copy_buffer_path, {
		desc = "Copy current buffer path to clipboard (@filename format)",
	})

	vim.api.nvim_create_user_command("CopyBufferPathWithLine", M.copy_buffer_path_with_line, {
		desc = "Copy current buffer path with line number to clipboard (@filename#123 format)",
	})

	-- Set keybindings
	local keymap = vim.keymap.set
	keymap("n", "<leader>bp", M.copy_buffer_path, { desc = "Copy buffer path (@file)" })
	keymap("n", "<leader>bl", M.copy_buffer_path_with_line, { desc = "Copy buffer path with line (@file#123)" })
	keymap("v", "<leader>bl", M.copy_buffer_path_with_line, { desc = "Copy buffer path with line range" })
end

return M
