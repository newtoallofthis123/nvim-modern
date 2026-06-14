vim.api.nvim_create_autocmd("BufWritePre", {
	desc = "Autocreate a dir when saving a file",
	group = vim.api.nvim_create_augroup("auto_create_dir", { clear = true }),
	callback = function(event)
		if event.match:match("^%w%w+:[\\/][\\/]") then
			return
		end
		local file = vim.uv.fs_realpath(event.match) or event.match
		vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
	end,
})

vim.api.nvim_create_user_command("E", function(opts)
	local path = vim.fn.expand(opts.args)
	local dir = vim.fn.fnamemodify(path, ":h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	end
	vim.cmd("edit " .. path)
end, { nargs = 1, complete = "file" })

-- restore cursor position when reopening files
vim.api.nvim_create_autocmd("BufReadPost", {
	callback = function(args)
		local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
		local line_count = vim.api.nvim_buf_line_count(args.buf)
		if mark[1] > 0 and mark[1] <= line_count then
			vim.api.nvim_win_set_cursor(0, mark)
			vim.schedule(function()
				vim.cmd("normal! zz")
			end)
		end
	end,
})

-- auto resize splits when the terminal's window is resized
vim.api.nvim_create_autocmd("VimResized", {
	command = "wincmd =",
})

-- no auto continue comments on new line
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("no_auto_comment", {}),
	callback = function()
		vim.opt_local.formatoptions:remove({ "c", "r", "o" })
	end,
})

-- syntax highlighting for dotenv files
vim.api.nvim_create_autocmd("BufRead", {
	group = vim.api.nvim_create_augroup("dotenv_ft", { clear = true }),
	pattern = { ".env", ".env.*" },
	callback = function()
		vim.bo.filetype = "dosini"
	end,
})

-- show cursorline only in the active window (the "you are here" marker)
local active_cursorline = vim.api.nvim_create_augroup("active_cursorline", { clear = true })
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
	group = active_cursorline,
	callback = function()
		vim.wo.cursorline = true
	end,
})
vim.api.nvim_create_autocmd("WinLeave", {
	group = active_cursorline,
	callback = function()
		vim.wo.cursorline = false
	end,
})

-- LSP indexing pulse → tmux pane border. While any language server is busy
-- (begin..end progress) the active pane border glows gold, then resets the
-- moment all servers go idle. Your editor talking to your multiplexer.
if vim.env.TMUX then
	local pulse = vim.api.nvim_create_augroup("tmux_lsp_pulse", { clear = true })
	-- Remember the theme's own border colour so we restore it, not "default".
	local rest = vim.fn.system({ "tmux", "show-options", "-wv", "pane-active-border-style" })
	rest = (rest:gsub("%s+$", ""))
	if rest == "" then
		rest = "default"
	end
	local active = 0
	local function border(on)
		vim.system({ "tmux", "set", "-w", "pane-active-border-style", on and "fg=#f6c177" or rest })
	end
	vim.api.nvim_create_autocmd("LspProgress", {
		group = pulse,
		callback = function(ev)
			local kind = vim.tbl_get(ev, "data", "params", "value", "kind")
			if kind == "begin" then
				active = active + 1
				border(true)
			elseif kind == "end" then
				active = math.max(0, active - 1)
				if active == 0 then
					border(false)
				end
			end
		end,
	})
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = pulse,
		callback = function()
			border(false)
		end,
	})
end

-- Auto-reload files changed underneath us — the LLM writes in another pane,
-- nvim refreshes the buffer when you focus/enter/idle on it, and says so.
vim.o.autoread = true
local autoreload = vim.api.nvim_create_augroup("auto_reload", { clear = true })
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
	group = autoreload,
	callback = function()
		-- checktime errors inside the cmdline window; guard it
		if vim.fn.mode() ~= "c" and vim.fn.getcmdwintype() == "" then
			vim.cmd("checktime")
		end
	end,
})
vim.api.nvim_create_autocmd("FileChangedShellPost", {
	group = autoreload,
	callback = function()
		vim.notify("Reloaded — file changed on disk", vim.log.levels.INFO)
	end,
})

-- Reflow width for prose so gq / gw wrap cleanly: markdown 80, commits 72
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("prose_textwidth", { clear = true }),
	pattern = { "markdown", "gitcommit", "text" },
	callback = function(ev)
		vim.opt_local.textwidth = ev.match == "gitcommit" and 72 or 80
	end,
})

-- Flash the line when you drop a named mark (0.12 MarkSet event)
local mark_ns = vim.api.nvim_create_namespace("mark_flash")
vim.api.nvim_create_autocmd("MarkSet", {
	group = vim.api.nvim_create_augroup("mark_flash", { clear = true }),
	callback = function(ev)
		if not (ev.match or ""):match("^%a$") then
			return
		end
		local row = vim.api.nvim_win_get_cursor(0)[1] - 1
		vim.hl.range(0, mark_ns, "Visual", { row, 0 }, { row, -1 }, { timeout = 200 })
	end,
})
