return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"saghen/blink.cmp",
		"mason-org/mason.nvim",
		"mason-org/mason-lspconfig.nvim",
	},
	config = function()
		local capabilities = require("blink.cmp").get_lsp_capabilities()
		capabilities.general = capabilities.general or {}
		capabilities.general.positionEncodings = { "utf-16" }

		-- Apply capabilities to every server we configure
		vim.lsp.config("*", { capabilities = capabilities })

		-- Symbol-under-cursor glow: a hairline underline, no fill (best on a
		-- transparent bg). Reapplied if the colorscheme changes.
		local function doc_hl_style()
			for _, g in ipairs({ "LspReferenceText", "LspReferenceRead", "LspReferenceWrite" }) do
				vim.api.nvim_set_hl(0, g, { underline = true, bg = "NONE" })
			end
		end
		doc_hl_style()
		vim.api.nvim_create_autocmd("ColorScheme", { callback = doc_hl_style })

		----------------------------------------------------------------------
		-- Server settings
		----------------------------------------------------------------------
		vim.lsp.config.lua_ls = {
			settings = {
				Lua = {
					diagnostics = { globals = { "vim" } },
					workspace = {
						library = vim.api.nvim_get_runtime_file("", true),
						checkThirdParty = false,
					},
					telemetry = { enable = false },
				},
			},
		}

		vim.lsp.config.ty = {}

		vim.lsp.config.ts_ls = {
			init_options = {
				preferences = { disableSuggestions = false },
			},
		}

		vim.lsp.config.emmet_ls = {}
		vim.lsp.config.astro = {}

		vim.lsp.config.rust_analyzer = {
			settings = {
				["rust-analyzer"] = {
					cargo = { allFeatures = true },
					checkOnSave = { command = "clippy" },
				},
			},
		}

		vim.lsp.config.gopls = {
			filetypes = { "go", "gomod", "gowork", "gotmpl" },
			settings = {
				gopls = {
					gofumpt = true,
					hints = {
						parameterNames = true,
						assignVariableTypes = true,
						rangeVariableTypes = true,
					},
				},
			},
		}

		-- Elixir (Dexter) — `brew install dexter-lsp`. Nav + format only; it
		-- does NOT emit compiler diagnostics by design (upstream issue #29).
		-- NOTE: don't put `.dexter/dexter.db` in root_markers — a nested-path
		-- marker resolves root_dir to the `.dexter/` index folder instead of the
		-- project. mix.exs/.git pin it to the actual project root.
		vim.lsp.config("dexter", {
			cmd = { "dexter", "lsp" },
			root_markers = { "mix.exs", ".git" },
			filetypes = { "elixir", "eelixir", "heex" },
			init_options = {
				followDelegates = true, -- jump through defdelegate to the target
			},
		})

		----------------------------------------------------------------------
		-- Mason: keep installs in sync, but DON'T auto-enable every installed
		-- server (that's what kept starting pyright/copilot). We enable
		-- explicitly below.
		----------------------------------------------------------------------
		require("mason-lspconfig").setup({
			ensure_installed = {
				"lua_ls",
				"ts_ls",
				"emmet_ls",
				"rust_analyzer",
				"gopls",
				"astro",
			},
			automatic_enable = false,
		})

		----------------------------------------------------------------------
		-- Diagnostics — rendered once, cleanly (tiny-inline-diagnostic draws
		-- the virtual text; we own signs + float here).
		----------------------------------------------------------------------
		vim.diagnostic.config({
			virtual_text = false,
			signs = {
				text = {
					[vim.diagnostic.severity.ERROR] = " ",
					[vim.diagnostic.severity.WARN] = " ",
					[vim.diagnostic.severity.HINT] = " ",
					[vim.diagnostic.severity.INFO] = " ",
				},
			},
			underline = true,
			update_in_insert = false,
			severity_sort = true,
			float = { border = "rounded", source = true },
		})

		----------------------------------------------------------------------
		-- Discoverable keymaps — set per-buffer when a server attaches.
		-- which-key surfaces these so you actually learn them.
		----------------------------------------------------------------------
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("noob-lsp-attach", { clear = true }),
			callback = function(ev)
				local buf = ev.buf
				local function map(keys, fn, desc, mode)
					vim.keymap.set(mode or "n", keys, fn, { buffer = buf, desc = "LSP: " .. desc })
				end

				-- Navigation (Snacks pickers — consistent with your gd)
				map("grr", function()
					Snacks.picker.lsp_references()
				end, "References")
				map("gri", function()
					Snacks.picker.lsp_implementations()
				end, "Implementations")
				map("grt", function()
					Snacks.picker.lsp_type_definitions()
				end, "Type definition")

				-- Actions
				map("grn", vim.lsp.buf.rename, "Rename")
				map("gra", vim.lsp.buf.code_action, "Code action", { "n", "x" })
				map("K", function()
					vim.lsp.buf.hover({ border = "rounded" })
				end, "Hover")
				map("<C-k>", function()
					vim.lsp.buf.signature_help({ border = "rounded" })
				end, "Signature help", "i")

				-- <leader>l group (mirrors the above so it shows in which-key)
				map("<leader>lr", vim.lsp.buf.rename, "Rename")
				map("<leader>la", vim.lsp.buf.code_action, "Code action", { "n", "x" })
				map("<leader>lR", function()
					Snacks.picker.lsp_references()
				end, "References")
				map("<leader>ls", function()
					Snacks.picker.lsp_symbols()
				end, "Document symbols")
				map("<leader>lS", function()
					Snacks.picker.lsp_workspace_symbols()
				end, "Workspace symbols")

				local client = vim.lsp.get_client_by_id(ev.data.client_id)

				-- LSP symbol breadcrumb in the statusline (via navic)
				if client and client:supports_method("textDocument/documentSymbol") then
					require("nvim-navic").attach(client, buf)
				end

				-- Native LSP folding (0.11+) for servers that return folding
				-- ranges — semantically richer than treesitter folds, which
				-- remain the fallback everywhere else (see options.lua).
				if client and client:supports_method("textDocument/foldingRange") then
					local win = vim.api.nvim_get_current_win()
					vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
				end

				-- Symbol-under-cursor glow on idle; cleared the moment you move.
				if client and client:supports_method("textDocument/documentHighlight") then
					local g = vim.api.nvim_create_augroup("noob-doc-hl-" .. buf, { clear = true })
					vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
						group = g,
						buffer = buf,
						callback = vim.lsp.buf.document_highlight,
					})
					vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
						group = g,
						buffer = buf,
						callback = vim.lsp.buf.clear_references,
					})
				end

				-- Inlay hints toggle (off by default)
				if client and client:supports_method("textDocument/inlayHint") then
					map("<leader>lh", function()
						vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }), { bufnr = buf })
					end, "Toggle inlay hints")
				end
			end,
		})

		----------------------------------------------------------------------
		-- Enable exactly the servers we want.
		----------------------------------------------------------------------
		vim.lsp.enable({
			"lua_ls",
			"ts_ls",
			"emmet_ls",
			"rust_analyzer",
			"dexter",
			"gopls",
			"astro",
			"ty",
		})
	end,
}
