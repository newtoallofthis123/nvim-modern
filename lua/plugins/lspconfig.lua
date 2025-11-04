return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "saghen/blink.cmp",
    "mason-org/mason.nvim",
    "mason-org/mason-lspconfig.nvim"
  },
  opts = {
servers = {
      lua_ls = {}
    }
  },
config = function()
    local capabilities = require("blink.cmp").get_lsp_capabilities()
    capabilities.general = capabilities.general or {}
    capabilities.general.positionEncodings = { 'utf-16' }

    local opts = { silent = true }

    vim.lsp.config.lua_ls = {
      capabilities = capabilities,
      settings = {
        Lua = {
          diagnostics = {
            globals = { "vim" },
          },
          workspace = {
            library = vim.api.nvim_get_runtime_file("", true),
            checkThirdParty = false,
          },
          telemetry = {
            enable = false,
          },
        },
      },
    }

    vim.lsp.config.pyright = {
      capabilities = capabilities,
      settings = {
        python = {
          analysis = {
            autoSearchPaths = true,
            diagnosticMode = "workspace",
            useLibraryCodeForTypes = true,
          },
        },
      },
    }

    vim.lsp.config.ts_ls = {
      capabilities = capabilities,
      init_options = {
        preferences = {
          disableSuggestions = false,
        },
      },
    }

    vim.lsp.config.prettier = {
      capabilities = capabilities
    }

    vim.lsp.config.emmet_ls = {
      capabilities = capabilities,
    }

    vim.lsp.config.rust_analyzer = {
      capabilities = capabilities,
      settings = {
        ["rust-analyzer"] = {
          cargo = {
            allFeatures = true,
          },
          checkOnSave = {
            command = "clippy",
          },
        },
      },
    }

    vim.lsp.config.astro = {
      capabilities = capabilities
    }

    vim.lsp.config('expert', {
      cmd = { '/Users/noob/.bin/expert_darwin_amd64' },
      root_markers = { 'mix.exs', '.git' },
      filetypes = { 'elixir', 'eelixir', 'heex' },
    })

    vim.lsp.config.copilot_language_server = {
      capabilities = capabilities
    }

    vim.diagnostic.config({
      virtual_text = true,
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = " ",
          [vim.diagnostic.severity.WARN] = " ",
          [vim.diagnostic.severity.HINT] = " ",
          [vim.diagnostic.severity.INFO] = " ",
        }
      },
      underline = true,
      update_in_insert = false,
      severity_sort = false,
    })

    -- Enable all configured LSP servers
    vim.lsp.enable({ 'lua_ls', 'pyright', 'ts_ls', 'emmet_ls', 'rust_analyzer', 'expert', 'copilot_language_server',
      'astro' })
  end,
}
