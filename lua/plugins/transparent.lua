-- Global background transparency. rose-pine's styles.transparency only clears
-- the main background; this clears the rest (cursorline, statusline, floats)
-- and the new dropbar winbar.
return {
	"xiyaowong/transparent.nvim",
	lazy = false,
	priority = 999, -- after rose-pine (1000)
	opts = {
		extra_groups = {
			"WinBar",
			"WinBarNC",
			"DropBarCurrentContext",
			"DropBarMenuCurrentContext",
			"NormalFloat",
			"FloatBorder",
			"SnacksPickerList",
			"SnacksPickerInput",
			"SnacksPickerBox",
			"BlinkCmpMenu",
			"BlinkCmpMenuBorder",
		},
	},
	config = function(_, opts)
		require("transparent").setup(opts)
		-- Ensure it's on after a fresh (re)install
		if not vim.g.transparent_enabled then
			vim.cmd("TransparentEnable")
		end
	end,
}
