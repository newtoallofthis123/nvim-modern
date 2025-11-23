return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	opts = {
		bigfile = { enabled = true },
		bufdelete = { enabled = true },
		dashboard = {
			enabled = true,
			width = 60,
			row = nil,
			col = nil,
			pane_gap = 4,
			autokeys = "1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
			preset = {
				pick = nil,
				keys = {
					{ icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
					{
						icon = " ",
						key = "n",
						desc = "New File",
						action = function()
							vim.cmd("bd!")
							vim.cmd("enew")
						end,
					},
					{ icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('grep')" },
					{
						icon = " ",
						key = "r",
						desc = "Recent Files",
						action = ":lua Snacks.dashboard.pick('oldfiles')",
					},
					{ icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
					{ icon = " ", key = "s", desc = "Restore Session", section = "session" },
					{
						icon = "󰒲 ",
						key = "L",
						desc = "Lazy",
						action = ":Lazy",
						enabled = package.loaded.lazy ~= nil,
					},
					{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
				},
				header = [[


_   __            __   _
     / | / /___  ____  / /_ ( )_____
    /  |/ / __ \/ __ \/ __ \|// ___/
   / /|  / /_/ / /_/ / /_/ / (__  )
  /_/ |_/\____/\____/_.___/ /____/

        ]],
			},
			sections = {
				{ section = "header" },
				{ section = "keys", gap = 1, padding = 1 },
				{ section = "startup" },
			},
		},
		explorer = {
			replace_netrw = true,
			trash = true,
		},
		image = { enabled = true },
		indent = { enabled = false, char = "|" },
		git = { enabled = true },
		gitbrowse = { enabled = true },
		gh = { enabled = true },
		lazygit = { enabled = true, win = {
			style = "lazygit",
		} },
		picker = {
			actions = {
				set_glob_pattern = function(picker)
					require("snacks").input({
						prompt = "Glob pattern: ",
					}, function(pattern)
						if pattern and pattern ~= "" then
							picker.opts.args = picker.opts.args or {}
							table.insert(picker.opts.args, "--glob=" .. pattern)
							picker:find()
						end
					end)
				end,
				search_in_directory = {
					action = function(_, item)
						if not item then
							return
						end
						local dir = vim.fn.fnamemodify(item.file, ":p:h")
						require("snacks").picker.grep({
							cwd = dir,
							cmd = "rg",
							args = {},
							show_empty = true,
							hidden = true,
							ignored = true,
							follow = false,
							supports_live = true,
						})
					end,
				},
				search_files_in_directory = {
					action = function(_, item)
						if not item then
							return
						end
						local dir = vim.fn.fnamemodify(item.file, ":p:h")
						require("snacks").picker.files({
							cwd = dir,
							hidden = true,
							ignored = true,
							follow = false,
						})
					end,
				},
				create_file_in_directory = {
					action = function(picker, item)
						if not item then
							return
						end
						local dir = vim.fn.fnamemodify(item.file, ":p:h")
						require("snacks").input({
							prompt = "Filename: ",
						}, function(filename)
							if filename and filename ~= "" then
								local filepath = dir .. "/" .. filename
								vim.cmd("edit " .. vim.fn.fnameescape(filepath))
								picker:close()
							end
						end)
					end,
				},
			},
			matcher = {
				frecency = true,
			},
			list = {
				keys = {
					["t"] = { "tab" },
					["v"] = { "edit_vsplit" },
					["f"] = {
						"set_glob_pattern",
						mode = { "n" },
						desc = "Set glob pattern",
					},
					["s"] = { "search_in_directory", desc = "Search in directory" },
					["S"] = { "search_files_in_directory", desc = "Search files in directory" },
					["%"] = { "create_file_in_directory", desc = "Create file in directory" },
				},
			},
			sources = {
				explorer = {
					layout = { layout = { position = "right" } },
				},
				gh_issue = {},
				gh_pr = {},
			},

			win = {
				input = {
					keys = {
						["<S-k>"] = { "history_back", mode = { "n" } },
						["<S-j>"] = { "history_forward", mode = { "n" } },
						["t"] = { "tab" },
						["f"] = {
							"set_glob_pattern",
							mode = { "n" },
							desc = "Set glob pattern",
						},
						["v"] = { "edit_vsplit" },
						["%"] = { "create_file_in_directory", desc = "Create file in directory" },
					},
				},
			},
		},
		scroll = { enabled = false },
		scratch = { enabled = false },
		toggle = { enabled = true },
		input = { enabled = true },
		terminal = {},
	},
	keys = {
		{
			"<leader>E",
			function()
				Snacks.explorer({
					auto_close = true,
					matcher = { sort_empty = false, fuzzy = true },
				})
			end,
			desc = "File Explorer",
		},
		{
			"<leader>d",
			function()
				Snacks.bufdelete()
			end,
			desc = "Smart Delete Buffer",
		},
		{
			"<leader>D",
			function()
				Snacks.bufdelete.other()
			end,
			desc = "Delete all other buffers",
		},

		-- Pickers
		{
			"<leader>b",
			function()
				Snacks.picker.buffers()
			end,
			desc = "Open Buffers",
		},
		{
			"<leader>%",
			function()
				Snacks.picker.colorschemes()
			end,
			desc = "Open Colorschemes",
		},
		{
			"<leader>lp",
			function()
				Snacks.picker.diagnostics()
			end,
			desc = "Open LSP Diagnostics",
		},
		{
			"<leader>ld",
			function()
				Snacks.picker.diagnostics_buffer()
			end,
			desc = "Open LSP Diagnostics Buffer",
		},
		{
			"<leader>ld",
			function()
				Snacks.picker.diagnostics_buffer()
			end,
			desc = "Open LSP Diagnostics Buffer",
		},
		{
			"<leader>ff",
			function()
				Snacks.picker.files()
			end,
			desc = "Open Files",
		},
		{
			"<leader>fs",
			function()
				Snacks.picker.grep()
			end,
			desc = "Grep in Files",
		},
		{
			"<leader>gf",
			function()
				Snacks.picker.git_branches()
			end,
			desc = "Open Git Branches",
		},
		{
			"<leader>gs",
			function()
				Snacks.picker.git_status()
			end,
			desc = "Open Git Status",
		},
		{
			"<leader>o",
			function()
				Snacks.picker.lsp_symbols({
					filter = {
						elixir = true,
						typescript = true,
					},
				})
			end,
			desc = "LSP Symbols",
		},
		{
			"gd",
			function()
				Snacks.picker.lsp_definitions()
			end,
			desc = "LSP Definitions",
		},
		{
			"<leader>R",
			function()
				Snacks.picker.registers()
			end,
			desc = "Registers",
		},
		{
			"<leader>S",
			function()
				Snacks.picker.search_history()
			end,
			desc = "Search History",
		},
		{
			"<leader>s",
			function()
				Snacks.picker.spelling()
			end,
			desc = "Spelling Suggestions",
		},
		{
			"<leader>fe",
			function()
				Snacks.picker.smart()
			end,
			desc = "Smart Search",
		},

		-- Git stuff
		{
			"<leader>gb",
			function()
				Snacks.git.blame_line()
			end,
			desc = "Git Blame Line",
		},
		{
			"<leader>go",
			function()
				Snacks.gitbrowse()
			end,
			desc = "Git browse remote",
		},
		{
			"<leader>gl",
			function()
				Snacks.lazygit()
			end,
			desc = "Lazy Git",
		},
		{
			"<leader>gi",
			function()
				Snacks.picker.gh_issue()
			end,
			desc = "GitHub Issues (open)",
		},
		{
			"<leader>ge",
			function()
				Snacks.picker.gh_issue({ state = "all" })
			end,
			desc = "GitHub Issues (all)",
		},
		{
			"<leader>gp",
			function()
				Snacks.picker.gh_pr()
			end,
			desc = "GitHub Pull Requests (open)",
		},
		{
			"<leader>gP",
			function()
				Snacks.picker.gh_pr({ state = "all" })
			end,
			desc = "GitHub Pull Requests (all)",
		},

		-- Scratch buffer
		{
			"<leader>.",
			function()
				Snacks.scratch()
			end,
			desc = "Open a Scratch Buffer",
		},

		-- Grep visual selection and motion
		{
			"<leader>fw",
			function()
				local text = vim.fn.expand("<cword>")
				Snacks.picker.grep({ search = text })
			end,
			desc = "Grep word under cursor",
		},
		{
			"<leader>fw",
			function()
				-- Get visually selected text
				vim.cmd('noau normal! "vy"')
				local text = vim.fn.getreg("v")
				-- Replace newlines with spaces
				text = text:gsub("\n", " ")
				Snacks.picker.grep({ search = text })
			end,
			desc = "Grep visual selection",
			mode = "v",
		},

		-- Terminal
		{
			"<C-t>h",
			function()
				Snacks.terminal.toggle(nil, {
					win = {
						position = "bottom",
						height = 0.3,
					},
					count = 999, -- fixed id for the horizontal terminal
				})
			end,
			desc = "Toggle Horizontal Terminal",
			mode = { "n", "t" },
		},
		{
			"<C-t>1",
			function()
				vim.cmd("tabnew")
				Snacks.terminal.toggle(nil, {
					win = {
						position = "current",
					},
					count = 1,
				})
			end,
			desc = "Toggle Terminal 1 (Tab)",
			mode = { "n", "t" },
		},
		{
			"<C-t>2",
			function()
				vim.cmd("tabnew")
				Snacks.terminal.toggle(nil, {
					win = {
						position = "current",
					},
					count = 2,
				})
			end,
			desc = "Toggle Terminal 2 (Tab)",
			mode = { "n", "t" },
		},
		{
			"<C-t>3",
			function()
				vim.cmd("tabnew")
				Snacks.terminal.toggle(nil, {
					win = {
						position = "current",
					},
					count = 3,
				})
			end,
			desc = "Toggle Terminal 3 (Tab)",
			mode = { "n", "t" },
		},
		{
			"<C-t>t",
			function()
				vim.cmd("tabnew")
				Snacks.terminal.toggle(nil, {
					win = {
						position = "current",
					},
					count = 100, -- fixed id for temp terminal
				})
			end,
			desc = "Toggle Temp Terminal (Tab)",
			mode = { "n", "t" },
		},
		{
			"<C-t>i",
			function()
				Snacks.input({
					prompt = "Command: ",
				}, function(cmd)
					if cmd and cmd ~= "" then
						vim.cmd("tabnew")
						Snacks.terminal.open(cmd, {
							win = {
								position = "current",
							},
							count = 101, -- fixed id for input terminal
						})
					end
				end)
			end,
			desc = "Terminal with Input Command (Tab)",
			mode = { "n", "t" },
		},
	},
	config = function(_, opts)
		local snacks = require("snacks")
		snacks.setup(opts)

		-- Indent Stuff
		snacks.toggle.indent():map("<leader>ui")
		snacks.toggle.inlay_hints():map("<leader>uh")
		snacks.toggle.dim():map("<leader>uD")
		snacks.toggle.scroll():map("<leader>uS")
		snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
		snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")

		-- Motion-based grep function
		_G.__snacks_grep_motion = function(type)
			local saved_reg = vim.fn.getreg('"')
			local saved_regtype = vim.fn.getregtype('"')

			if type == "char" then
				vim.cmd('noau normal! `[v`]"zy')
			elseif type == "line" then
				vim.cmd('noau normal! `[V`]"zy')
			else
				return
			end

			local text = vim.fn.getreg("z")
			vim.fn.setreg('"', saved_reg, saved_regtype)

			if text and text ~= "" then
				-- Replace newlines with spaces
				text = text:gsub("\n", " ")
				snacks.picker.grep({ search = text })
			end
		end

		-- Set up motion keymap after function is defined
		vim.keymap.set("n", "gy", function()
			vim.o.operatorfunc = "v:lua.__snacks_grep_motion"
			return "g@"
		end, { expr = true, desc = "Grep motion" })
	end,
}
