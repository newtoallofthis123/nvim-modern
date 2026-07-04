-- prcomments.lua — ambient, read-only visibility for PR review comments.
--
-- If the current buffer sits inside a worktree whose branch has an open PR,
-- fetches that PR's review comments (path + line + body + author) and
-- renders each as a virtual line under the commented line. No actions, no
-- routing — this is a viewer, not a review tool (that's the gh_diff picker's
-- own `a` comment/suggestion flow). Off by default; <leader>gt toggles, and
-- once on it stays live across every buffer you open until toggled off.
--
-- Caching mirrors prstatus.lua: async vim.system, 120s TTL per (root,
-- branch), so the statusline-adjacent bits never spawn a process to render.

local M = {}

local REFRESH_INTERVAL = 120 -- seconds, per (root, branch)

local ns = vim.api.nvim_create_namespace("prcomments")

M.enabled = false

-- key = "<root>|<branch>" -> { by_path = { [relpath] = {line, author, body}[] }, ts }
local cache = {}
-- dir -> key, or `false` when dir has no repo/branch/PR
local dir_key = {}
-- dir -> last time we attempted to resolve root/branch for it
local last_attempt = {}
-- key -> true while a gh fetch is in flight
local fetching = {}

local function get_dir()
	local bufname = vim.api.nvim_buf_get_name(0)
	if bufname == "" then
		return vim.fn.getcwd()
	end
	return vim.fs.dirname(bufname)
end

local function repo_from_url(url)
	return url and url:match("github%.com/([^/]+/[^/]+)")
end

-- Groups raw `gh api .../pulls/{n}/comments` rows by file path. Comments
-- with a null `line` are outdated (superseded by a later push) — skip them,
-- there is nowhere sensible to anchor them anymore.
local function group_by_path(raw)
	local by_path = {}
	for _, c in ipairs(raw) do
		if c.line and c.path then
			by_path[c.path] = by_path[c.path] or {}
			table.insert(by_path[c.path], {
				line = c.line,
				author = c.user and c.user.login or "?",
				body = (c.body or ""):gsub("\r\n", "\n"):gsub("\n.*", " …"),
			})
		end
	end
	return by_path
end

local function render_buf(buf, comments)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	if not M.enabled or not comments then
		return
	end
	local nlines = vim.api.nvim_buf_line_count(buf)
	for _, c in ipairs(comments) do
		local lnum = c.line - 1
		if lnum >= 0 and lnum < nlines then
			vim.api.nvim_buf_set_extmark(buf, ns, lnum, 0, {
				virt_lines = { { { ("  ◆ %s: %s"):format(c.author, c.body), "PrCommentNote" } } },
			})
		end
	end
end

-- Applies cached comments (if any) to a single loaded buffer.
function M.apply(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local name = vim.api.nvim_buf_get_name(buf)
	if name == "" then
		return
	end
	if not M.enabled then
		vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
		return
	end

	local dir = vim.fs.dirname(name)
	local key = dir_key[dir]
	if key == nil then
		M.refresh(dir)
		return
	elseif key == false then
		return
	end

	local entry = cache[key]
	if not entry then
		return
	end
	-- Resolve symlinks on both sides before comparing: `git rev-parse
	-- --show-toplevel` and a buffer's name can disagree by symlink alone
	-- (e.g. macOS /tmp -> /private/tmp), which would otherwise silently
	-- break the prefix strip below.
	local root = vim.uv.fs_realpath(key:match("^(.-)|")) or key:match("^(.-)|")
	local real_name = vim.uv.fs_realpath(name) or name
	if real_name:sub(1, #root + 1) ~= root .. "/" then
		return
	end
	local relpath = real_name:sub(#root + 2)
	render_buf(buf, entry.by_path[relpath])
end

-- Re-applies to every loaded buffer under `root` — called once a fetch
-- for that root completes, so already-open buffers pick up the result
-- without waiting for their next BufEnter.
local function render_visible(root)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			local name = vim.api.nvim_buf_get_name(buf)
			if name ~= "" and name:sub(1, #root + 1) == root .. "/" then
				M.apply(buf)
			end
		end
	end
end

local function fetch_comments(key, root, branch)
	local now = os.time()
	local entry = cache[key]
	if (entry and now - entry.ts < REFRESH_INTERVAL) or fetching[key] then
		return
	end
	fetching[key] = true

	vim.system({ "gh", "pr", "view", branch, "--json", "number,url" }, { cwd = root, text = true }, function(res)
		if res.code ~= 0 then
			vim.schedule(function()
				fetching[key] = false
				cache[key] = { by_path = {}, ts = now }
			end)
			return
		end
		local ok, data = pcall(vim.json.decode, res.stdout)
		local repo = ok and data and repo_from_url(data.url)
		if not ok or not data or not data.number or not repo then
			vim.schedule(function()
				fetching[key] = false
				cache[key] = { by_path = {}, ts = now }
			end)
			return
		end

		local endpoint = ("repos/%s/pulls/%d/comments"):format(repo, data.number)
		vim.system({ "gh", "api", endpoint }, { cwd = root, text = true }, function(res2)
			vim.schedule(function()
				fetching[key] = false
				if res2.code ~= 0 then
					cache[key] = { by_path = {}, ts = now }
					return
				end
				-- `luanil` matters here: GitHub sends an explicit `"line": null`
				-- for outdated comments, and without it vim.NIL (truthy, not
				-- Lua nil) would slip past the `c.line and ...` check below.
				local ok2, raw = pcall(vim.json.decode, res2.stdout, { luanil = { object = true, array = true } })
				cache[key] = { by_path = (ok2 and raw) and group_by_path(raw) or {}, ts = now }
				render_visible(root)
			end)
		end)
	end)
end

function M.refresh(dir)
	local now = os.time()
	if last_attempt[dir] and now - last_attempt[dir] < REFRESH_INTERVAL then
		return
	end
	last_attempt[dir] = now

	vim.system({ "git", "rev-parse", "--show-toplevel" }, { cwd = dir, text = true }, function(res)
		if res.code ~= 0 then
			vim.schedule(function()
				dir_key[dir] = false
			end)
			return
		end
		local root = vim.trim(res.stdout)

		vim.system({ "git", "branch", "--show-current" }, { cwd = root, text = true }, function(res2)
			vim.schedule(function()
				local branch = res2.code == 0 and vim.trim(res2.stdout) or ""
				if branch == "" then
					dir_key[dir] = false
					return
				end
				local key = root .. "|" .. branch
				dir_key[dir] = key
				fetch_comments(key, root, branch)
			end)
		end)
	end)
end

function M.toggle()
	M.enabled = not M.enabled
	vim.notify("PR review comments: " .. (M.enabled and "on" or "off"), vim.log.levels.INFO)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			M.apply(buf)
		end
	end
end

function M.setup()
	-- rose-pine muted, italic — same tone agentrecv.lua uses for ambient notes
	vim.api.nvim_set_hl(0, "PrCommentNote", { fg = "#908caa", italic = true, default = true })

	local group = vim.api.nvim_create_augroup("PrComments", { clear = true })
	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		callback = function(ev)
			if M.enabled then
				M.apply(ev.buf)
			end
		end,
	})

	vim.keymap.set("n", "<leader>gt", M.toggle, { desc = "Toggle inline PR review comments" })
end

return M
