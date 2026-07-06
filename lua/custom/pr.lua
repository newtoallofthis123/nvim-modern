-- pr.lua — the PR hub. One resolver for "which PR is this branch", shared by
-- every consumer, so "which PR am I on" is instant and cached (never blocks).
--
-- Folds in what used to be prstatus.lua (statusline text/state) and
-- prcomments.lua (inline review comments), and adds the action layer:
--   <leader>P   central float: current branch's PR · mine · review-requested
--                 (one `gh pr status` call — never the slow `gh pr list`)
--   <leader>gt  toggle inline PR review comments (ambient, read-only)
--
-- Inside the float, acting on the PR under the cursor:
--   d / <CR>  diff in CodeDiff WITHOUT checkout (fetch the PR head to a ref)
--   a         approve (+ optional one-line body)
--   r         request reviewers
--   m         enable auto-merge / merge queue (--squash)
--   o         open on github.com   ·   q  close
--
-- Rich per-line comments while reviewing? Leave them on the web (`o`, or
-- <leader>go on a code line) — approve here is a single body by design.
--
-- Everything shells out to `gh`/`git` async via vim.system; the statusline
-- only ever reads an in-memory cache, 120s TTL per (root, branch).

local M = {}

local REFRESH_INTERVAL = 120 -- seconds, per (root, branch)
local REMOTE = "origin"
local ns = vim.api.nvim_create_namespace("pr_comments")

-- the one `gh pr view` field set every consumer draws from
local PR_FIELDS =
	"number,state,url,title,statusCheckRollup,reviewDecision,baseRefName,headRefName,headRefOid,author"

M.comments_enabled = false

-- key = "<root>|<branch>" -> { pr, rendered, state, by_path, ts }
--   pr        = decoded `gh pr view` json (or nil when the branch has no PR)
--   rendered  = statusline string   ·  state = color bucket
--   by_path   = review comments grouped by relpath (only when comments are on)
local cache = {}
local dir_key = {} -- dir -> key, or false when dir has no repo/branch/PR
local last_attempt = {} -- dir -> last resolve attempt time
local fetching = {} -- key -> true while a gh fetch is in flight

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

-- ── statusline render (lifted from prstatus) ──────────────────────────────
-- statusCheckRollup + reviewDecision -> "#<n> <ci>[ <review>]" + color bucket
local function render(data)
	local ci, ci_state = "~", "pending"
	local rollup = data.statusCheckRollup
	if rollup and #rollup > 0 then
		local any_failure, any_pending = false, false
		for _, check in ipairs(rollup) do
			if check.status ~= "COMPLETED" then
				any_pending = true
			elseif not (check.conclusion == "SUCCESS" or check.conclusion == "NEUTRAL" or check.conclusion == "SKIPPED") then
				any_failure = true
			end
		end
		if any_failure then
			ci, ci_state = "✗", "fail"
		elseif any_pending then
			ci, ci_state = "~", "pending"
		else
			ci, ci_state = "✓", "pass"
		end
	end

	local review, state = "", ci_state
	if data.reviewDecision == "CHANGES_REQUESTED" then
		review, state = " ●", "changes_requested"
	elseif data.reviewDecision == "APPROVED" then
		review, state = " ✓", "approved"
	end

	return ("#%d %s%s"):format(data.number, ci, review), state
end

-- ── inline comments (lifted from prcomments) ──────────────────────────────
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
	if not M.comments_enabled or not comments then
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

-- Applies cached comments (if any) to one loaded buffer.
function M.apply(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local name = vim.api.nvim_buf_get_name(buf)
	if name == "" then
		return
	end
	if not M.comments_enabled then
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
	if not entry or not entry.by_path then
		return
	end
	-- resolve symlinks on both sides before the prefix strip (macOS /tmp ->
	-- /private/tmp would otherwise silently break it)
	local root = vim.uv.fs_realpath(key:match("^(.-)|")) or key:match("^(.-)|")
	local real_name = vim.uv.fs_realpath(name) or name
	if real_name:sub(1, #root + 1) ~= root .. "/" then
		return
	end
	local relpath = real_name:sub(#root + 2)
	render_buf(buf, entry.by_path[relpath])
end

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

-- Second hop: fetch this PR's review comments. Reuses number+url already on
-- the cache entry, so unlike the old prcomments it costs no extra `gh pr view`.
local function fetch_comments(key, root)
	local entry = cache[key]
	if not entry or not entry.pr then
		return
	end
	local repo = repo_from_url(entry.pr.url)
	if not repo then
		return
	end
	local endpoint = ("repos/%s/pulls/%d/comments"):format(repo, entry.pr.number)
	vim.system({ "gh", "api", endpoint }, { cwd = root, text = true }, function(res)
		vim.schedule(function()
			if res.code ~= 0 then
				return
			end
			-- luanil: GitHub sends explicit "line": null for outdated comments;
			-- without it vim.NIL (truthy) slips past the c.line check.
			local ok, raw = pcall(vim.json.decode, res.stdout, { luanil = { object = true, array = true } })
			local e = cache[key]
			if e then
				e.by_path = (ok and raw) and group_by_path(raw) or {}
			end
			render_visible(root)
		end)
	end)
end

-- ── the shared core: resolve branch's PR, cache it ────────────────────────
local function fetch_pr(key, root, branch)
	local now = os.time()
	local entry = cache[key]
	if (entry and now - entry.ts < REFRESH_INTERVAL) or fetching[key] then
		return
	end
	fetching[key] = true

	vim.system({ "gh", "pr", "view", branch, "--json", PR_FIELDS }, { cwd = root, text = true }, function(res)
		vim.schedule(function()
			fetching[key] = false
			local ok, data = pcall(vim.json.decode, res.stdout)
			if res.code ~= 0 or not ok or not data or not data.number then
				cache[key] = { ts = now } -- no PR on this branch
				return
			end
			local rendered, state = render(data)
			cache[key] = { pr = data, rendered = rendered, state = state, ts = now }
			if M.comments_enabled then
				fetch_comments(key, root)
			end
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
				fetch_pr(key, root, branch)
			end)
		end)
	end)
end

-- lualine component: reads cache only, never blocks.
function M.text()
	local dir = get_dir()
	local key = dir_key[dir]
	if key == nil then
		M.refresh(dir)
		return ""
	elseif key == false then
		return ""
	end
	local entry = cache[key]
	return entry and entry.rendered or ""
end

-- "pass" | "fail" | "pending" | "changes_requested" | "approved" | nil
function M.state()
	local key = dir_key[get_dir()]
	local entry = key and cache[key]
	return entry and entry.state or nil
end

function M.toggle()
	M.comments_enabled = not M.comments_enabled
	vim.notify("PR review comments: " .. (M.comments_enabled and "on" or "off"), vim.log.levels.INFO)
	-- turning on may need a comments fetch for the already-resolved branch
	if M.comments_enabled then
		local key = dir_key[get_dir()]
		local entry = key and cache[key]
		if entry and entry.pr and not entry.by_path then
			fetch_comments(key, key:match("^(.-)|"))
		end
	end
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			M.apply(buf)
		end
	end
end

-- ── actions ───────────────────────────────────────────────────────────────
-- Resolve the repo root for the current buffer (sync — actions are explicit,
-- user-initiated, and few, so a blocking git call is fine here).
local function repo_root()
	local out = vim.fn.systemlist("git -C " .. vim.fn.shellescape(get_dir()) .. " rev-parse --show-toplevel")[1]
	if vim.v.shell_error ~= 0 or not out or out == "" then
		vim.notify("not in a git repo", vim.log.levels.WARN)
		return nil
	end
	return out
end

-- run a gh command async, notify the outcome
local function gh(root, args, ok_msg)
	vim.system(vim.list_extend({ "gh" }, args), { cwd = root, text = true }, function(res)
		vim.schedule(function()
			if res.code == 0 then
				vim.notify(ok_msg, vim.log.levels.INFO)
			else
				vim.notify("gh: " .. vim.trim(res.stderr ~= "" and res.stderr or res.stdout), vim.log.levels.ERROR)
			end
		end)
	end)
end

-- Diff a PR in CodeDiff WITHOUT checking it out: fetch its head into a local
-- ref (working tree untouched), then two-pane it against the remote base.
function M.diff(n, base)
	local root = repo_root()
	if not root then
		return
	end
	base = base or "main"
	local ref = "refs/pr/" .. n
	vim.notify("fetching PR #" .. n .. " …", vim.log.levels.INFO)
	vim.system(
		{ "git", "-C", root, "fetch", REMOTE, ("pull/%d/head:%s"):format(n, ref) },
		{ text = true },
		function(res)
			vim.schedule(function()
				if res.code ~= 0 then
					vim.notify("fetch failed: " .. vim.trim(res.stderr), vim.log.levels.ERROR)
					return
				end
				vim.cmd(("CodeDiff %s/%s...%s"):format(REMOTE, base, ref))
			end)
		end
	)
end

function M.approve(n)
	local root = repo_root()
	if not root then
		return
	end
	vim.ui.input({ prompt = "Approve #" .. n .. " — body (optional): " }, function(body)
		local args = { "pr", "review", tostring(n), "--approve" }
		if body and body ~= "" then
			vim.list_extend(args, { "--body", body })
		end
		gh(root, args, "approved #" .. n)
	end)
end

function M.request_reviewers(n)
	local root = repo_root()
	if not root then
		return
	end
	vim.ui.input({ prompt = "Request reviewers for #" .. n .. " (comma-sep): " }, function(who)
		if not who or who == "" then
			return
		end
		gh(root, { "pr", "edit", tostring(n), "--add-reviewer", who }, "requested review on #" .. n)
	end)
end

function M.queue(n)
	local root = repo_root()
	if not root then
		return
	end
	gh(root, { "pr", "merge", tostring(n), "--auto", "--squash" }, "auto-merge enabled on #" .. n)
end

function M.open_web(n)
	local root = repo_root()
	if not root then
		return
	end
	gh(root, { "pr", "view", tostring(n), "--web" }, "opened #" .. n .. " in browser")
end

-- ── the central float: `gh pr status` → three buckets ─────────────────────
local STATUS_FIELDS = "number,title,headRefName,baseRefName,state,reviewDecision,author"

local function build_lines(status)
	local lines, rows = {}, {} -- rows[i] = { n, base } for the PR on display line i
	local function section(title, prs, empty)
		table.insert(lines, title)
		table.insert(rows, false)
		if not prs or #prs == 0 then
			table.insert(lines, "   " .. empty)
			table.insert(rows, false)
		else
			for _, pr in ipairs(prs) do
				local decision = ""
				if pr.reviewDecision == "APPROVED" then
					decision = "  ✓"
				elseif pr.reviewDecision == "CHANGES_REQUESTED" then
					decision = "  ●"
				end
				table.insert(lines, ("   #%d  %s%s"):format(pr.number, pr.title, decision))
				table.insert(rows, { n = pr.number, base = pr.baseRefName })
			end
		end
		table.insert(lines, "")
		table.insert(rows, false)
	end

	local cur = status.currentBranch
	section("● Current branch", cur and cur.number and { cur } or nil, "no PR for this branch")
	section("◆ Mine", status.createdBy, "none open")
	section("◇ Review requested", status.needsReview, "inbox clear")

	table.insert(lines, "  d/⏎ diff · a approve · r reviewers · m queue · o web · q close")
	table.insert(rows, false)
	return lines, rows
end

local function open_float(lines, rows)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = "pr_hub"

	local width = math.min(90, math.floor(vim.o.columns * 0.7))
	local height = math.min(#lines + 2, math.floor(vim.o.lines * 0.7))
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = "  Pull Requests ",
		title_pos = "center",
	})
	vim.wo[win].cursorline = true

	local function row_under_cursor()
		return rows[vim.api.nvim_win_get_cursor(win)[1]]
	end
	local function act(fn)
		return function()
			local r = row_under_cursor()
			if r then
				vim.api.nvim_win_close(win, true)
				fn(r)
			end
		end
	end
	local kopts = { buffer = buf, nowait = true, silent = true }
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
	end, kopts)
	vim.keymap.set("n", "<esc>", function()
		vim.api.nvim_win_close(win, true)
	end, kopts)
	vim.keymap.set("n", "<cr>", act(function(r)
		M.diff(r.n, r.base)
	end), kopts)
	vim.keymap.set("n", "d", act(function(r)
		M.diff(r.n, r.base)
	end), kopts)
	vim.keymap.set("n", "a", act(function(r)
		M.approve(r.n)
	end), kopts)
	vim.keymap.set("n", "r", act(function(r)
		M.request_reviewers(r.n)
	end), kopts)
	vim.keymap.set("n", "m", act(function(r)
		M.queue(r.n)
	end), kopts)
	vim.keymap.set("n", "o", act(function(r)
		M.open_web(r.n)
	end), kopts)

	-- land the cursor on the first actionable row
	for i, r in ipairs(rows) do
		if r then
			vim.api.nvim_win_set_cursor(win, { i, 0 })
			break
		end
	end
end

function M.hub()
	local root = repo_root()
	if not root then
		return
	end
	vim.notify("loading PRs …", vim.log.levels.INFO)
	vim.system(
		{ "gh", "pr", "status", "--json", STATUS_FIELDS },
		{ cwd = root, text = true },
		function(res)
			vim.schedule(function()
				if res.code ~= 0 then
					vim.notify("gh pr status failed: " .. vim.trim(res.stderr), vim.log.levels.ERROR)
					return
				end
				local ok, status = pcall(vim.json.decode, res.stdout)
				if not ok or not status then
					vim.notify("could not parse gh pr status", vim.log.levels.ERROR)
					return
				end
				local lines, rows = build_lines(status)
				open_float(lines, rows)
			end)
		end
	)
end

-- ── setup (idempotent — both lualine and the plugin shim call it) ─────────
function M.setup()
	if M._did_setup then
		return
	end
	M._did_setup = true

	-- rose-pine muted italic — same tone agentrecv uses for ambient notes
	vim.api.nvim_set_hl(0, "PrCommentNote", { fg = "#908caa", italic = true, default = true })

	local group = vim.api.nvim_create_augroup("PrHub", { clear = true })
	vim.api.nvim_create_autocmd({ "DirChanged", "FocusGained" }, {
		group = group,
		callback = function()
			M.refresh(get_dir())
		end,
	})
	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		callback = function(ev)
			if M.comments_enabled then
				M.apply(ev.buf)
			end
		end,
	})

	vim.keymap.set("n", "<leader>P", M.hub, { desc = "PR hub (current · mine · review-requested)" })
	vim.keymap.set("n", "<leader>gt", M.toggle, { desc = "Toggle inline PR review comments" })
end

return M
