vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

vim.opt.smartindent = true
vim.opt.wrap = false

vim.opt.shell = "/bin/zsh"
vim.opt.shellcmdflag = "-c"

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true
vim.opt.background = "dark"

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.autoindent = true
vim.opt.smarttab = true
vim.opt.encoding = "UTF-8"
vim.opt.wildmenu = true
vim.opt.compatible = false
vim.opt.path:append("**")
vim.opt.wildignore:append("**/.git/**")
vim.opt.showtabline = 2
vim.opt.winbar = " " -- Add spacing below tabline
vim.opt.laststatus = 3 -- Global statusline

vim.opt.mouse = "a"

vim.g.clipboard = {
	name = "macOS-clipboard",
	copy = {
		["+"] = "pbcopy",
		["*"] = "pbcopy",
	},
	paste = {
		["+"] = "pbpaste",
		["*"] = "pbpaste",
	},
	cache_enabled = 0,
}

vim.opt.undofile = true
vim.opt.undodir = vim.fn.expand("~/.undodir")

vim.o.foldcolumn = "0"
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true

vim.filetype.add({
	pattern = {
		[".*%.mdx"] = "markdown",
	},
})

vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})
