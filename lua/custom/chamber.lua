-- chamber — pick two functions from anywhere, see them side-by-side as an
-- aligned diff. "are these twins?"
--
-- A two-step ritual, no keymap:
--   :Chamber   inside function A → arms it; inside function B → opens a tab
--              with A|B in vertical scratch splits and runs diffthis on both.
--   :Chamber raw   same, but skip normalization (comments/blank-runs kept).
--   :Chamber!      re-arm fresh from the current function (drops stale state).
--   q (in either split) closes the whole tab.
--
-- Normalization is ON by default: strip comment lines / trailing comments via
-- treesitter comment nodes, and collapse runs of blank lines to one — so the
-- diff is about structure, not incidentals.

local M = {}

-- armed side: { text = {lines}, name, ft } or nil
M.armed = nil

-- per-language function-ish node types (walk ancestors until we hit one) ------
local FN_TYPES = {
	lua = { function_declaration = true, function_definition = true },
	go = { function_declaration = true, method_declaration = true },
	typescript = { function_declaration = true, method_definition = true, arrow_function = true },
	javascript = { function_declaration = true, method_definition = true, arrow_function = true },
	typescriptreact = { function_declaration = true, method_definition = true, arrow_function = true },
	javascriptreact = { function_declaration = true, method_definition = true, arrow_function = true },
	tsx = { function_declaration = true, method_definition = true, arrow_function = true },
	python = { function_definition = true },
	rust = { function_item = true },
	elixir = {}, -- handled specially below (call with a do_block)
}

-- an arrow_function is usually the value of `const f = () => …`; climb to the
-- owning statement so we capture the name + full declaration.
local ARROW_LIFT = {
	variable_declarator = true,
	lexical_declaration = true,
	variable_declaration = true,
	assignment_expression = true,
	export_statement = true,
	public_field_definition = true,
}

-- elixir: def/defp is a `call` whose first child names the definer -----------
local function elixir_fn(node)
	while node do
		if node:type() == "call" then
			local first = node:named_child(0)
			local name = first and vim.treesitter.get_node_text(first, 0)
			if name == "def" or name == "defp" or name == "defmacro" then
				return node
			end
			-- fallback: any call carrying a do_block
			for i = 0, node:named_child_count() - 1 do
				if node:named_child(i):type() == "do_block" then
					return node
				end
			end
		end
		node = node:parent()
	end
end

-- walk up from the cursor to the enclosing function-ish node, or nil ----------
local function enclosing_fn(ft)
	local ok, node = pcall(vim.treesitter.get_node)
	if not ok or not node then
		return nil
	end
	if ft == "elixir" then
		return elixir_fn(node)
	end
	local types = FN_TYPES[ft]
	if not types then
		return nil, "unsupported filetype: " .. (ft == "" and "none" or ft)
	end
	while node do
		if types[node:type()] then
			if node:type() == "arrow_function" then
				local p = node:parent()
				while p and ARROW_LIFT[p:type()] do
					node = p
					p = p:parent()
				end
			end
			return node
		end
		node = node:parent()
	end
	return nil
end

-- a display name for the node: its `name`/identifier child, else first line ---
local function display_name(node, bufnr)
	local f = node:field("name")
	if f and f[1] then
		return vim.treesitter.get_node_text(f[1], bufnr)
	end
	for i = 0, node:named_child_count() - 1 do
		local c = node:named_child(i)
		local t = c:type()
		if t == "identifier" or t == "name" or t == "field_identifier" then
			return vim.treesitter.get_node_text(c, bufnr)
		end
	end
	local sr = node:range()
	local first = vim.api.nvim_buf_get_lines(bufnr, sr, sr + 1, false)[1] or ""
	return vim.trim(first):sub(1, 40)
end

-- collect comment-node ranges within [sr, er] so we can strip them -----------
local function comment_spans(node, bufnr, ft)
	local spans = {}
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr, ft)
	if not ok or not parser then
		return spans
	end
	local root = parser:parse()[1]:root()
	local sr, _, er = node:range()
	local function walk(n)
		local t = n:type()
		if t == "comment" or t == "line_comment" or t == "block_comment" then
			local a, ac, b, bc = n:range()
			if a >= sr and b <= er then
				spans[#spans + 1] = { a, ac, b, bc }
			end
		end
		for c in n:iter_children() do
			walk(c)
		end
	end
	walk(root)
	return spans
end

-- extract the function under the cursor as a normalized (or raw) line list ----
local function extract(normalize)
	local bufnr = vim.api.nvim_get_current_buf()
	local ft = vim.bo[bufnr].filetype
	if not vim.treesitter.highlighter.active[bufnr] and not pcall(vim.treesitter.get_parser, bufnr, ft) then
		return nil, "no treesitter parser for this buffer"
	end
	local node, err = enclosing_fn(ft)
	if not node then
		return nil, err or "cursor is not inside a function"
	end
	local name = display_name(node, bufnr)
	local sr, _, er = node:range()
	local lines = vim.api.nvim_buf_get_lines(bufnr, sr, er + 1, false)

	if normalize then
		-- blank out comment spans (by absolute line), relative to sr
		for _, s in ipairs(comment_spans(node, bufnr, ft)) do
			local a, ac, b, bc = s[1], s[2], s[3], s[4]
			for l = a, b do
				local idx = l - sr + 1
				local text = lines[idx]
				if text then
					if l == a and l == b then
						lines[idx] = text:sub(1, ac) .. text:sub(bc + 1)
					elseif l == a then
						lines[idx] = text:sub(1, ac)
					elseif l == b then
						lines[idx] = text:sub(bc + 1)
					else
						lines[idx] = ""
					end
				end
			end
		end
		-- a line that is now only whitespace (was a full-line comment) → blank,
		-- then collapse runs of blank lines to one
		local out = {}
		local prev_blank = false
		for _, l in ipairs(lines) do
			local blank = vim.trim(l) == ""
			if blank then
				if not prev_blank then
					out[#out + 1] = ""
				end
			else
				out[#out + 1] = l
			end
			prev_blank = blank
		end
		lines = out
	end

	return { text = lines, name = name, ft = ft }
end

-- open a scratch split holding `side`, return its buffer ----------------------
local function scratch(side)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, side.text)
	pcall(vim.api.nvim_buf_set_name, buf, "chamber://" .. side.name)
	vim.bo[buf].filetype = side.ft
	return buf
end

-- close the whole tab from either split
local function close_tab()
	pcall(vim.cmd, "tabclose")
end

local function present(a, b)
	vim.cmd("tabnew")
	local left = scratch(a)
	vim.api.nvim_win_set_buf(0, left)
	vim.cmd("vsplit")
	local right = scratch(b)
	vim.api.nvim_win_set_buf(0, right)
	-- diff both windows
	vim.cmd("windo diffthis")
	for _, buf in ipairs({ left, right }) do
		vim.keymap.set("n", "q", close_tab, { buffer = buf, desc = "chamber: close" })
	end
end

-- :Chamber [raw] / :Chamber! -------------------------------------------------
function M.chamber(opts)
	local normalize = not (opts.args == "raw")
	local rearm = opts.bang

	if M.armed and not rearm then
		local b, err = extract(normalize)
		if not b then
			vim.notify("chamber: " .. err, vim.log.levels.WARN)
			return
		end
		local a = M.armed
		if a.name == b.name and vim.deep_equal(a.text, b.text) then
			vim.notify("chamber: that's the same function", vim.log.levels.INFO)
			return
		end
		present(a, b)
		M.armed = nil
		return
	end

	-- arm (fresh): normalization for the *pairing* is decided at fire time, but
	-- store raw+normalized-agnostic text based on this call's setting so raw and
	-- normal stay symmetric.
	local a, err = extract(normalize)
	if not a then
		vim.notify("chamber: " .. err, vim.log.levels.WARN)
		return
	end
	M.armed = a
	vim.notify(("chamber armed: %s (%d lines)"):format(a.name, #a.text))
end

function M.setup()
	vim.api.nvim_create_user_command("Chamber", M.chamber, {
		nargs = "?",
		bang = true,
		complete = function()
			return { "raw" }
		end,
		desc = "Chamber: side-by-side function diff (arm, then fire)",
	})
end

M.setup()
return M
