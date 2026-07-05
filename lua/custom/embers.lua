-- embers.lua — lines you just touched glow with a faint warm bg, then cool.
--
-- Editing leaves an ember: the whole line gets a barely-there amber wash the
-- moment you change it, cooling through six steps to almost-nothing over ~15
-- minutes before it dies. A glance tells you what's fresh in a buffer without
-- a diff. (The line background, not the gutter: gitsigns owns the sign AND
-- number columns in this config, so embers lives where nothing else does.)
-- Absolute colours, no blending — works over a transparent background.
-- Attaches to real file buffers on first enter; one global timer walks every
-- live mark every 30s and reassigns its colour by age. Bulk changes (formatter
-- rewrites, external reloads) are NOT embers — only human-sized edits burn.
--
--   :Embers clear    wipe every ember everywhere
--   :Embers toggle   enable / disable the whole plugin

local M = {}

local ns = vim.api.nvim_create_namespace("embers")

-- state: marks[bufnr][extmark_id] = timestamp_ms; attached[bufnr] = true
local marks = {}
local attached = {}
local enabled = true
local timer = nil

local STEPS = 6
local TICK_MS = 30 * 1000
local COOLDOWN_MS = 15 * 60 * 1000
local MAX_LINES = 10000
local BULK_LINES = 100 -- a single change touching more than this isn't you typing

-- six-step bg ramp: a whisper of warmth → nothing. Deliberately near-black:
-- over a dark transparent base the eye catches the temperature shift in the
-- periphery without ever reading it as a "highlighted line".
local RAMP = { "#211711", "#1c140f", "#17110d", "#120e0b", "#0d0a08", "#080706" }

local function now()
	return vim.uv.now()
end

-- highlight groups ----------------------------------------------------------
local function set_hl()
	for i, bg in ipairs(RAMP) do
		vim.api.nvim_set_hl(0, "Embers" .. i, { bg = bg })
	end
end

-- attach / marks ------------------------------------------------------------
local function place(buf, line)
	local ok, id = pcall(vim.api.nvim_buf_set_extmark, buf, ns, line, 0, {
		line_hl_group = "Embers1",
		priority = 1, -- under visual selection, search, cursorline
	})
	if ok then
		marks[buf] = marks[buf] or {}
		marks[buf][id] = now()
	end
end

-- collapse a changed row range into one ember per line, resetting the clock.
-- Only the marks inside the range are queried — never the whole buffer.
local function touch(buf, first, last)
	local existing = {}
	local in_range = vim.api.nvim_buf_get_extmarks(buf, ns, { first, 0 }, { math.max(last - 1, first), -1 }, {})
	for _, m in ipairs(in_range) do
		existing[m[2]] = m[1] -- row → id
	end
	for line = first, last - 1 do
		local id = existing[line]
		if id and marks[buf] and marks[buf][id] then
			marks[buf][id] = now()
		else
			place(buf, line)
		end
	end
end

-- pending edits per buffer, coalesced into one scheduled flush per burst
local pending = {}

local function should_attach(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	return vim.bo[buf].buftype == ""
		and name ~= ""
		and not name:match("^%w+://") -- oil://, fugitive://, fossick:// etc.
		and vim.api.nvim_buf_line_count(buf) <= MAX_LINES
end

local function attach(buf)
	if attached[buf] then
		return
	end
	attached[buf] = true
	vim.api.nvim_buf_attach(buf, false, {
		on_lines = function(_, b, _, first, _, last)
			if not enabled then
				attached[b] = nil
				return true -- detach
			end
			-- plugins like oil set buftype AFTER BufEnter; bail out late too
			if not should_attach(b) then
				attached[b] = nil
				pending[b] = nil
				vim.schedule(function()
					if vim.api.nvim_buf_is_valid(b) then
						pcall(vim.api.nvim_buf_clear_namespace, b, ns, 0, -1)
					end
					marks[b] = nil
				end)
				return true -- detach
			end
			if last - first > BULK_LINES then
				return -- formatter / generated rewrite, not an edit
			end
			-- coalesce: extend the pending range; only the first event schedules
			local p = pending[b]
			if p then
				p[1], p[2] = math.min(p[1], first), math.max(p[2], last)
				return
			end
			pending[b] = { first, last }
			vim.schedule(function()
				local range = pending[b]
				pending[b] = nil
				if range and vim.api.nvim_buf_is_valid(b) then
					if range[2] - range[1] <= BULK_LINES then
						touch(b, range[1], range[2])
					end
				end
			end)
		end,
		on_reload = function(_, b)
			-- external change (checktime etc.): every old mark is meaningless
			marks[b] = nil
			pending[b] = nil
			pcall(vim.api.nvim_buf_clear_namespace, b, ns, 0, -1)
		end,
		on_detach = function(_, b)
			attached[b] = nil
			pending[b] = nil
		end,
	})
end

-- cooling -------------------------------------------------------------------
local function step_for(age)
	local i = math.floor(age / COOLDOWN_MS * STEPS) + 1
	return math.min(i, STEPS)
end

local function tick()
	local t = now()
	for buf, ids in pairs(marks) do
		if not vim.api.nvim_buf_is_valid(buf) then
			marks[buf] = nil
		else
			for id, ts in pairs(ids) do
				local age = t - ts
				if age >= COOLDOWN_MS then
					pcall(vim.api.nvim_buf_del_extmark, buf, ns, id)
					ids[id] = nil
				else
					local ok, pos = pcall(vim.api.nvim_buf_get_extmark_by_id, buf, ns, id, {})
					if ok and pos[1] then
						pcall(vim.api.nvim_buf_set_extmark, buf, ns, pos[1], 0, {
							id = id,
							line_hl_group = "Embers" .. step_for(age),
							priority = 1,
						})
					else
						ids[id] = nil -- extmark vanished (line deleted)
					end
				end
			end
		end
	end
end

local function start_timer()
	if timer then
		return
	end
	timer = vim.uv.new_timer()
	timer:start(TICK_MS, TICK_MS, vim.schedule_wrap(tick))
end

-- clean-up ------------------------------------------------------------------
local function forget(buf)
	marks[buf] = nil
	attached[buf] = nil
end

function M.clear()
	for buf in pairs(marks) do
		if vim.api.nvim_buf_is_valid(buf) then
			pcall(vim.api.nvim_buf_clear_namespace, buf, ns, 0, -1)
		end
	end
	marks = {}
end

function M.toggle()
	enabled = not enabled
	if enabled then
		start_timer()
		local buf = vim.api.nvim_get_current_buf()
		if should_attach(buf) then
			attach(buf)
		end
		vim.notify("embers on")
	else
		M.clear() -- on_lines callbacks return true and detach on next edit
		attached = {}
		vim.notify("embers off")
	end
end

-- setup ---------------------------------------------------------------------
function M.setup()
	set_hl()
	start_timer()

	local group = vim.api.nvim_create_augroup("Embers", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_hl })
	vim.api.nvim_create_autocmd("BufEnter", {
		group = group,
		callback = function(ev)
			if enabled and should_attach(ev.buf) then
				attach(ev.buf)
			end
		end,
	})
	vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
		group = group,
		callback = function(ev)
			forget(ev.buf)
		end,
	})

	vim.api.nvim_create_user_command("Embers", function(o)
		local sub = o.args
		if sub == "clear" then
			M.clear()
		elseif sub == "toggle" then
			M.toggle()
		else
			vim.notify("Embers: clear | toggle", vim.log.levels.WARN)
		end
	end, {
		nargs = 1,
		complete = function(lead)
			return vim.tbl_filter(function(c)
				return c:find(lead, 1, true) == 1
			end, { "clear", "toggle" })
		end,
	})
end

M.setup()
return M
