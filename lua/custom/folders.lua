-- Quick-pick folder registry: keep a global list of folders on disk, then
-- fan them into the snacks pickers (files / grep) or oil. Think Harpoon, but
-- for directories instead of files.
local M = {}

local store = vim.fn.stdpath("data") .. "/quick-folders.json"

-- In-memory list of absolute folder paths. Loaded from disk on setup.
M.folders = {}

local function load()
	local f = io.open(store, "r")
	if not f then
		return
	end
	local content = f:read("*a")
	f:close()
	local ok, data = pcall(vim.json.decode, content)
	if ok and type(data) == "table" then
		M.folders = data
	end
end

local function save()
	local f = io.open(store, "w")
	if not f then
		vim.notify("quick-folders: cannot write " .. store, vim.log.levels.ERROR)
		return
	end
	f:write(vim.json.encode(M.folders))
	f:close()
end

-- Format a folder as an @-ref relative to cwd (matches the copy-context group).
local function format_ref(path)
	local cwd = vim.fn.getcwd()
	local rel = path:gsub(vim.pesc(cwd .. "/"), "")
	return "@" .. rel
end

local function add(path)
	if not path or path == "" then
		return
	end
	path = vim.fn.fnamemodify(path, ":p"):gsub("/$", "")
	if vim.fn.isdirectory(path) == 0 then
		vim.notify("quick-folders: not a directory: " .. path, vim.log.levels.WARN)
		return
	end
	if vim.tbl_contains(M.folders, path) then
		vim.notify("quick-folders: already listed: " .. path)
		return
	end
	table.insert(M.folders, path)
	save()
	vim.notify("quick-folders: added " .. path)
end

-- Pick one registered folder, then hand its path to `cb`.
local function pick_folder(prompt, cb)
	if #M.folders == 0 then
		vim.notify("quick-folders: list is empty (add with <leader>fqa)", vim.log.levels.WARN)
		return
	end
	local items = {}
	for _, path in ipairs(M.folders) do
		table.insert(items, { text = format_ref(path), file = path, folder = path })
	end
	Snacks.picker.pick({
		title = prompt,
		items = items,
		format = "text",
		confirm = function(picker, item)
			picker:close()
			if item then
				cb(item.folder)
			end
		end,
	})
end

-- === add / remove ===========================================================

-- Browse the filesystem (fd, from cwd) and add the chosen directory.
function M.add_browse()
	local dirs = vim.fn.systemlist({ "fd", "--type", "d", "--hidden", "--exclude", ".git" })
	local items = { { text = ".", file = vim.fn.getcwd(), folder = vim.fn.getcwd() } }
	for _, d in ipairs(dirs) do
		table.insert(items, { text = d, file = d, folder = vim.fn.fnamemodify(d, ":p") })
	end
	Snacks.picker.pick({
		title = "Add folder to quick-pick",
		items = items,
		format = "text",
		confirm = function(picker, item)
			picker:close()
			if item then
				add(item.folder)
			end
		end,
	})
end

function M.add_cwd()
	add(vim.fn.getcwd())
end

function M.remove()
	pick_folder("Remove folder", function(folder)
		for i, path in ipairs(M.folders) do
			if path == folder then
				table.remove(M.folders, i)
				break
			end
		end
		save()
		vim.notify("quick-folders: removed " .. folder)
	end)
end

-- === verbs ==================================================================

-- 1. Pick a folder, paste its @path at the cursor.
function M.paste_path()
	pick_folder("Paste folder path", function(folder)
		vim.api.nvim_put({ format_ref(folder) }, "c", true, true)
	end)
end

-- 2. Pick a folder, open a file inside it.
function M.open_file()
	pick_folder("Open file in folder", function(folder)
		Snacks.picker.files({ cwd = folder })
	end)
end

-- 3. Pick a folder, go there in oil.
function M.goto_folder()
	pick_folder("Go to folder", function(folder)
		require("oil").open(folder)
	end)
end

-- 4. Pick a folder, grep inside it.
function M.grep_folder()
	pick_folder("Grep in folder", function(folder)
		Snacks.picker.grep({ dirs = { folder } })
	end)
end

-- 5. Grep across every registered folder at once.
function M.grep_all()
	if #M.folders == 0 then
		vim.notify("quick-folders: list is empty (add with <leader>fqa)", vim.log.levels.WARN)
		return
	end
	Snacks.picker.grep({ dirs = M.folders })
end

function M.setup()
	load()

	local map = vim.keymap.set
	map("n", "<leader>fqa", M.add_browse, { desc = "Quick-folders: add (browse)" })
	map("n", "<leader>fqA", M.add_cwd, { desc = "Quick-folders: add cwd" })
	map("n", "<leader>fqx", M.remove, { desc = "Quick-folders: remove" })
	map("n", "<leader>fqp", M.paste_path, { desc = "Quick-folders: paste @path" })
	map("n", "<leader>fqf", M.open_file, { desc = "Quick-folders: open file in folder" })
	map("n", "<leader>fqo", M.goto_folder, { desc = "Quick-folders: go (oil)" })
	map("n", "<leader>fqg", M.grep_folder, { desc = "Quick-folders: grep one folder" })
	map("n", "<leader>fqG", M.grep_all, { desc = "Quick-folders: grep all folders" })
end

return M
