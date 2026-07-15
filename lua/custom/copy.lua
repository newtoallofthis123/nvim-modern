local M = {}

function M.get_relative_filepath()
	local filepath = vim.fn.expand("%:p")
	local cwd = vim.fn.getcwd()

	local relative_path = filepath:gsub(vim.pesc(cwd .. "/"), "")

	if relative_path == "" or relative_path == filepath then
		return "[No Name]"
	end

	return relative_path
end

-- Absolute path from the filesystem root (/), plain, no @ prefix.
function M.get_absolute_filepath()
	local filepath = vim.fn.expand("%:p")
	if filepath == "" then
		return "[No Name]"
	end
	return filepath
end

-- Numeric line range of the cursor (normal) or live selection (visual).
function M.get_line_range()
	local mode = vim.fn.mode()
	if mode == "v" or mode == "V" or mode == "\22" then -- visual modes
		-- Read the live selection: "v" is the anchor, "." is the cursor.
		-- The '< / '> marks are only set on leaving visual mode, so they're
		-- stale (0) while a visual-mode mapping is running.
		local start_line = vim.fn.line("v")
		local end_line = vim.fn.line(".")
		if start_line > end_line then
			start_line, end_line = end_line, start_line
		end
		return start_line, end_line
	end
	local cur = vim.fn.line(".")
	return cur, cur
end

function M.get_current_line_or_range()
	local start_line, end_line = M.get_line_range()
	if start_line == end_line then
		return tostring(start_line)
	end
	return start_line .. "-" .. end_line
end

local function get_formatted_buffer_path()
	local relative_path = M.get_relative_filepath()
	if relative_path == "[No Name]" then
		return "@[No Name]"
	end
	return "@" .. relative_path
end

local function get_formatted_buffer_path_with_line()
	local relative_path = M.get_relative_filepath()
	local line_info = M.get_current_line_or_range()
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

-- Format an arbitrary absolute path as an @-ref relative to cwd.
local function format_ref(filepath)
	if filepath == "" then
		return "@[No Name]"
	end
	local cwd = vim.fn.getcwd()
	local relative = filepath:gsub(vim.pesc(cwd .. "/"), "")
	return "@" .. relative
end

-- Pick a listed buffer via snacks, then paste its @path at the cursor.
function M.pick_buffer_path()
	Snacks.picker.buffers({
		confirm = function(picker, item)
			picker:close()
			if not item then
				return
			end
			local ref = format_ref(vim.fn.fnamemodify(item.file, ":p"))
			vim.api.nvim_put({ ref }, "c", true, true)
		end,
	})
end

function M.copy_root_path()
	local path = M.get_absolute_filepath()
	vim.fn.setreg("+", path)
	vim.notify("Copied to clipboard: " .. path)
end

function M.setup()
	-- Register commands
	vim.api.nvim_create_user_command("CopyRootPath", M.copy_root_path, {
		desc = "Copy current file path relative to the project root (plain, no @)",
	})

	vim.api.nvim_create_user_command("CopyBufferPath", M.copy_buffer_path, {
		desc = "Copy current buffer path to clipboard (@filename format)",
	})

	vim.api.nvim_create_user_command("CopyBufferPathWithLine", M.copy_buffer_path_with_line, {
		desc = "Copy current buffer path with line number to clipboard (@filename#123 format)",
	})

	-- Set keybindings (copy-context group: paste @file refs to the LLM)
	local keymap = vim.keymap.set
	keymap("n", "<leader>cp", M.copy_buffer_path, { desc = "Copy buffer path (@file)" })
	keymap("n", "<leader>cP", M.copy_root_path, { desc = "Copy absolute file path (from /)" })
	keymap("n", "<leader>cl", M.copy_buffer_path_with_line, { desc = "Copy buffer path with line (@file#123)" })
	keymap("v", "<leader>cl", M.copy_buffer_path_with_line, { desc = "Copy buffer path with line range" })
	keymap("n", "<leader>cb", M.pick_buffer_path, { desc = "Pick buffer, paste @path at cursor" })

	vim.api.nvim_create_user_command("PickBufferPath", M.pick_buffer_path, {
		desc = "Pick a buffer and paste its @path at the cursor",
	})
end

return M
