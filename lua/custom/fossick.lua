-- fossick — scrub the current file through its git history like video.
--
-- :Fossick / <leader>gF clones the buffer into a scratch "film reel". Index 0
-- is the live working copy; 1..N are commits newest→oldest (via --follow, so
-- renames are chased). h/l step a frame, H/L jump ten, 0/$ hit the ends, d
-- diffs the frame against the file on disk, q rolls it back. A footer shows
-- where you are. Blobs load lazily, cache by sha, and prefetch their neighbours
-- so held-key scrubbing stays smooth.

local M = {}

-- one scrub at a time; nil when idle
M.state = nil

-- git plumbing --------------------------------------------------------------

-- Parse `git log --name-status` output into newest→oldest {sha,date,subject,path}.
-- The date field disambiguates a commit header from a name-status line (A/C/D
-- are valid hex, but never followed by a date). Rename lines list old→new; the
-- last path is the file's name AT that commit, which is what `git show` wants.
local function parse(out)
	local entries, cur = {}, nil
	for _, line in ipairs(vim.split(out or "", "\n", { plain = true })) do
		local sha, date, subj = line:match("^(%x+)\t(%d%d%d%d%-%d%d%-%d%d)\t(.*)$")
		if sha and #sha >= 7 then
			cur = { sha = sha, date = date, subject = subj }
			entries[#entries + 1] = cur
		elseif cur and not cur.path then
			local _, rest = line:match("^([A-Z]%d*)\t(.+)$")
			if rest then
				local parts = vim.split(rest, "\t", { plain = true })
				cur.path = parts[#parts]
			end
		end
	end
	return entries
end

-- Lines of <sha>:<path>, synchronously. Trims git's trailing newline.
local function load_blob(sha, path)
	local st = M.state
	if st.cache[sha] then
		return st.cache[sha]
	end
	local res = vim.system({ "git", "show", sha .. ":" .. path }, { cwd = st.root, text = true }):wait()
	local lines = vim.split(res.stdout or "", "\n", { plain = true })
	if #lines > 0 and lines[#lines] == "" then
		table.remove(lines)
	end
	st.cache[sha] = lines
	return lines
end

-- Warm the immediate neighbours in the background (commit frames only).
local function prefetch(idx)
	local st = M.state
	for _, i in ipairs({ idx - 1, idx + 1 }) do
		local e = st.entries[i]
		if e and not st.cache[e.sha] then
			vim.system(
				{ "git", "show", e.sha .. ":" .. (e.path or st.rel) },
				{ cwd = st.root, text = true },
				function(res)
					vim.schedule(function()
						if M.state == st and not st.cache[e.sha] then
							local lines = vim.split(res.stdout or "", "\n", { plain = true })
							if #lines > 0 and lines[#lines] == "" then
								table.remove(lines)
							end
							st.cache[e.sha] = lines
						end
					end)
				end
			)
		end
	end
end

-- footer --------------------------------------------------------------------

local HINT = "h/l step · H/L ×10 · 0/$ ends · d diff · o github · q quit"

function M.footer_text()
	local st = M.state
	if not st then
		return nil
	end
	if st.idx == 0 then
		return ("◀ 0/%d · working copy"):format(#st.entries)
	end
	local e = st.entries[st.idx]
	return ("◀ %d/%d · %s · %s · %s"):format(st.idx, #st.entries, e.sha:sub(1, 7), e.date, e.subject)
end

local function ensure_footer()
	local st = M.state
	if st.foot_win and vim.api.nvim_win_is_valid(st.foot_win) then
		return
	end
	st.foot_buf = vim.api.nvim_create_buf(false, true)
	local width = vim.api.nvim_win_get_width(st.win)
	st.foot_win = vim.api.nvim_open_win(st.foot_buf, false, {
		relative = "win",
		win = st.win,
		anchor = "NW",
		row = vim.api.nvim_win_get_height(st.win) - 2,
		col = 0,
		width = width,
		height = 2,
		focusable = false,
		style = "minimal",
		noautocmd = true,
		zindex = 50,
	})
	vim.wo[st.foot_win].winhl = "Normal:Pmenu"
end

local function update_footer()
	local st = M.state
	ensure_footer()
	-- keep it pinned to the bottom in case the window resized
	pcall(vim.api.nvim_win_set_config, st.foot_win, {
		relative = "win",
		win = st.win,
		anchor = "NW",
		row = vim.api.nvim_win_get_height(st.win) - 2,
		col = 0,
		width = vim.api.nvim_win_get_width(st.win),
		height = 2,
	})
	vim.api.nvim_buf_set_lines(st.foot_buf, 0, -1, false, { M.footer_text(), HINT })
end

-- scrubbing -----------------------------------------------------------------

function M.show(idx)
	local st = M.state
	if not st then
		return
	end
	idx = math.max(0, math.min(idx, #st.entries))
	local cur = vim.api.nvim_win_get_cursor(st.win)
	local lines
	if idx == 0 then
		lines = st.live
	else
		local e = st.entries[idx]
		lines = st.cache[e.sha] or load_blob(e.sha, e.path or st.rel)
	end
	st.idx = idx
	vim.bo[st.scrub].modifiable = true
	vim.api.nvim_buf_set_lines(st.scrub, 0, -1, false, lines)
	vim.bo[st.scrub].modifiable = false
	local line = math.max(1, math.min(cur[1], #lines))
	pcall(vim.api.nvim_win_set_cursor, st.win, { line, cur[2] })
	update_footer()
	prefetch(idx)
end

-- viewed frame vs the file on disk, in its own tab (leaves the reel intact)
function M.diff()
	local st = M.state
	if not st then
		return
	end
	local viewed = vim.api.nvim_buf_get_lines(st.scrub, 0, -1, false)
	local tag = st.idx == 0 and "working" or st.entries[st.idx].sha:sub(1, 7)
	vim.cmd("tabnew " .. vim.fn.fnameescape(st.realpath))
	vim.cmd("diffthis")
	vim.cmd("vsplit")
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, viewed)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = st.ft
	pcall(vim.api.nvim_buf_set_name, buf, "fossick-diff://" .. tag)
	vim.api.nvim_win_set_buf(0, buf)
	vim.cmd("diffthis")
end

-- the viewed frame on github.com: origin remote → blob/<sha>/<path>#L<line>
function M.open_origin()
	local st = M.state
	if not st then
		return
	end
	local res = vim.system({ "git", "remote", "get-url", "origin" }, { cwd = st.root, text = true }):wait()
	if res.code ~= 0 then
		vim.notify("fossick: no origin remote", vim.log.levels.WARN)
		return
	end
	local url = vim.trim(res.stdout):gsub("%.git$", "")
	url = url:gsub("^git@([^:]+):", "https://%1/"):gsub("^ssh://git@", "https://")
	-- working copy isn't on github; the newest commit of this file is its closest truth
	local e = st.idx == 0 and st.entries[1] or st.entries[st.idx]
	local line = vim.api.nvim_win_get_cursor(st.win)[1]
	local permalink = ("%s/blob/%s/%s#L%d"):format(url, e.sha, e.path or st.rel, line)
	vim.ui.open(permalink)
	vim.notify("fossick: opened " .. e.sha:sub(1, 7) .. " on origin")
end

function M.cleanup()
	local st = M.state
	if not st or st.cleaning then
		return
	end
	st.cleaning = true
	if st.foot_win and vim.api.nvim_win_is_valid(st.foot_win) then
		pcall(vim.api.nvim_win_close, st.foot_win, true)
	end
	if st.foot_buf and vim.api.nvim_buf_is_valid(st.foot_buf) then
		pcall(vim.api.nvim_buf_delete, st.foot_buf, { force = true })
	end
	if st.win and vim.api.nvim_win_is_valid(st.win) and vim.api.nvim_buf_is_valid(st.orig) then
		vim.api.nvim_win_set_buf(st.win, st.orig)
		pcall(vim.api.nvim_win_set_cursor, st.win, st.cursor)
	end
	if st.scrub and vim.api.nvim_buf_is_valid(st.scrub) then
		pcall(vim.api.nvim_buf_delete, st.scrub, { force = true })
	end
	M.state = nil
end

local function start(root, rel, entries)
	local orig = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()
	local ft = vim.bo[orig].filetype
	local scrub = vim.api.nvim_create_buf(false, true)
	vim.bo[scrub].buftype = "nofile"
	vim.bo[scrub].bufhidden = "wipe"
	vim.bo[scrub].swapfile = false
	vim.bo[scrub].filetype = ft
	pcall(vim.api.nvim_buf_set_name, scrub, "fossick://" .. rel .. "@live")

	M.state = {
		root = root,
		rel = rel,
		realpath = root .. "/" .. rel,
		entries = entries,
		live = vim.api.nvim_buf_get_lines(orig, 0, -1, false),
		orig = orig,
		win = win,
		cursor = vim.api.nvim_win_get_cursor(win),
		scrub = scrub,
		ft = ft,
		cache = {},
		idx = 0,
	}

	vim.api.nvim_win_set_buf(win, scrub)

	local map = function(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { buffer = scrub, nowait = true, silent = true, desc = desc })
	end
	map("l", function()
		M.show(M.state.idx - 1)
	end, "fossick: newer")
	map("h", function()
		M.show(M.state.idx + 1)
	end, "fossick: older")
	map("L", function()
		M.show(M.state.idx - 10)
	end, "fossick: newer ×10")
	map("H", function()
		M.show(M.state.idx + 10)
	end, "fossick: older ×10")
	map("0", function()
		M.show(#M.state.entries)
	end, "fossick: oldest")
	map("$", function()
		M.show(0)
	end, "fossick: working copy")
	map("d", M.diff, "fossick: diff vs file")
	map("o", M.open_origin, "fossick: open commit on github")
	map("<leader>gO", M.open_origin, "fossick: open commit on github")
	map("q", M.cleanup, "fossick: quit")

	vim.api.nvim_create_autocmd({ "BufWinLeave", "WinClosed" }, {
		buffer = scrub,
		callback = function()
			M.cleanup()
		end,
	})

	M.show(0)
end

function M.fossick()
	local file = vim.api.nvim_buf_get_name(0)
	if file == "" then
		vim.notify("fossick: no file in this buffer", vim.log.levels.WARN)
		return
	end
	local dir = vim.fn.fnamemodify(file, ":h")
	local top = vim.system({ "git", "rev-parse", "--show-toplevel" }, { cwd = dir, text = true }):wait()
	if top.code ~= 0 then
		vim.notify("fossick: not a git repo", vim.log.levels.WARN)
		return
	end
	local root = vim.trim(top.stdout)
	local rel = vim.fn.fnamemodify(file, ":p"):sub(#root + 2)

	vim.system({
		"git", "log", "--follow", "--name-status",
		"--format=%H%x09%ad%x09%s", "--date=short", "--", rel,
	}, { cwd = root, text = true }, function(res)
		vim.schedule(function()
			local entries = parse(res.stdout)
			if res.code ~= 0 or #entries == 0 then
				vim.notify("fossick: no git history for " .. rel, vim.log.levels.WARN)
				return
			end
			start(root, rel, entries)
		end)
	end)
end

function M.setup()
	vim.api.nvim_create_user_command("Fossick", M.fossick, {})
	vim.keymap.set("n", "<leader>gF", M.fossick, { desc = "fossick: scrub git history" })
end

M.setup()
return M
