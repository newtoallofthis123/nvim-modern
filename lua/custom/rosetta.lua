-- rosetta — decode the gibberish under your cursor.
--
-- <leader>K over a base64 blob / JWT / %-encoded URL / unix timestamp / 0xhex /
-- escaped JSON pops a float with the plain-text meaning. Auto-detection runs in
-- priority order (jwt > ts > url > json > base64 > hex); first confident match
-- wins. :Rosetta <codec> [text] forces a codec — and if the input doesn't
-- decode, it ENCODES instead (:Rosetta base64 hello → aGVsbG8=). In the float:
-- y yanks + closes, r replaces the source text, q/<Esc> closes. Pure Lua, no
-- deps, never touches a buffer unless you press r.

local M = {}

-- base64 (pure Lua, url-safe aware) ----------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function b64_encode(s)
	if vim.base64 then
		return vim.base64.encode(s)
	end
	local out, n = {}, #s
	for i = 1, n, 3 do
		local a, b, c = s:byte(i, i + 2)
		local x = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1 = math.floor(x / 262144) % 64
		local c2 = math.floor(x / 4096) % 64
		local c3 = math.floor(x / 64) % 64
		local c4 = x % 64
		out[#out + 1] = B64:sub(c1 + 1, c1 + 1)
		out[#out + 1] = B64:sub(c2 + 1, c2 + 1)
		out[#out + 1] = (i + 1 <= n) and B64:sub(c3 + 1, c3 + 1) or "="
		out[#out + 1] = (i + 2 <= n) and B64:sub(c4 + 1, c4 + 1) or "="
	end
	return table.concat(out)
end

local function b64_decode(s)
	s = s:gsub("%s", "")
	-- normalise url-safe → standard, then strip anything not in the alphabet
	local url = s:find("[-_]") ~= nil
	if url then
		s = s:gsub("-", "+"):gsub("_", "/")
	end
	s = s:gsub("=+$", "")
	if s == "" or s:find("[^A-Za-z0-9+/]") then
		return nil, "not base64"
	end
	local lut = {}
	for i = 1, #B64 do
		lut[B64:sub(i, i)] = i - 1
	end
	local out = {}
	for i = 1, #s, 4 do
		local c1 = lut[s:sub(i, i)]
		local c2 = lut[s:sub(i + 1, i + 1)]
		local c3 = lut[s:sub(i + 2, i + 2)]
		local c4 = lut[s:sub(i + 3, i + 3)]
		if not c1 or not c2 then
			return nil, "not base64"
		end
		local x = c1 * 262144 + c2 * 4096 + (c3 or 0) * 64 + (c4 or 0)
		out[#out + 1] = string.char(math.floor(x / 65536) % 256)
		if c3 then
			out[#out + 1] = string.char(math.floor(x / 256) % 256)
		end
		if c4 then
			out[#out + 1] = string.char(x % 256)
		end
	end
	return table.concat(out)
end

-- how much of this string is printable (for confident auto-detect)
local function printable_ratio(s)
	if #s == 0 then
		return 0
	end
	local ok = 0
	for i = 1, #s do
		local b = s:byte(i)
		if b == 9 or b == 10 or b == 13 or (b >= 32 and b < 127) then
			ok = ok + 1
		end
	end
	return ok / #s
end

-- pretty-print JSON (pure Lua, 2-space indent, stable-ish key order) --------
local function is_array(t)
	local n = 0
	for k in pairs(t) do
		if type(k) ~= "number" then
			return false
		end
		n = n + 1
	end
	return n == vim.tbl_count(t)
end

local function pretty(val, indent)
	indent = indent or ""
	local nl = "\n" .. indent .. "  "
	local t = type(val)
	if val == vim.NIL then
		return "null"
	elseif t == "table" then
		if vim.tbl_isempty(val) then
			return "{}"
		end
		local parts = {}
		if is_array(val) then
			for _, v in ipairs(val) do
				parts[#parts + 1] = nl .. pretty(v, indent .. "  ")
			end
			return "[" .. table.concat(parts, ",") .. "\n" .. indent .. "]"
		end
		local keys = vim.tbl_keys(val)
		table.sort(keys)
		for _, k in ipairs(keys) do
			parts[#parts + 1] = nl .. vim.json.encode(tostring(k)) .. ": " .. pretty(val[k], indent .. "  ")
		end
		return "{" .. table.concat(parts, ",") .. "\n" .. indent .. "}"
	elseif t == "string" then
		return vim.json.encode(val)
	elseif t == "number" or t == "boolean" then
		return tostring(val)
	end
	return "null"
end

-- format a unix time as UTC + local + relative --------------------------------
local function human_time(secs)
	local now = os.time()
	local diff = now - secs
	local rel
	local a = math.abs(diff)
	local unit, val
	if a < 60 then
		unit, val = "second", a
	elseif a < 3600 then
		unit, val = "minute", math.floor(a / 60)
	elseif a < 86400 then
		unit, val = "hour", math.floor(a / 3600)
	elseif a < 2592000 then
		unit, val = "day", math.floor(a / 86400)
	elseif a < 31536000 then
		unit, val = "month", math.floor(a / 2592000)
	else
		unit, val = "year", math.floor(a / 31536000)
	end
	local plural = val == 1 and "" or "s"
	rel = diff >= 0 and ("%d %s%s ago"):format(val, unit, plural)
		or ("in %d %s%s"):format(val, unit, plural)
	return {
		("UTC:   %s"):format(os.date("!%Y-%m-%d %H:%M:%S", secs)),
		("Local: %s"):format(os.date("%Y-%m-%d %H:%M:%S %Z", secs)),
		("Rel:   %s"):format(rel),
	}
end

-- codecs --------------------------------------------------------------------
-- each: detect(s)->bool, decode(s)->str|nil,err, encode(s)->str (optional)
-- decode returns (text, is_json) where is_json toggles json filetype.
local codecs = {}

codecs.base64 = {
	detect = function(s)
		if #s < 4 or s:find("[^A-Za-z0-9+/=_-]") then
			return false
		end
		local dec = b64_decode(s)
		if not dec then
			return false
		end
		if printable_ratio(dec) > 0.85 then
			return true
		end
		return pcall(vim.json.decode, dec)
	end,
	decode = function(s)
		local dec, err = b64_decode(s)
		if not dec then
			return nil, err
		end
		local ok, parsed = pcall(vim.json.decode, dec)
		if ok and type(parsed) == "table" then
			return pretty(parsed), true
		end
		-- only call it a decode if the bytes are meaningful; otherwise the
		-- caller (explicit :Rosetta) falls through to ENCODE the plain text.
		if printable_ratio(dec) < 0.85 then
			return nil, "not base64"
		end
		return dec
	end,
	encode = function(s)
		return b64_encode(s)
	end,
}

codecs.jwt = {
	detect = function(s)
		local _, dots = s:gsub("%.", "")
		return s:sub(1, 3) == "eyJ" and dots == 2
	end,
	decode = function(s)
		local parts = vim.split(s, ".", { plain = true })
		if #parts ~= 3 then
			return nil, "not a JWT (need 3 segments)"
		end
		local function seg(part, label)
			local dec = b64_decode(part)
			if not dec then
				return nil, "bad base64 in " .. label
			end
			local ok, obj = pcall(vim.json.decode, dec)
			if not ok then
				return nil, "bad JSON in " .. label
			end
			return obj
		end
		local header, herr = seg(parts[1], "header")
		if not header then
			return nil, herr
		end
		local payload, perr = seg(parts[2], "payload")
		if not payload then
			return nil, perr
		end
		local lines = { "// header", pretty(header), "", ("─"):rep(40), "", "// payload", pretty(payload) }
		local claims = { exp = "expires", iat = "issued", nbf = "not-before" }
		local extra = {}
		for claim, what in pairs(claims) do
			if type(payload[claim]) == "number" then
				extra[#extra + 1] = ("// %s (%s): %s"):format(claim, what, os.date("!%Y-%m-%d %H:%M:%S UTC", payload[claim]))
			end
		end
		table.sort(extra)
		if #extra > 0 then
			lines[#lines + 1] = ""
			vim.list_extend(lines, extra)
		end
		return table.concat(lines, "\n"), false
	end,
}

codecs.url = {
	detect = function(s)
		return s:find("%%%x%x") ~= nil
	end,
	decode = function(s)
		-- nothing to unescape → let explicit invocations ENCODE instead
		if not s:find("%%%x%x") and not s:find("+") then
			return nil, "nothing to decode"
		end
		local out = s:gsub("+", " "):gsub("%%(%x%x)", function(h)
			return string.char(tonumber(h, 16))
		end)
		return out
	end,
	encode = function(s)
		return (s:gsub("[^%w%-%._~]", function(c)
			return ("%%%02X"):format(c:byte())
		end))
	end,
}

codecs.ts = {
	detect = function(s)
		return s:match("^%d+$") ~= nil and (#s == 10 or #s == 13)
	end,
	decode = function(s)
		local num = tonumber(s)
		if not num then
			return nil, "not a number"
		end
		if #s == 13 then
			num = math.floor(num / 1000)
		elseif #s ~= 10 then
			return nil, "expected 10 (s) or 13 (ms) digits"
		end
		return table.concat(human_time(num), "\n"), false
	end,
}

codecs.hex = {
	detect = function(s)
		return s:match("^0x%x+$") ~= nil
	end,
	decode = function(s)
		local n = tonumber(s)
		if not n then
			-- decimal → hex (explicit reverse)
			local d = tonumber(s, 10)
			if not d then
				return nil, "not hex or decimal"
			end
			return ("0x%x"):format(d)
		end
		if s:match("^0x") then
			return tostring(n) -- hex → decimal
		end
		return ("0x%x"):format(n) -- decimal → hex
	end,
	encode = function(s)
		local d = tonumber(s, 10)
		if not d then
			return nil, "not a decimal number"
		end
		return ("0x%x"):format(d)
	end,
}

codecs.json = {
	detect = function(s)
		local t = vim.trim(s)
		if not t:match("^[%[{]") then
			return false
		end
		local ok, obj = pcall(vim.json.decode, t)
		return ok and type(obj) == "table"
	end,
	decode = function(s)
		local t = vim.trim(s)
		-- unescape \" style embedded JSON first
		if t:find('\\"') then
			t = t:gsub('\\"', '"'):gsub("\\\\", "\\")
		end
		local ok, obj = pcall(vim.json.decode, t)
		if not ok or type(obj) ~= "table" then
			return nil, "invalid JSON"
		end
		return pretty(obj), true
	end,
}

-- order matters for auto-detect
local AUTO = { "jwt", "ts", "url", "json", "base64", "hex" }
local NAMES = { "base64", "jwt", "url", "ts", "hex", "json" }

-- float presentation --------------------------------------------------------
-- src = { buf, srow, scol, erow, ecol } marking the replaceable range, or nil
local function show(codec, text, is_json, src)
	local lines = vim.split(text, "\n", { plain = true })
	local width, height = 1, #lines
	for _, l in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(l))
	end
	width = math.min(width + 2, math.floor(vim.o.columns * 0.7))
	height = math.min(height, math.floor(vim.o.lines * 0.5))

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	if is_json then
		vim.bo[buf].filetype = "json"
	end

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "cursor",
		row = 1,
		col = 0,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = (" rosetta · %s "):format(codec),
		title_pos = "center",
		focusable = true,
	})

	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	local kopts = { buffer = buf, nowait = true, silent = true }
	vim.keymap.set("n", "q", close, kopts)
	vim.keymap.set("n", "<Esc>", close, kopts)
	vim.keymap.set("n", "y", function()
		vim.fn.setreg('"', text)
		vim.fn.setreg("+", text)
		vim.notify("rosetta: yanked")
		close()
	end, kopts)
	vim.keymap.set("n", "r", function()
		if not src then
			vim.notify("rosetta: nothing to replace (result came from command text)", vim.log.levels.WARN)
			return
		end
		local repl = vim.split(text, "\n", { plain = true })
		vim.api.nvim_buf_set_text(src.buf, src.srow, src.scol, src.erow, src.ecol, repl)
		close()
		vim.notify("rosetta: replaced")
	end, kopts)
end

-- run a codec in decode-or-encode mode and present the result ----------------
local function transcode(name, input, src)
	local codec = codecs[name]
	if not codec then
		vim.notify("rosetta: unknown codec " .. name, vim.log.levels.ERROR)
		return
	end
	local text, is_json = codec.decode(input)
	if text then
		show(name, text, is_json, src)
		return
	end
	-- decode failed → try encode (unless decode-only)
	if codec.encode then
		local enc, eerr = codec.encode(input)
		if enc then
			show(name, enc, false, src)
			return
		end
		vim.notify("rosetta: " .. (eerr or "encode failed"), vim.log.levels.WARN)
		return
	end
	vim.notify("rosetta: " .. (is_json or "decode failed"), vim.log.levels.WARN)
end

-- auto-detect over a word ----------------------------------------------------
local function auto(input, src)
	for _, name in ipairs(AUTO) do
		local codec = codecs[name]
		if codec.detect(input) then
			local text, is_json = codec.decode(input)
			if text then
				show(name, text, is_json, src)
				return true
			end
		end
	end
	return false
end

-- grab the cWORD plus a trimmed variant, and its byte range in the buffer -----
local function word_under_cursor()
	local word = vim.fn.expand("<cWORD>")
	if word == "" then
		return nil
	end
	local trimmed = word:gsub("^[\"'`(%[{<]+", ""):gsub("[\"'`)%]}>,;:]+$", "")
	local line = vim.api.nvim_get_current_line()
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local s, e = line:find(trimmed, 1, true)
	local src
	if s then
		src = { buf = vim.api.nvim_get_current_buf(), srow = row, scol = s - 1, erow = row, ecol = e }
	end
	return trimmed, word, src
end

-- visual selection text + range ---------------------------------------------
local function selection()
	local srow, scol = vim.fn.line("v"), vim.fn.col("v")
	local erow, ecol = vim.fn.line("."), vim.fn.col(".")
	if srow > erow or (srow == erow and scol > ecol) then
		srow, scol, erow, ecol = erow, ecol, srow, scol
	end
	local lines = vim.api.nvim_buf_get_lines(0, srow - 1, erow, false)
	if #lines == 0 then
		return nil
	end
	ecol = math.min(ecol, #lines[#lines])
	local text
	if #lines == 1 then
		text = lines[1]:sub(scol, ecol)
	else
		lines[1] = lines[1]:sub(scol)
		lines[#lines] = lines[#lines]:sub(1, ecol)
		text = table.concat(lines, "\n")
	end
	local src = { buf = vim.api.nvim_get_current_buf(), srow = srow - 1, scol = scol - 1, erow = erow - 1, ecol = ecol }
	return text, src
end

-- surfaces ------------------------------------------------------------------
function M.cursor()
	local trimmed, raw, src = word_under_cursor()
	if not trimmed then
		vim.notify("rosetta: nothing under cursor", vim.log.levels.INFO)
		return
	end
	if auto(trimmed, src) then
		return
	end
	if raw ~= trimmed and auto(raw, nil) then
		return
	end
	vim.notify("rosetta: nothing I recognize", vim.log.levels.INFO)
end

function M.visual()
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
	local text, src = selection()
	if not text or text == "" then
		vim.notify("rosetta: empty selection", vim.log.levels.INFO)
		return
	end
	if not auto(text, src) then
		vim.notify("rosetta: nothing I recognize", vim.log.levels.INFO)
	end
end

-- :Rosetta <codec> [text] ----------------------------------------------------
function M.command(opts)
	local args = vim.split(vim.trim(opts.args), "%s+")
	local name = args[1]
	if not name or name == "" then
		vim.notify("rosetta: usage :Rosetta <codec> [text]", vim.log.levels.WARN)
		return
	end
	if not codecs[name] then
		vim.notify("rosetta: unknown codec " .. name, vim.log.levels.ERROR)
		return
	end
	table.remove(args, 1)
	local text = table.concat(args, " ")
	if text ~= "" then
		transcode(name, text, nil) -- command text: not replaceable
		return
	end
	-- no text: use visual range (when invoked as :'<,'>) or cursor word
	if opts.range and opts.range > 0 then
		local sr, er = opts.line1, opts.line2
		local lines = vim.api.nvim_buf_get_lines(0, sr - 1, er, false)
		local body = table.concat(lines, "\n")
		local src = { buf = vim.api.nvim_get_current_buf(), srow = sr - 1, scol = 0, erow = er - 1, ecol = #(lines[#lines] or "") }
		transcode(name, body, src)
	else
		local trimmed, _, src = word_under_cursor()
		if not trimmed then
			vim.notify("rosetta: nothing under cursor", vim.log.levels.INFO)
			return
		end
		transcode(name, trimmed, src)
	end
end

-- setup ---------------------------------------------------------------------
function M.setup()
	vim.keymap.set("n", "<leader>K", M.cursor, { desc = "rosetta: decode under cursor" })
	vim.keymap.set("x", "<leader>K", M.visual, { desc = "rosetta: decode selection" })
	vim.api.nvim_create_user_command("Rosetta", M.command, {
		nargs = "*",
		range = true,
		complete = function(arglead)
			return vim.tbl_filter(function(n)
				return n:find(arglead, 1, true) == 1
			end, NAMES)
		end,
	})
end

M.setup()
return M
