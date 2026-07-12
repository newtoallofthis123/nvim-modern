-- pr.lua — the PR hub. One resolver for "which PR is this branch", shared by
-- every consumer, so "which PR am I on" is instant and cached (never blocks).
--
-- The core concept is the FOCUSED PR — "the PR in view". Opening a PR any way
-- (status float, hub row, goto by url, diffing it) focuses it, and every
-- action key then acts on it without asking again. View a diff, then
-- <leader>Pa approves THAT PR — no re-prompt. When nothing is focused,
-- actions fall back to the current branch's PR.
--
-- Keymaps (flat — no chords waiting on timeoutlen):
--   <leader>Pp  status float of the focused PR (falls back to branch PR)
--   <leader>Pb  THIS branch's PR — also re-focuses it
--   <leader>Pl  list float: current · mine · review-requested (one `gh pr
--                 status` call — the explicit, opt-in list; never `gh pr list`)
--   <leader>Pg  go to any PR: number / #n / full github URL — a URL from a
--                 DIFFERENT repo works too (gh -R + fetch from that repo)
--   <leader>Pd  diff the focused PR in Diffview, no checkout
--   <leader>Pa  approve         ·  <leader>Px  request changes
--   <leader>Pc  comment         ·  <leader>Pr  request reviewers
--   <leader>Pm  auto-merge/queue·  <leader>PC  checkout its branch
--   <leader>Po  open on github  ·  <leader>Py  yank PR url
--   <leader>gt  toggle inline PR review comments (ambient, read-only)
--
-- Inside the floats the same verbs work on the PR under the cursor:
--   d/<CR> diff · a approve · x req-changes · c comment · r reviewers
--   m queue · C checkout · y yank url · o web · q close
--
-- Rich per-line comments while reviewing? Leave them on the web (`o`, or
-- <leader>go on a code line) — reviews here are single-body by design.
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

-- "owner/repo" out of an https / ssh github url (or nil)
local function repo_from_url(url)
	local repo = url and url:match("github%.com[:/]([^/]+/[^/%s]+)")
	return repo and repo:gsub("%.git$", "")
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

-- forward decl — the focus state lives with the actions below
local get_focus

-- lualine component: reads cache only, never blocks. When a DIFFERENT PR is
-- focused (you're reviewing someone else's), it's appended as ◎#n so the
-- statusline always says what the action keys will hit.
function M.text()
	local dir = get_dir()
	local key = dir_key[dir]
	local s = ""
	if key == nil then
		M.refresh(dir)
	elseif key ~= false then
		local entry = cache[key]
		s = entry and entry.rendered or ""
	end
	local f = get_focus and get_focus()
	if f and f.pr then
		local branch_n = s:match("^#(%d+)")
		if f.repo or tostring(f.pr.number) ~= branch_n then
			s = s .. (s ~= "" and "  " or "") .. "◎#" .. f.pr.number
		end
	end
	return s
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

-- ── the focused PR: "the PR in view" ──────────────────────────────────────
-- Set whenever a PR is opened/diffed/jumped-to; every action targets it.
-- ctx = { pr = <gh json (at least number, baseRefName)>, repo = "owner/repo"
-- or nil when it's this repo's PR }.
local focused

local function set_focus(ctx)
	focused = ctx
end

get_focus = function() -- fulfils the forward decl M.text() reads through
	return focused
end

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

-- owner/repo of this repo's origin (nil when it isn't github)
local function origin_repo(root)
	local url = vim.fn.systemlist("git -C " .. vim.fn.shellescape(root) .. " remote get-url " .. REMOTE)[1]
	return vim.v.shell_error == 0 and repo_from_url(url) or nil
end

-- The action target: the focused PR, else this branch's cached PR.
local function target()
	if focused then
		return focused
	end
	local pr = M.current_pr() -- notifies when absent / still resolving
	return pr and { pr = pr } or nil
end

-- run a gh command async, notify the outcome. ctx.repo adds -R for
-- cross-repo PRs (a pasted URL from another repo just works).
local function gh(root, args, ctx, ok_msg)
	if ctx and ctx.repo then
		vim.list_extend(args, { "-R", ctx.repo })
	end
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

-- ── actions (each takes a ctx; keymaps feed them target()) ────────────────

-- Diff a PR in Diffview WITHOUT checking it out: fetch its head (and, for a
-- cross-repo PR, its base) into local refs — working tree untouched — then
-- open the merge-base range, same provider/feel as <leader>gD.
function M.diff(ctx)
	local root = repo_root()
	if not root then
		return
	end
	local n = ctx.pr.number
	local base = ctx.pr.baseRefName or "main"
	local head_ref = ("refs/pr/%d/head"):format(n)
	local cmd = { "git", "-C", root, "fetch" }
	local base_rev
	if ctx.repo then
		-- foreign repo: fetch both sides straight from its URL into local refs
		base_rev = ("refs/pr/%d/base"):format(n)
		vim.list_extend(cmd, {
			"https://github.com/" .. ctx.repo .. ".git",
			("+refs/pull/%d/head:%s"):format(n, head_ref),
			("+refs/heads/%s:%s"):format(base, base_rev),
		})
	else
		base_rev = REMOTE .. "/" .. base
		-- fetching `base` alongside refreshes origin/<base> in the same call
		vim.list_extend(cmd, { REMOTE, ("+refs/pull/%d/head:%s"):format(n, head_ref), base })
	end
	set_focus(ctx)
	vim.notify("fetching PR #" .. n .. " …", vim.log.levels.INFO)
	sys(cmd, { text = true }, function(res)
		vim.schedule(function()
			if res.code ~= 0 then
				vim.notify("fetch failed: " .. vim.trim(res.stderr), vim.log.levels.ERROR)
				return
			end
			vim.cmd(("DiffviewOpen %s...%s"):format(base_rev, head_ref))
		end)
	end)
end

-- gh review verbs. request-changes requires a body (GitHub API rule).
local function review(ctx, flag, verb, body_required)
	local root = repo_root()
	if not root then
		return
	end
	local n = ctx.pr.number
	vim.ui.input({ prompt = ("%s #%d — body%s: "):format(verb, n, body_required and "" or " (optional)") }, function(body)
		if body == nil then
			return -- <esc> aborts; empty <cr> proceeds (when body is optional)
		end
		if body == "" and body_required then
			vim.notify(verb .. " needs a body", vim.log.levels.WARN)
			return
		end
		local args = { "pr", "review", tostring(n), flag }
		if body ~= "" then
			vim.list_extend(args, { "--body", body })
		end
		gh(root, args, ctx, verb:lower() .. " sent on #" .. n)
	end)
end

function M.approve(ctx)
	review(ctx, "--approve", "Approve", false)
end

function M.request_changes(ctx)
	review(ctx, "--request-changes", "Request changes", true)
end

function M.comment(ctx)
	local root = repo_root()
	if not root then
		return
	end
	local n = ctx.pr.number
	vim.ui.input({ prompt = "Comment on #" .. n .. ": " }, function(body)
		if not body or body == "" then
			return
		end
		gh(root, { "pr", "comment", tostring(n), "--body", body }, ctx, "commented on #" .. n)
	end)
end

function M.request_reviewers(ctx)
	local root = repo_root()
	if not root then
		return
	end
	local n = ctx.pr.number
	vim.ui.input({ prompt = "Request reviewers for #" .. n .. " (comma-sep): " }, function(who)
		if not who or who == "" then
			return
		end
		gh(root, { "pr", "edit", tostring(n), "--add-reviewer", who }, ctx, "requested review on #" .. n)
	end)
end

function M.queue(ctx)
	local root = repo_root()
	if not root then
		return
	end
	gh(root, { "pr", "merge", tostring(ctx.pr.number), "--auto", "--squash" }, ctx, "auto-merge enabled on #" .. ctx.pr.number)
end

function M.checkout(ctx)
	local root = repo_root()
	if not root then
		return
	end
	if ctx.repo then
		vim.notify("#" .. ctx.pr.number .. " belongs to " .. ctx.repo .. " — checkout only works in its repo", vim.log.levels.WARN)
		return
	end
	gh(root, { "pr", "checkout", tostring(ctx.pr.number) }, ctx, "checked out #" .. ctx.pr.number)
end

function M.open_web(ctx)
	local root = repo_root()
	if not root then
		return
	end
	gh(root, { "pr", "view", tostring(ctx.pr.number), "--web" }, ctx, "opened #" .. ctx.pr.number .. " in browser")
end

function M.yank_url(ctx)
	local url = ctx.pr.url or ("https://github.com/%s/pull/%d"):format(ctx.repo or origin_repo(repo_root() or ".") or "?", ctx.pr.number)
	vim.fn.setreg("+", url)
	vim.notify("yanked " .. url, vim.log.levels.INFO)
end

-- ── the central float: `gh pr status` → three buckets ─────────────────────
local STATUS_FIELDS = "number,title,url,headRefName,baseRefName,state,reviewDecision,author"

local HINTS = "  d/⏎ diff · a approve · x changes · c comment · r reviewers · m queue · C checkout · y url · o web · q"

local function build_lines(status)
	local lines, rows = {}, {} -- rows[i] = pr json for the PR on display line i
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
				table.insert(rows, pr)
			end
		end
		table.insert(lines, "")
		table.insert(rows, false)
	end

	local cur = status.currentBranch
	section("● Current branch", cur and cur.number and { cur } or nil, "no PR for this branch")
	section("◆ Mine", status.createdBy, "none open")
	section("◇ Review requested", status.needsReview, "inbox clear")

	table.insert(lines, HINTS)
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

-- action keys shared by both floats: fn is called with a ctx; acting on a PR
-- also focuses it, so follow-up global keys (<leader>Pa …) hit the same PR.
local function bind_actions(buf, close, get)
	local kopts = { buffer = buf, nowait = true, silent = true }
	local function act(fn)
		return function()
			local ctx = get()
			if ctx then
				close()
				set_focus(ctx)
				fn(ctx)
			end
		end
	end
	local keys = {
		["<cr>"] = M.diff,
		d = M.diff,
		a = M.approve,
		x = M.request_changes,
		c = M.comment,
		r = M.request_reviewers,
		m = M.queue,
		C = M.checkout,
		y = M.yank_url,
		o = M.open_web,
	}
	for k, fn in pairs(keys) do
		vim.keymap.set("n", k, act(fn), kopts)
	end
end

-- multi-PR list (the `gh pr status` buckets)
local function open_float(lines, rows)
	local buf, win, close = make_float(lines, "  Pull Requests ")
	bind_actions(buf, close, function()
		local pr = rows[vim.api.nvim_win_get_cursor(win)[1]]
		if pr then
			return { pr = pr }
		end
	end)
	for i, r in ipairs(rows) do -- land on the first actionable row
		if r then
			vim.api.nvim_win_set_cursor(win, { i, 0 })
			break
		end
	end
end

-- single-PR status detail. Opening it FOCUSES the PR — from here on, the
-- global action keys target it.
local function open_pr_float(pr, repo)
	set_focus({ pr = pr, repo = repo })
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
		HINTS,
	}
	local title = repo and ("  %s #%d "):format(repo, pr.number) or ("  PR #%d "):format(pr.number)
	local buf, _, close = make_float(lines, title)
	bind_actions(buf, close, function()
		return { pr = pr, repo = repo }
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

-- branch PR float — also the way to re-focus YOUR PR after reviewing others
function M.current()
	local pr = M.current_pr()
	if pr then
		open_pr_float(pr)
	end
end

-- status float of the focused PR (falls back to the branch PR)
function M.status()
	local ctx = target()
	if ctx then
		open_pr_float(ctx.pr, ctx.repo)
	end
end

-- Jump to any PR by number / #number / github URL → its status float.
-- A URL from ANOTHER repo works: owner/repo is parsed out of it and every
-- action (view, diff, approve …) is routed there, no checkout, no cd.
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
		local repo = v:match("github%.com/([^/]+/[^/]+)/pull/")
		if repo and repo == origin_repo(root) then
			repo = nil -- it's this repo's PR — plain paths (origin refs, checkout) apply
		end
		local cmd = { "gh", "pr", "view", n, "--json", PR_FIELDS }
		if repo then
			vim.list_extend(cmd, { "-R", repo })
		end
		sys(cmd, { cwd = root, text = true }, function(res)
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
				open_pr_float(data, repo)
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

	-- action keys route through target(): the focused (in-view) PR, else this
	-- branch's PR. So: <leader>Pg → paste URL → d to diff → <leader>Pa
	-- approves THAT PR, even from inside the diff. No re-prompting.
	local function act(fn)
		return function()
			local ctx = target()
			if ctx then
				fn(ctx)
			end
		end
	end
	local map = vim.keymap.set
	map("n", "<leader>Pp", M.status, { desc = "PR: status float (focused, else branch)" })
	map("n", "<leader>Pb", M.current, { desc = "PR: this branch's PR (re-focuses it)" })
	map("n", "<leader>Pl", M.hub, { desc = "PR: list (current · mine · review-requested)" })
	map("n", "<leader>Pg", M.goto_pr, { desc = "PR: go to number / #n / url (any repo)" })
	map("n", "<leader>Pd", act(M.diff), { desc = "PR: diff in Diffview (no checkout)" })
	map("n", "<leader>Pa", act(M.approve), { desc = "PR: approve" })
	map("n", "<leader>Px", act(M.request_changes), { desc = "PR: request changes" })
	map("n", "<leader>Pc", act(M.comment), { desc = "PR: comment" })
	map("n", "<leader>Pr", act(M.request_reviewers), { desc = "PR: request reviewers" })
	map("n", "<leader>Pm", act(M.queue), { desc = "PR: auto-merge / queue (squash)" })
	map("n", "<leader>PC", act(M.checkout), { desc = "PR: checkout its branch" })
	map("n", "<leader>Po", act(M.open_web), { desc = "PR: open on github.com" })
	map("n", "<leader>Py", act(M.yank_url), { desc = "PR: yank url" })
	map("n", "<leader>gt", M.toggle, { desc = "Toggle inline PR review comments" })
end

return M
