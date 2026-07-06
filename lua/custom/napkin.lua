-- napkin — quick throwaway scratch files.
--
-- <leader>ns spins up a fresh markdown scratch in vim.g.tmp_dir (/tmp/nvim),
-- stamped with the folder you were in and when you made it:
--
--   ---
--   folder: <>
--   created_at: 2026-07-06T14:32:10
--   ---
--
-- The tmp dir IS the tracker — every *.md in there is a napkin. <leader>nS
-- picks one back up in a snacks picker, newest first, showing which folder it
-- came from so you can tell your scratches apart.
--
--   <leader>ns  new napkin (opens it, cursor past the frontmatter)
--   <leader>nS  pick an existing napkin

local M = {}

local function dir()
	return vim.fn.expand(vim.g.tmp_dir or "/tmp/nvim")
end

-- read the folder/created_at out of a napkin's frontmatter (cheap: first lines)
local function meta(path)
	local out = { folder = nil, created_at = nil }
	local f = io.open(path, "r")
	if not f then
		return out
	end
	local first = f:read("*l")
	if first == "---" then
		for _ = 1, 10 do
			local line = f:read("*l")
			if not line or line == "---" then
				break
			end
			local k, v = line:match("^(%w+):%s*(.*)$")
			if k == "folder" then
				out.folder = v
			elseif k == "created_at" then
				out.created_at = v
			end
		end
	end
	f:close()
	return out
end

-- new napkin ----------------------------------------------------------------
function M.new()
	local d = dir()
	vim.fn.mkdir(d, "p")

	local stamp = os.date("%Y%m%d-%H%M%S")
	local path = d .. "/" .. stamp .. ".md"
	local n = 1
	while vim.fn.filereadable(path) == 1 do -- same-second collision
		path = d .. "/" .. stamp .. "-" .. n .. ".md"
		n = n + 1
	end

	local header = {
		"---",
		"folder: " .. vim.fn.getcwd(),
		"created_at: " .. os.date("%Y-%m-%dT%H:%M:%S"),
		"---",
		"",
		"",
	}
	vim.cmd("edit " .. vim.fn.fnameescape(path))
	vim.api.nvim_buf_set_lines(0, 0, -1, false, header)
	vim.cmd("write")
	vim.api.nvim_win_set_cursor(0, { #header, 0 }) -- land on the blank body line
	vim.cmd("startinsert")
end

-- pick an existing napkin ---------------------------------------------------
function M.pick()
	local d = dir()
	local files = vim.fn.glob(d .. "/*.md", false, true)
	if vim.tbl_isempty(files) then
		vim.notify("napkin: no scratch files in " .. d, vim.log.levels.INFO)
		return
	end
	table.sort(files, function(a, b)
		return a > b -- filenames are timestamped → newest first
	end)

	local items = {}
	for i, path in ipairs(files) do
		local m = meta(path)
		local folder = m.folder and vim.fn.fnamemodify(m.folder, ":t") or "?"
		items[#items + 1] = {
			idx = i,
			file = path,
			text = folder .. " " .. (m.created_at or vim.fn.fnamemodify(path, ":t:r")),
			folder = folder,
			created_at = m.created_at,
		}
	end

	if not (Snacks and Snacks.picker) then
		vim.ui.select(items, {
			prompt = "Napkins",
			format_item = function(it)
				return it.text
			end,
		}, function(c)
			if c then
				vim.cmd("edit " .. vim.fn.fnameescape(c.file))
			end
		end)
		return
	end

	Snacks.picker.pick({
		title = "Napkins",
		items = items,
		format = function(item)
			return {
				{ (item.created_at or "") .. "  ", "Comment" },
				{ item.folder or "", "Directory" },
			}
		end,
		confirm = function(picker, item)
			picker:close()
			vim.cmd("edit " .. vim.fn.fnameescape(item.file))
		end,
	})
end

vim.keymap.set("n", "<leader>ns", M.new, { desc = "Napkin: new scratch file" })
vim.keymap.set("n", "<leader>nS", M.pick, { desc = "Napkin: pick a scratch file" })

return M
