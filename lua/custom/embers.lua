-- embers.lua — lines you just touched glow in the sign column, then cool.
--
-- Editing leaves an ember: a "▎" in the sign column, bright amber the moment
-- you change a line, cooling through six steps to a dull grey over ~15 minutes
-- before it dies. A glance tells you what's fresh in a buffer without a diff.
-- Attaches to real file buffers on first enter; one global timer walks every
-- live mark every 30s and reassigns its colour by age. Sign priority 5, so
-- gitsigns (6) still wins the column when both land on a line.
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

-- six-step ramp: hot amber → dull grey, tuned for transparent / rose-pine.
local RAMP = { "#e0a458", "#cf9a5f", "#a98b6a", "#877d72", "#6b6a72", "#4d4a55" }

local function now()
	return vim.uv.now()
end

-- highlight groups ----------------------------------------------------------
local function set_hl()
	for i, fg in ipairs(RAMP) do
		vim.api.nvim_set_hl(0, "Embers" .. i, { fg = fg })
	end
end

-- attach / marks ------------------------------------------------------------
local function place(buf, line)
	local ok, id = pcall(vim.api.nvim_buf_set_extmark, buf, ns, line, 0, {
		sign_text = "▎",
		sign_hl_group = "Embers1",
		priority = 5,
	})
	if ok then
		marks[buf] = marks[buf] or {}
		marks[buf][id] = now()
	end
end

-- collapse a changed row range into one ember per line, resetting the clock.
local function touch(buf, first, last)
	local existing = {}
	if marks[buf] then
		for id in pairs(marks[buf]) do
			local ok, pos = pcall(vim.api.nvim_buf_get_extmark_by_id, buf, ns, id, {})
			if ok and pos[1] then
				existing[pos[1]] = id
			end
		end
	end
	for line = first, last - 1 do
		local id = existing[line]
		if id then
			marks[buf][id] = now()
		else
			place(buf, line)
		end
	end
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
			-- defer: extmarks have already shifted for this edit by next tick.
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(b) then
					touch(b, first, last)
				end
			end)
		end,
		on_detach = function(_, b)
			attached[b] = nil
		end,
	})
end

local function should_attach(buf)
	return vim.bo[buf].buftype == ""
		and vim.api.nvim_buf_get_name(buf) ~= ""
		and vim.api.nvim_buf_line_count(buf) <= MAX_LINES
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
							sign_text = "▎",
							sign_hl_group = "Embers" .. step_for(age),
							priority = 5,
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
