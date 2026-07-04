-- prstatus.lua — quiet PR awareness for the statusline.
--
-- Resolves the current buffer's git worktree + branch, then asks `gh` for
-- that branch's PR: number, CI rollup, review decision. Everything runs
-- async via vim.system — the statusline only ever reads an in-memory
-- cache, so there is no path from "draw the statusline" to "spawn a
-- process and wait". First render (before anything has resolved) is "".
--
-- Render shape: "#<number> <ci>[ <review>]"
--   ci:     ✓ all checks green · ✗ something failed · ~ pending/running
--   review: ● changes requested · ✓ approved (omitted when not decisive)
--
-- `state()` reports which color the current render deserves, so the
-- lualine.lua component (which owns the actual palette) can map it to a
-- color without this module knowing about rose-pine.

local M = {}

local REFRESH_INTERVAL = 120 -- seconds, per (root, branch)

-- key = "<root>|<branch>" -> { rendered, state, ts }
local cache = {}
-- dir -> key, or `false` when dir has no repo/branch/PR
local dir_key = {}
-- dir -> last time we attempted to resolve root/branch for it
local last_attempt = {}
-- key -> true while a gh fetch is in flight, to avoid piling up requests
local fetching = {}

local function get_dir()
	local bufname = vim.api.nvim_buf_get_name(0)
	if bufname == "" then
		return vim.fn.getcwd()
	end
	return vim.fs.dirname(bufname)
end

-- statusCheckRollup + reviewDecision -> render string + color state
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

local function fetch_pr(key, root, branch)
	local now = os.time()
	local entry = cache[key]
	if (entry and now - entry.ts < REFRESH_INTERVAL) or fetching[key] then
		return
	end
	fetching[key] = true

	vim.system(
		{ "gh", "pr", "view", branch, "--json", "number,statusCheckRollup,reviewDecision" },
		{ cwd = root, text = true },
		function(res)
			vim.schedule(function()
				fetching[key] = false
				if res.code ~= 0 then
					cache[key] = { rendered = "", state = nil, ts = now }
					return
				end
				local ok, data = pcall(vim.json.decode, res.stdout)
				if not ok or not data or not data.number then
					cache[key] = { rendered = "", state = nil, ts = now }
					return
				end
				local rendered, state = render(data)
				cache[key] = { rendered = rendered, state = state, ts = now }
			end)
		end
	)
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

function M.setup()
	local group = vim.api.nvim_create_augroup("PrStatus", { clear = true })
	vim.api.nvim_create_autocmd({ "DirChanged", "FocusGained" }, {
		group = group,
		callback = function()
			M.refresh(get_dir())
		end,
	})
end

return M
