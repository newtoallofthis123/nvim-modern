-- Cursor smear — the cursor streaks to its destination instead of
-- teleporting. Pure candy; if it gets old, delete this file.
return {
	"sphamba/smear-cursor.nvim",
	event = "VeryLazy",
	opts = {
		-- transparent background: legacy symbols keep the smear from
		-- painting opaque cell backgrounds over the terminal's
		legacy_computing_symbols_support = true,
		smear_between_neighbor_lines = false, -- calm during j/k walking
		smear_insert_mode = false, -- no trails while typing
	},
}
