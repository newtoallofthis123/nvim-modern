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

vim.opt.mouse = "a"

-- where throwaway scratch files live (see custom.napkin)
vim.g.tmp_dir = "/tmp/nvim"

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
-- Folds work again (ufo is gone): treesitter provides the structure
-- everywhere, and LSP folding takes over per-buffer on attach (see
-- lspconfig.lua) for servers that return folding ranges.
vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.o.foldtext = ""

----------------------------------------------------------------------
-- Feel & orientation (0.12 niceties)
----------------------------------------------------------------------
-- "Where am I" — never sit at the screen edge; keep context in view.
vim.opt.scrolloff = 10
vim.opt.sidescrolloff = 8
vim.opt.smoothscroll = true -- <C-d>/<C-u> scroll by visual lines (wrapped diffs)
vim.opt.splitkeep = "screen" -- opening a split stops yanking the text around

-- Live substitution preview in a split as you type the replacement.
vim.opt.inccommand = "split"

-- Snappier idle (CursorHold): symbol-glow appears fast, auto-reload checks
-- the disk soon after you stop moving.
vim.opt.updatetime = 250

-- Always reserve the sign column so diagnostics don't shove text sideways.
vim.opt.signcolumn = "yes"

-- One global rounded border for every floating window (hover, signature,
-- completion docs, pickers). Replaces per-plugin border config.
vim.opt.winborder = "rounded"

-- Diff cockpit: the engine behind diffview + native :diffsplit. histogram
-- aligns moved blocks; linematch lines up similar rows within a hunk;
-- inline:char highlights the exact characters that changed.
vim.opt.diffopt = {
	"internal",
	"filler",
	"closeoff",
	"algorithm:histogram",
	"indent-heuristic",
	"linematch:60",
	"inline:char",
}

-- Cozy texture: kill the ~ end-of-buffer tildes (loud on a transparent bg),
-- solid split divider, quiet fold column.
vim.opt.fillchars = {
	eob = " ",
	vert = "│",
	fold = " ",
	foldopen = "▾",
	foldclose = "▸",
	foldsep = " ",
	diff = "╱",
}
-- Audition: highlight only the line *number*, not the whole row.
-- vim.opt.cursorlineopt = "number"

vim.filetype.add({
	pattern = {
		[".*%.mdx"] = "markdown",
		[".*%.otio"] = "json",
	},
})

vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.hl.on_yank()
	end,
})

-- macOS clipboard, yank-only: an explicit yank (y) mirrors to the system
-- clipboard via the + register (pbcopy, see vim.g.clipboard above). Deletes
-- and changes (d/c/x) stay in Neovim's own registers and never clobber it.
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Mirror yanks (not deletes) to the macOS clipboard",
	group = vim.api.nvim_create_augroup("yank-to-clipboard", { clear = true }),
	callback = function()
		if vim.v.event.operator == "y" then
			vim.fn.setreg("+", vim.v.event.regcontents, vim.v.event.regtype)
		end
	end,
})
