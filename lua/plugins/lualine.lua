return {
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		local c = {
			rose = "#ebbcba",
			gold = "#f6c177",
			foam = "#9ccfd8",
			iris = "#c4a7e7",
			pine = "#31748f",
			love = "#eb6f92",
			muted = "#6e6a86",
			subtle = "#908caa",
			text = "#e0def4",
		}

		-- "Quiet word" mode: a soft lowercase word, colored by mode (the second
		-- hand). Everything else stays quiet; gold is the one warm accent.
		local modes = {
			n = { "normal", c.rose },
			i = { "insert", c.foam },
			v = { "visual", c.iris },
			V = { "visual", c.iris },
			["\22"] = { "visual", c.iris },
			s = { "select", c.pine },
			S = { "select", c.pine },
			c = { "command", c.gold },
			R = { "replace", c.love },
			r = { "replace", c.love },
			["!"] = { "shell", c.gold },
			t = { "terminal", c.pine },
		}

		local mode = {
			function()
				return (modes[vim.fn.mode()] or modes.n)[1]
			end,
			color = function()
				return { fg = (modes[vim.fn.mode()] or modes.n)[2], gui = "bold" }
			end,
			padding = { left = 1, right = 1 },
		}

		-- Quiet, transparent theme: muted by default; components opt into color.
		local theme = {}
		for _, m in ipairs({ "normal", "insert", "visual", "replace", "command", "inactive" }) do
			theme[m] = {
				a = { fg = c.muted, bg = "NONE" },
				b = { fg = c.subtle, bg = "NONE" },
				c = { fg = c.muted, bg = "NONE" },
			}
		end

		require("lualine").setup({
			options = {
				theme = theme,
				component_separators = "·",
				section_separators = "",
				globalstatus = true,
			},
			sections = {
				lualine_a = {},
				lualine_b = { mode },
				lualine_c = {
					{ "branch", icon = "", color = { fg = c.muted } },
					{ "diagnostics" }, -- severity colors = meaningful
					{
						function()
							return require("nvim-navic").get_location()
						end,
						cond = function()
							return package.loaded["nvim-navic"] and require("nvim-navic").is_available()
						end,
					},
				},
				lualine_x = {
					{ "searchcount", maxcount = 999, color = { fg = c.gold } },
					{ "filetype", color = { fg = c.muted } },
				},
				lualine_y = {
					{ "location", color = { fg = c.subtle } },
					{ "progress", color = { fg = c.muted } },
				},
				lualine_z = {},
			},
			inactive_sections = {
				lualine_c = { { "filename", path = 1, color = { fg = c.muted } } },
				lualine_x = { { "location", color = { fg = c.muted } } },
			},
		})
	end,
}
