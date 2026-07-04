-- agentrecv.lua — the INBOUND half of the agent bridge (agentsend is outbound).
--
-- An agent in a sibling tmux pane drives this nvim through the `nvim-agent`
-- CLI, which resolves the @nvim window option this instance publishes (see
-- autocmds.lua) and calls M.rpc() over --remote-expr with a JSON payload.
--
-- Verbs:
--   jump <file> <line> <note>   — open file:line here; note pinned as virtual
--                                 text at the line, cleared on cursor move
--   touched <file...>           — remember the agent's changed files (latest
--                                 set only, no history); browse via keymaps
--
-- Keymaps:  <leader>an  touched files → quickfix
--           <leader>ap  touched files → picker

local M = {}

M.files = {} -- latest touched set; deliberately no history

local ns = vim.api.nvim_create_namespace("agentrecv")

-- ── rpc entry point ──────────────────────────────────────────────────────
-- Single dispatch keeps the CLI's vimscript expression trivial; args travel
-- as JSON so shell quoting never mangles paths or notes.
function M.rpc(payload)
	local ok, msg = pcall(vim.json.decode, payload)
	if not ok or type(msg) ~= "table" then
		return "agentrecv: bad payload"
	end
	if msg.verb == "jump" then
		vim.schedule(function()
			M.jump(msg.file, tonumber(msg.line), msg.note)
		end)
		return "ok"
	elseif msg.verb == "touched" then
		return M.touched(msg.files)
	end
	return "agentrecv: unknown verb " .. tostring(msg.verb)
end

-- ── jump — reverse agentsend ─────────────────────────────────────────────
function M.jump(file, line, note)
	if not file or vim.fn.filereadable(file) == 0 then
		return
	end
	vim.cmd.edit(vim.fn.fnameescape(file))
	if line and line > 0 then
		pcall(vim.api.nvim_win_set_cursor, 0, { line, 0 })
		vim.cmd("normal! zz")
	end
	if note and note ~= "" then
		local buf = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
		vim.api.nvim_buf_set_extmark(buf, ns, math.max((line or 1) - 1, 0), 0, {
			virt_text = { { "  ◆ " .. note, "AgentRecvNote" } },
			virt_text_pos = "eol",
		})
		-- the note lingers until you move — read it, move on, it's gone.
		-- Deferred: our own win_set_cursor above fires CursorMoved, and hooking
		-- immediately would clear the note before it's ever seen.
		vim.defer_fn(function()
			if not vim.api.nvim_buf_is_valid(buf) then
				return
			end
			vim.api.nvim_create_autocmd("CursorMoved", {
				buffer = buf,
				once = true,
				callback = function()
					vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
				end,
			})
		end, 100)
	end
end

-- ── touched files ────────────────────────────────────────────────────────
function M.touched(files)
	if type(files) ~= "table" then
		return "agentrecv: touched wants a file list"
	end
	M.files = vim.tbl_filter(function(f)
		return vim.fn.filereadable(f) == 1
	end, files)
	return ("ok %d"):format(#M.files)
end

local function no_files()
	if #M.files == 0 then
		vim.api.nvim_echo({ { "agentrecv: no touched files reported yet", "Comment" } }, false, {})
		return true
	end
	return false
end

function M.qflist()
	if no_files() then
		return
	end
	vim.fn.setqflist({}, " ", {
		title = "Agent touched",
		items = vim.tbl_map(function(f)
			return { filename = f, lnum = 1 }
		end, M.files),
	})
	vim.cmd.copen()
end

function M.picker()
	if no_files() then
		return
	end
	Snacks.picker({
		title = "Agent touched",
		items = vim.tbl_map(function(f)
			return { file = f, text = f }
		end, M.files),
		format = "file",
	})
end

-- ── setup ────────────────────────────────────────────────────────────────
function M.setup()
	-- rose-pine love, italic — same accent the tab bar uses for agent signals
	vim.api.nvim_set_hl(0, "AgentRecvNote", { fg = "#eb6f92", italic = true, default = true })
	vim.keymap.set("n", "<leader>an", M.qflist, { desc = "Agent touched → quickfix" })
	vim.keymap.set("n", "<leader>ap", M.picker, { desc = "Agent touched → picker" })
end

return M
