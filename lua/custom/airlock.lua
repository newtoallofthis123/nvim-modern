-- Airlock — move buffers between nvim splits and tmux panes, both directions.
--
--   <leader>wx  eject: open this file (same line) in a new tmux pane to the
--               right, then close the nvim split it came from
--   <leader>wi  absorb: find a stray nvim in a sibling tmux pane, open its
--               file (same line) here and quit it (the pane's shell remains)
--   <C-t>H      drawer: toggle a real tmux pane below (drawer.sh) — the
--               tmux twin of snacks' <C-t>h toggleterm; survives hiding
--
-- Mechanism notes:
--  * Eject writes the buffer first — the tmux-side nvim reads from disk, so
--    an unsaved buffer would silently fork into two divergent copies.
--  * Absorb finds the stray's RPC socket by pid: nvim listens on
--    <run>/nvim.<pid>.0 and the pane's #{pane_pid} is the shell that spawned
--    it, so we match sockets whose pid has the pane's pid as an ancestor.
--  * The stray is closed with :qall (no bang) — unsaved changes keep it
--    alive, and we say so instead of eating the edit.

local M = {}

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, { title = "Airlock" })
end

local function in_tmux()
	if not vim.env.TMUX then
		notify("not inside tmux", vim.log.levels.WARN)
		return false
	end
	return true
end

-- ── eject: nvim split → tmux pane ─────────────────────────────────────

function M.eject()
	if not in_tmux() then
		return
	end
	local file = vim.api.nvim_buf_get_name(0)
	if file == "" or vim.bo.buftype ~= "" then
		notify("no file to eject", vim.log.levels.WARN)
		return
	end
	if vim.bo.modified then
		vim.cmd.write()
	end
	local line = vim.api.nvim_win_get_cursor(0)[1]
	vim.fn.system({
		"tmux",
		"split-window",
		"-h",
		"-c",
		vim.fn.getcwd(),
		string.format("nvim +%d %s", line, vim.fn.shellescape(file)),
	})
	if vim.v.shell_error ~= 0 then
		notify("tmux split failed", vim.log.levels.ERROR)
		return
	end
	-- The buffer has left the ship: close its window, or clear it if it's
	-- the last one (alternate buffer if we have one, empty buffer if not).
	if #vim.api.nvim_tabpage_list_wins(0) > 1 then
		vim.api.nvim_win_close(0, false)
	elseif vim.fn.buflisted(vim.fn.bufnr("#")) == 1 then
		vim.cmd.buffer("#")
	else
		vim.cmd.enew()
	end
end

-- ── absorb: stray tmux-pane nvim → this nvim ──────────────────────────

-- True if `ancestor` appears in pid's parent chain (pane_pid is the pane's
-- shell; the stray nvim is its child — or the pane itself when exec'd).
local function has_ancestor(pid, ancestor)
	for _ = 1, 5 do
		if pid == ancestor then
			return true
		end
		local out = vim.fn.system({ "ps", "-o", "ppid=", "-p", tostring(pid) })
		pid = tonumber(out)
		if not pid or pid <= 1 then
			return false
		end
	end
	return false
end

-- Socket of the nvim instance living in the pane whose shell is pane_pid.
local function socket_for_pane(pane_pid)
	local run = vim.fs.dirname(vim.fn.stdpath("run")) -- /tmp/nvim.<user>
	for _, sock in ipairs(vim.fn.glob(run .. "/*/nvim.*.0", true, true)) do
		local pid = tonumber(sock:match("nvim%.(%d+)%.0$"))
		if pid and pid ~= vim.fn.getpid() and has_ancestor(pid, pane_pid) then
			return sock
		end
	end
end

function M.absorb()
	if not in_tmux() then
		return
	end
	local panes = vim.fn.systemlist({
		"tmux",
		"list-panes",
		"-F",
		"#{pane_id}\t#{pane_pid}\t#{pane_current_command}",
	})
	for _, entry in ipairs(panes) do
		local pane_id, pane_pid, cmd = entry:match("^(%%%d+)\t(%d+)\t(.+)$")
		if pane_id and pane_id ~= vim.env.TMUX_PANE and (cmd == "nvim" or cmd == "vim") then
			local sock = socket_for_pane(tonumber(pane_pid))
			if not sock then
				notify(pane_id .. " runs nvim but its socket wasn't found", vim.log.levels.WARN)
				return
			end
			local out = vim.fn.system({
				"nvim",
				"--server",
				sock,
				"--remote-expr",
				[[expand('%:p') . "\t" . line('.')]],
			})
			local file, line = out:match("^(.-)\t(%d+)")
			if not file or file == "" then
				notify("stray nvim has no file open — left it alone", vim.log.levels.WARN)
				return
			end
			-- :qall without ! — unsaved changes keep the stray alive.
			vim.fn.system({ "nvim", "--server", sock, "--remote-send", [[<C-\><C-n>:qall<CR>]] })
			vim.cmd(string.format("edit +%s %s", line, vim.fn.fnameescape(file)))
			-- The pane's shell survives the quit; only warn if nvim itself did.
			vim.defer_fn(function()
				local cmd_now = vim.fn.system({
					"tmux",
					"display-message",
					"-t",
					pane_id,
					"-p",
					"#{pane_current_command}",
				})
				if cmd_now:match("n?vim") then
					notify("stray nvim wouldn't quit (unsaved changes?)", vim.log.levels.WARN)
				end
			end, 200)
			return
		end
	end
	notify("no sibling pane running nvim", vim.log.levels.WARN)
end

function M.drawer()
	if not in_tmux() then
		return
	end
	vim.fn.system({ vim.fn.expand("~/.config/tmux/scripts/drawer.sh"), vim.env.TMUX_PANE })
end

function M.setup()
	vim.keymap.set("n", "<leader>wx", M.eject, { desc = "Airlock: eject buffer → tmux pane" })
	vim.keymap.set("n", "<leader>wi", M.absorb, { desc = "Airlock: absorb tmux-pane nvim → here" })
	vim.keymap.set({ "n", "t" }, "<C-t>H", M.drawer, { desc = "Airlock: toggle tmux drawer pane below" })
end

return M
