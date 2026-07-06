-- pr.lua — the PR hub. One resolver for "which PR is this branch", shared by
-- every consumer, so "which PR am I on" is instant and cached (never blocks).
--
-- Folds in what used to be prstatus.lua (statusline text/state) and
-- prcomments.lua (inline review comments), and adds the action layer:
--   <leader>Pc  THIS branch's PR — status float, from cache, instant
--   <leader>Pca   approve it   ·   <leader>Pcd  diff it (no checkout)
--   <leader>Pl  list float: current · mine · review-requested (one `gh pr
--                 status` call — the explicit, opt-in list; never `gh pr list`)
--   <leader>Pg  go to any PR by number / #n / github url → its status
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

-- vim.system THROWS ENOENT when the binary is missing (classic: `gh` lives in
-- Homebrew's bin, which a GUI-launched nvim doesn't have on PATH). Wrap it so a
-- missing tool degrades to exit code 127 instead of crashing the callback and
-- leaving the resolver stuck on "resolving…". Uses `vim.system,` (comma) so the
-- vim.system( -> sys( sweep below leaves this reference alone.
local function sys(cmd, opts, cb)
	local ok, err = pcall(vim.system, cmd, opts, cb)
	if not ok then
		vim.schedule(function()
			cb({ code = 127, stdout = "", stderr = tostring(err) })
		end)
	end
end

-- Add the usual bins if `gh` isn't resolvable — fixes GUI nvim's bare PATH for
-- the whole session, not just this module.
local function ensure_gh_path()
	if vim.fn.exepath("gh") ~= "" then
		return true
	end
	for _, p in ipairs({ "/opt/homebrew/bin", "/usr/local/bin", (vim.env.HOME or "") .. "/.local/bin" }) do
		if vim.fn.isdirectory(p) == 1 and not (":" .. (vim.env.PATH or "") .. ":"):find(":" .. p .. ":", 1, true) then
			vim.env.PATH = p .. ":" .. (vim.env.PATH or "")
		end
	end
	return vim.fn.exepath("gh") ~= ""
end

-- "the repo I'm working in" — ignore diff views / oil / terminals / pickers (a
-- set buftype, or a scheme:// name) so reviewing a PR's diff doesn't make the
-- current-branch PR resolve to the PR you're looking at.
local function get_dir()
	local name = vim.api.nvim_buf_get_name(0)
	if name == "" or vim.bo.buftype ~= "" or name:match("^%w+://") then
		return vim.fn.getcwd()
	end
	return vim.fs.dirname(name)
end

local function repo_from_url(url)
	return url and url:match("github%.com/([^/]+/[^/]+)")
end

-- ── statusline render (lifted from prstatus) ──────────────────────────────
-- statusCheckRollup -> symbol, word, color bucket
local function ci_of(data)
	local rollup = data.statusCheckRollup
	if not rollup or #rollup == 0 then
		return "~", "no checks", "pending"
	end
	local any_failure, any_pending = false, false
	for _, check in ipairs(rollup) do
		if check.status ~= "COMPLETED" then
			any_pending = true
		elseif not (check.conclusion == "SUCCESS" or check.conclusion == "NEUTRAL" or check.conclusion == "SKIPPED") then
			any_failure = true
		end
	end
	if any_failure then
		return "✗", "failing", "fail"
	elseif any_pending then
		return "~", "pending", "pending"
	end
	return "✓", "passing", "pass"
end

local function review_label(data)
	if data.reviewDecision == "APPROVED" then
		return "✓ approved"
	elseif data.reviewDecision == "CHANGES_REQUESTED" then
		return "● changes requested"
	elseif data.reviewDecision == "REVIEW_REQUIRED" then
		return "review required"
	end
	return "—"
end

-- statusCheckRollup + reviewDecision -> "#<n> <ci>[ <review>]" + color bucket
local function render(data)
	local ci, _, ci_state = ci_of(data)
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
	if entry.comments_ts and os.time() - entry.comments_ts < REFRESH_INTERVAL then
		return -- throttle: the CI watcher can force fetch_pr often
	end
	entry.comments_ts = os.time()
	local repo = repo_from_url(entry.pr.url)
	if not repo then
		return
	end
	local endpoint = ("repos/%s/pulls/%d/comments"):format(repo, entry.pr.number)
	sys({ "gh", "api", endpoint }, { cwd = root, text = true }, function(res)
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

-- ci flip notifier: fire once when CI leaves "pending" for a decisive verdict,
-- i.e. you were waiting and it just resolved. Reset when it goes back to
-- pending (a new push), so the next resolution notifies again.
local notified = {} -- key -> last ci_state we notified about
local function notify_flip(key, prev_ci, ci_state, number, ci_word)
	if ci_state == "pending" then
		notified[key] = nil
		return
	end
	if prev_ci == "pending" and notified[key] ~= ci_state then
		notified[key] = ci_state
		vim.notify(
			("PR #%d checks %s %s"):format(number, ci_word, ci_state == "pass" and "✓" or "✗"),
			ci_state == "pass" and vim.log.levels.INFO or vim.log.levels.WARN
		)
	end
end

-- ── the shared core: resolve branch's PR, cache it ────────────────────────
-- force bypasses the TTL (the CI watcher uses it to poll a pending PR).
local function fetch_pr(key, root, branch, force)
	local now = os.time()
	local entry = cache[key]
	if fetching[key] or (not force and entry and now - entry.ts < REFRESH_INTERVAL) then
		return
	end
	fetching[key] = true

	sys({ "gh", "pr", "view", branch, "--json", PR_FIELDS }, { cwd = root, text = true }, function(res)
		vim.schedule(function()
			fetching[key] = false
			local ok, data = pcall(vim.json.decode, res.stdout)
			if res.code ~= 0 or not ok or not data or not data.number then
				cache[key] = { ts = now } -- no PR on this branch
				return
			end
			local prev = cache[key]
			local rendered, state = render(data)
			local _, ci_word, ci_state = ci_of(data)
			-- update in place so review comments (by_path) survive a CI refetch
			local e = prev or {}
			e.pr, e.rendered, e.state, e.ci_state, e.ts = data, rendered, state, ci_state, now
			cache[key] = e
			notify_flip(key, prev and prev.ci_state, ci_state, data.number, ci_word)
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

	sys({ "git", "rev-parse", "--show-toplevel" }, { cwd = dir, text = true }, function(res)
		if res.code ~= 0 then
			vim.schedule(function()
				dir_key[dir] = false
			end)
			return
		end
		local root = vim.trim(res.stdout)
		sys({ "git", "branch", "--show-current" }, { cwd = root, text = true }, function(res2)
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
	sys(vim.list_extend({ "gh" }, args), { cwd = root, text = true }, function(res)
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
	sys(
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

-- centered rounded float (matches Snacks.git.blame_line's feel); q/⎋ close.
local function make_float(lines, title)
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
		title = title,
		title_pos = "center",
	})
	vim.wo[win].cursorline = true

	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	for _, k in ipairs({ "q", "<esc>" }) do
		vim.keymap.set("n", k, close, { buffer = buf, nowait = true, silent = true })
	end
	return buf, win, close
end

-- action keys shared by both floats: fn is called with the PR number + base.
local function bind_actions(buf, close, get)
	local kopts = { buffer = buf, nowait = true, silent = true }
	local function act(fn)
		return function()
			local n, base = get()
			if n then
				close()
				fn(n, base)
			end
		end
	end
	vim.keymap.set("n", "<cr>", act(M.diff), kopts)
	vim.keymap.set("n", "d", act(M.diff), kopts)
	vim.keymap.set("n", "a", act(function(n)
		M.approve(n)
	end), kopts)
	vim.keymap.set("n", "r", act(function(n)
		M.request_reviewers(n)
	end), kopts)
	vim.keymap.set("n", "m", act(function(n)
		M.queue(n)
	end), kopts)
	vim.keymap.set("n", "o", act(function(n)
		M.open_web(n)
	end), kopts)
end

-- multi-PR list (the `gh pr status` buckets)
local function open_float(lines, rows)
	local buf, win, close = make_float(lines, "  Pull Requests ")
	bind_actions(buf, close, function()
		local r = rows[vim.api.nvim_win_get_cursor(win)[1]]
		if r then
			return r.n, r.base
		end
	end)
	for i, r in ipairs(rows) do -- land on the first actionable row
		if r then
			vim.api.nvim_win_set_cursor(win, { i, 0 })
			break
		end
	end
end

-- single-PR status detail (the cached branch PR, or an arbitrary one)
local function open_pr_float(pr)
	local ci_sym, ci_word = ci_of(pr)
	local author = pr.author and pr.author.login or "?"
	local lines = {
		("#%d  %s"):format(pr.number, pr.title or ""),
		"",
		("CI       %s %s"):format(ci_sym, ci_word),
		("Review   %s"):format(review_label(pr)),
		("Base     %s  ←  Head  %s"):format(pr.baseRefName or "?", pr.headRefName or "?"),
		("Author   %s"):format(author),
		("State    %s"):format((pr.state or ""):lower()),
		"",
		"  d diff · a approve · r reviewers · m queue · o web · q close",
	}
	local buf, _, close = make_float(lines, ("  PR #%d "):format(pr.number))
	bind_actions(buf, close, function()
		return pr.number, pr.baseRefName
	end)
end

function M.hub()
	local root = repo_root()
	if not root then
		return
	end
	vim.notify("loading PRs …", vim.log.levels.INFO)
	sys(
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

-- The CACHED current-branch PR — instant, no network. Returns the pr table, or
-- nil (with a notify) if it hasn't resolved yet / the branch has no PR.
function M.current_pr()
	local dir = get_dir()
	local key = dir_key[dir]
	if key == nil then
		M.refresh(dir)
		vim.notify("resolving this branch's PR — try again in a moment", vim.log.levels.INFO)
		return nil
	elseif key == false then
		vim.notify("no PR for this branch", vim.log.levels.WARN)
		return nil
	end
	local entry = cache[key]
	if not entry or not entry.pr then
		vim.notify("no PR for this branch (or still loading)", vim.log.levels.WARN)
		return nil
	end
	return entry.pr
end

function M.current()
	local pr = M.current_pr()
	if pr then
		open_pr_float(pr)
	end
end

function M.approve_current()
	local pr = M.current_pr()
	if pr then
		M.approve(pr.number)
	end
end

function M.diff_current()
	local pr = M.current_pr()
	if pr then
		M.diff(pr.number, pr.baseRefName)
	end
end

-- Jump to any PR by number / #number / github URL → its status float.
function M.goto_pr()
	local root = repo_root()
	if not root then
		return
	end
	Snacks.input({ prompt = "PR number / #n / url: " }, function(v)
		if not v or v == "" then
			return
		end
		local n = v:match("/pull/(%d+)") or v:match("^#?(%d+)$") or v:match("(%d+)")
		if not n then
			vim.notify("could not find a PR number in that", vim.log.levels.WARN)
			return
		end
		sys({ "gh", "pr", "view", n, "--json", PR_FIELDS }, { cwd = root, text = true }, function(res)
			vim.schedule(function()
				if res.code ~= 0 then
					vim.notify("gh: " .. vim.trim(res.stderr), vim.log.levels.ERROR)
					return
				end
				local ok, data = pcall(vim.json.decode, res.stdout)
				if not ok or not data or not data.number then
					vim.notify("could not read PR #" .. n, vim.log.levels.ERROR)
					return
				end
				open_pr_float(data)
			end)
		end)
	end)
end

-- ── CI watcher ────────────────────────────────────────────────────────────
-- Only spends a `gh` call when the current branch's PR is actually pending, so
-- it's free while you're not waiting on checks. notify_flip does the alerting.
local watch_timer
local function poll_ci()
	local key = dir_key[get_dir()]
	local e = key and cache[key]
	if e and e.pr and e.ci_state == "pending" then
		local root, branch = key:match("^(.-)|(.+)$")
		fetch_pr(key, root, branch, true) -- force past the TTL
	end
end

-- ── setup (idempotent — both lualine and the plugin shim call it) ─────────
function M.setup()
	if M._did_setup then
		return
	end
	M._did_setup = true

	if not ensure_gh_path() then
		vim.notify("pr.lua: `gh` not found on PATH — PR features need the GitHub CLI", vim.log.levels.WARN)
	end

	watch_timer = vim.uv.new_timer()
	watch_timer:start(30000, 30000, function()
		vim.schedule(poll_ci)
	end)

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

	vim.keymap.set("n", "<leader>Pc", M.current, { desc = "PR: current branch's PR (status float)" })
	vim.keymap.set("n", "<leader>Pca", M.approve_current, { desc = "PR: approve current" })
	vim.keymap.set("n", "<leader>Pcd", M.diff_current, { desc = "PR: diff current" })
	vim.keymap.set("n", "<leader>Pl", M.hub, { desc = "PR: list (current · mine · review-requested)" })
	vim.keymap.set("n", "<leader>Pg", M.goto_pr, { desc = "PR: go to a PR by number / #n / url" })
	vim.keymap.set("n", "<leader>gt", M.toggle, { desc = "Toggle inline PR review comments" })
end

return M
