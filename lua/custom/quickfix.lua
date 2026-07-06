-- Quickfix power layer. quicker.nvim already owns the display + <leader>qq
-- toggle; this adds the picker-free ways to FILL and WALK it.
vim.o.grepprg = "rg --vimgrep --smart-case"
vim.o.grepformat = "%f:%l:%c:%m"

local map = vim.keymap.set

local function grep(word)
	if word and word ~= "" then
		vim.cmd("silent grep! " .. vim.fn.shellescape(word))
	end
end

-- grep the word under the cursor (or the selection) into the quickfix — no picker
map("n", "<leader>*", function()
	grep(vim.fn.expand("<cword>"))
end, { desc = "Grep word under cursor → quickfix" })
map("x", "<leader>*", function()
	local save, savet = vim.fn.getreg("v"), vim.fn.getregtype("v")
	vim.cmd('noautocmd normal! "vy')
	local sel = vim.fn.getreg("v")
	vim.fn.setreg("v", save, savet)
	grep(sel)
end, { desc = "Grep selection → quickfix" })

-- every file this branch changed vs main → quickfix, landing on each file's
-- first changed line. Diffs from the merge-base to the WORKING TREE, so it
-- covers committed branch work *and* uncommitted edits — the review view.
local function branch_to_qf()
	local root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
	if vim.v.shell_error ~= 0 or not root or root == "" then
		vim.api.nvim_echo({ { "not in a git repo", "Comment" } }, false, {})
		return
	end
	-- pick the trunk (main, else master) and diff from where we forked off it
	local base
	for _, b in ipairs({ "main", "master" }) do
		vim.fn.system({ "git", "-C", root, "rev-parse", "--verify", "--quiet", b })
		if vim.v.shell_error == 0 then
			base = b
			break
		end
	end
	if not base then
		vim.api.nvim_echo({ { "no main/master branch", "Comment" } }, false, {})
		return
	end
	local mb = vim.fn.systemlist({ "git", "-C", root, "merge-base", base, "HEAD" })[1]
	if not mb or mb == "" then
		return
	end

	-- first changed line per file: walk `git diff <mb> -U0` hunk headers and
	-- keep the +start of the first hunk seen after each `+++ b/<path>`.
	local firstline = {}
	local cur
	for _, dl in ipairs(vim.fn.systemlist({
		"git", "-C", root, "-c", "core.quotepath=false", "--no-pager",
		"diff", mb, "-U0", "--no-color",
	})) do
		local p = dl:match("^%+%+%+ b/(.+)$")
		if p then
			cur = p:gsub('^"(.*)"$', "%1")
		elseif cur then
			local start = dl:match("^@@ %-%d+,?%d* %+(%d+)")
			if start then
				firstline[cur] = firstline[cur] or tonumber(start)
			end
		end
	end

	local files = vim.fn.systemlist({
		"git", "-C", root, "-c", "core.quotepath=false", "diff", "--name-only", mb,
	})
	local items = {}
	for _, path in ipairs(files) do
		path = path:gsub('^"(.*)"$', "%1") -- strip quoting on odd paths
		if path ~= "" then
			local abs = root .. "/" .. path
			if vim.fn.filereadable(abs) == 1 then
				local lnum = firstline[path] or 1
				local content = vim.fn.readfile(abs, "", lnum)[lnum] or ""
				table.insert(items, { filename = abs, lnum = lnum, col = 1, text = content })
			end
		end
	end
	if #items == 0 then
		vim.api.nvim_echo({ { "no changes vs " .. base, "Comment" } }, false, {})
		return
	end
	vim.fn.setqflist({}, " ", { title = "Branch vs " .. base, items = items })
	vim.cmd("botright copen")
end
map("n", "<leader>gq", branch_to_qf, { desc = "Branch changes vs main → quickfix" })

-- walk the list, centered + wrapping
local function qnav(forward)
	local ok = pcall(vim.cmd, forward and "cnext" or "cprev")
	if not ok then
		pcall(vim.cmd, forward and "cfirst" or "clast") -- wrap at the ends
	end
	pcall(vim.cmd, "normal! zz")
end
map("n", "]q", function()
	qnav(true)
end, { desc = "Next quickfix (centered)" })
map("n", "[q", function()
	qnav(false)
end, { desc = "Prev quickfix (centered)" })
map("n", "]Q", "<cmd>clast<CR>zz", { desc = "Last quickfix" })
map("n", "[Q", "<cmd>cfirst<CR>zz", { desc = "First quickfix" })

-- pop the quickfix open the moment a grep/make fills it
vim.api.nvim_create_autocmd("QuickFixCmdPost", {
	group = vim.api.nvim_create_augroup("qf_autoopen", { clear = true }),
	pattern = "[^l]*", -- :grep / :make, not the :lgrep location-list variants
	callback = function()
		vim.cmd("botright copen")
	end,
})
