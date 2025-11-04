# nvim config

My personal Neovim configuration, rewritten for modern development workflows.

## ✨ Highlights

- 🤖 **AI-Powered** - GitHub Copilot integration with blink.cmp
- 🔍 **Fast Navigation** - Snacks picker for fuzzy finding files, buffers, and grep
- 📝 **Multi-Language LSP** - Support for Lua, Python, TypeScript, Rust, Elixir, HTML/CSS, and more
- 🎨 **Rosé Pine Theme** - Beautiful colorscheme with transparency support
- 🌳 **Git-First** - Gitsigns, Fugitive, LazyGit, and GitHub CLI integration
- ⚡ **Performance** - Lazy loading via lazy.nvim
- 🎯 **Smart Editing** - Auto-pairs, surround, treesitter text objects, and more

## 📦 Core Plugins

### Completion & AI
- **blink.cmp** - Fast completion engine with Copilot, LSP, snippets, and buffer sources
- **copilot.lua** - GitHub Copilot integration
- **nvim-scissors** - Snippet editor/manager

### LSP & Language Support
- **nvim-lspconfig** - LSP for 8+ languages (Lua, Python, TypeScript, Rust, Elixir, etc.)
- **mason.nvim** - Automatic LSP/formatter/linter installer
- **conform.nvim** - Format on save with stylua, black, prettier, and more
- **nvim-treesitter** - Advanced syntax highlighting for 20+ languages

### Navigation & File Management
- **snacks.nvim** - Multi-tool with fuzzy finder, explorer, terminal, dashboard, and Git integration
- **oil.nvim** - Edit filesystem like a buffer
- **yazi.nvim** - Terminal file manager integration
- **flash.nvim** - Enhanced motion and search

### Git Integration
- **gitsigns.nvim** - Git signs in gutter, hunk operations
- **vim-fugitive** - Full Git workflow
- **lazygit** - TUI Git client (via snacks)
- **GitHub CLI** - Browse issues and PRs (via snacks)

### UI & Theme
- **rose-pine** - Main colorscheme with transparency
- **lualine.nvim** - Custom statusline
- **tabby.nvim** - Custom tabline
- **nvim-colorizer.lua** - Highlight color codes
- **which-key.nvim** - Keybinding popup helper

### Editing Enhancement
- **nvim-surround** - Surround text objects
- **nvim-autopairs** - Auto-close pairs
- **mini.ai** - Extended text objects
- **nvim-ufo** - Advanced code folding with LSP

### Utilities
- **tmux.nvim** - Seamless tmux-nvim navigation
- **persistence.nvim** - Session management
- **snipe.nvim** - Quick buffer/symbol switching
- **time-machine.nvim** - File history browser

## ⌨️ Key Bindings

**Leader:** `Space` | **Local Leader:** `\`

### Files & Navigation
| Key | Action |
|-----|--------|
| `<leader>ff` | Find files |
| `<leader>fs` | Grep in files |
| `<leader>fw` | Grep word under cursor |
| `<leader>fw` (visual) | Grep visual selection |
| `gy{motion}` | Grep motion (e.g., `gyt,` greps to comma) |
| `<leader>b` | Open buffers |
| `<leader>e` / `-` | Oil file explorer |
| `<leader>_` | Yazi file manager |
| `<leader>n` | New file |

### LSP
| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `<leader>ld` | Buffer diagnostics |
| `<leader>lp` | Project diagnostics |
| `<leader>F` | Format buffer |
| `<leader>O` | LSP symbols menu |
| `<leader>o` | LSP symbols picker |

### Git
| Key | Action |
|-----|--------|
| `<leader>hs` | Stage hunk |
| `<leader>hr` | Reset hunk |
| `<leader>hp` | Preview hunk |
| `]c` / `[c` | Next/previous hunk |
| `<leader>gb` | Git blame line |
| `<leader>gl` | LazyGit |
| `<leader>go` | Open in browser |
| `<leader>gi` | GitHub issues |
| `<leader>gp` | GitHub PRs |

### Buffers & Tabs
| Key | Action |
|-----|--------|
| `<leader>d` | Smart delete buffer |
| `<leader>'` | Buffer menu (snipe) |
| `<leader>tn` | New tab |
| `<leader>t1-9` | Go to tab 1-9 |

### Terminal
| Key | Action |
|-----|--------|
| `<C-t>h` | Horizontal terminal |
| `<C-t>1/2/3` | Terminal in new tab |
| `<C-t>t` | Temp terminal |
| `<C-t>i` | Terminal with command input |

### Motion & Editing
| Key | Action |
|-----|--------|
| `s` | Flash jump |
| `S` | Flash treesitter |
| `<leader>y` | Yank to clipboard |
| `<leader>p` | Paste from clipboard |
| `<leader>ra` | Find and replace word |

### Session Management
| Key | Action |
|-----|--------|
| `<leader>qs` | Load session |
| `<leader>ql` | Load last session |

### Toggles
| Key | Action |
|-----|--------|
| `<leader>ui` | Toggle indent guides |
| `<leader>uh` | Toggle inlay hints |
| `<leader>us` | Toggle spelling |
| `<leader>uw` | Toggle wrap |

## 🚀 Features

### Smart Window Navigation
Custom split navigation that auto-creates splits when navigating to non-existent windows.

### Motion-Based Grep
Use `gy` followed by any motion to grep selected text:
- `gyt,` - Grep to comma
- `gyiw` - Grep word
- `gyip` - Grep paragraph

### Format on Save
Automatic formatting with language-specific formatters and LSP fallback.

### AI Completion
Copilot integrated with blink.cmp, prioritized in completion menu with manual trigger mode.

### Custom Dashboard
Snacks dashboard with quick actions, recent files, and startup time display.

### Session Persistence
Auto-saves sessions per directory with multiple session slots.

## 📁 Structure

```
~/.config/nvim/
├── init.lua              # Entry point
├── lua/
│   ├── config/
│   │   ├── init.lua     # Loads all config
│   │   ├── options.lua  # Vim options
│   │   ├── keymaps.lua  # Global keybindings
│   │   ├── autocmds.lua # Autocommands
│   │   └── lazy.lua     # Plugin manager setup
│   └── plugins/         # Plugin configurations (27 files)
└── README.md
```

## 🎨 Theme

**Rosé Pine** - A warm, muted colorscheme with transparency support. Custom Lualine configuration with mode-specific colors.
