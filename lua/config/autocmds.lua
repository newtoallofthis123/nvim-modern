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
