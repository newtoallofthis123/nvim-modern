-- homesick — one key carries you back to where the session began.
--
-- The first real file you open becomes home: file + the line you landed on.
-- However deep you wander — other repos, drilled overlays, quickfix spelunking —
-- <leader>H tethers you straight back, jumplist seeded so <C-o> undoes the trip.
--
--   <leader>H   go home
--   :Homesick   same; `:Homesick set` re-anchors home to where you are now

local M = {}

-- home = { file, lnum, col } — set once, on the session's first real file
M.home = nil

local function is_real(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	return vim.bo[buf].buftype == "" and name ~= "" and not name:match("^%w+://")
end

local function anchor(buf)
	local pos = vim.api.nvim_win_get_cursor(0)
	M.home = { file = vim.api.nvim_buf_get_name(buf), lnum = pos[1], col = pos[2] }
end

function M.go()
	if not M.home then
		vim.notify("homesick: no home yet this session", vim.log.levels.WARN)
		return
	end
	vim.cmd("normal! m'") -- seed the jumplist so <C-o> comes back
	if vim.api.nvim_buf_get_name(0) ~= M.home.file then
		vim.cmd("edit " .. vim.fn.fnameescape(M.home.file))
	end
	pcall(vim.api.nvim_win_set_cursor, 0, { M.home.lnum, M.home.col })
	vim.cmd("normal! zz")
	vim.notify("🏠 " .. vim.fn.fnamemodify(M.home.file, ":~:."))
end

function M.set()
	local buf = vim.api.nvim_get_current_buf()
	if not is_real(buf) then
		vim.notify("homesick: not a real file", vim.log.levels.WARN)
		return
	end
	anchor(buf)
	vim.notify("🏠 home is now " .. vim.fn.fnamemodify(M.home.file, ":~:.") .. ":" .. M.home.lnum)
end

function M.setup()
	local group = vim.api.nvim_create_augroup("Homesick", { clear = true })
	vim.api.nvim_create_autocmd("BufReadPost", {
		group = group,
		callback = function(ev)
			if M.home or not is_real(ev.buf) then
				return
			end
			-- let session restore / edit-with-line land the cursor first
			vim.schedule(function()
				if M.home or not vim.api.nvim_buf_is_valid(ev.buf) then
					return
				end
				if vim.api.nvim_get_current_buf() == ev.buf then
					anchor(ev.buf)
				else -- window moved on during startup churn; anchor to the top
					M.home = { file = vim.api.nvim_buf_get_name(ev.buf), lnum = 1, col = 0 }
				end
			end)
		end,
	})

	vim.keymap.set("n", "<leader>H", M.go, { desc = "homesick: go home" })
	vim.api.nvim_create_user_command("Homesick", function(a)
		if a.args == "set" then
			M.set()
		else
			M.go()
		end
	end, {
		nargs = "?",
		complete = function()
			return { "set" }
		end,
		desc = "homesick: go home (set = re-anchor here)",
	})
end

M.setup()
return M
