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

-- show cursorline only in active window enable
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
	group = vim.api.nvim_create_augroup("active_cursorline", { clear = true }),
	callback = function()
		vim.opt_local.cursorline = true
	end,
})
--
-- vim.api.nvim_create_autocmd("LspProgress", {
--     callback = function(ev)
--         local value = ev.data.params.value or {}
--         if not value.kind then return end
--
--         local status = value.kind == "end" and 0 or 1
--         local percent = value.percentage or 0
--
--         local osc_seq = string.format("\27]9;4;%d;%d\a", status, percent)
--
--         if os.getenv("TMUX") then
--             osc_seq = string.format("\27Ptmux;\27%s\27\\", osc_seq)
--         end
--
--         io.stdout:write(osc_seq)
--         io.stdout:flush()
--     end,
-- })
