# Changelog — the `rebuild`

A weekend overhaul of this Neovim config, from "bloated, flaky, can't remember
anything" into an **AI-review cockpit**: the LLM runs in a tmux pane, the dev
server runs in another, and nvim is where I read plans/tickets, review the
agent's diffs, and shuttle context between the three.

**The headline:** 68 → 44 plugins · ~72ms → ~18ms startup · 38 → ~8 plugins
loading at startup · zero LSP errors · Neovim 0.12.

---

## Removed (the de-bloat)

Culled 24 plugins that weren't earning their slot:

- **Dashboards / pickers I didn't use:** snipe, bento, yazi, flyer/fyler
- **AI-in-editor (deliberate — I keep the agent in tmux, not nvim):** neural,
  claudecode, copilot, cursortab
- **Terminal/duplication:** toggleterm (snacks owns it), vscode-diff
- **Superseded by natives:** nvim-ufo (LSP/treesitter folding), time-machine
  (built-in `:Undotree`), vim-sensible, automkdir, haunt
- **Unused:** early-retirement, tcount, dadbod, gruvbox, monokai (rose-pine only)

## Performance

- `vim.loader.enable()` — Lua bytecode cache, first line of `init.lua`
- `performance.rtp.disabled_plugins` for builtins I don't use (gzip, netrw,
  tar/zip, tutor, tohtml) — **but NOT matchit/matchparen** (see Fixes)
- Aggressive lazy-loading: every plugin on `event`/`ft`/`cmd`/`keys`

## LSP (native, 0.11+ style)

- Migrated to `vim.lsp.config()` / `vim.lsp.enable()` — no more
  `lspconfig.setup()` boilerplate; global capabilities via `vim.lsp.config("*")`
- mason-lspconfig `automatic_enable = false` — only the servers I want start
  (killed the phantom pyright/copilot starts)
- Removed fake "LSP servers" that were really formatters → moved to conform
- Discoverable per-buffer keymaps on `LspAttach`: `grr`/`gri`/`grt` (snacks
  pickers), `grn`/`gra`, `K` hover, `<leader>l*` group, inlay-hint toggle
- **nvim-navic** symbol breadcrumb in the statusline (depth 2)
- **Native LSP folding** (`vim.lsp.foldexpr`) per-buffer, treesitter fallback
- **Symbol-under-cursor glow** — `document_highlight` on idle, hairline
  underline, no fill (transparent-friendly)
- **Elixir: Expert → Dexter** (`dexter lsp`, `init_options.followDelegates`)
- Diagnostics: signs + rounded floats here, virtual text owned by
  tiny-inline-diagnostic

## Treesitter

- Upgraded to the `main` branch (FileType `vim.treesitter.start()`)
- Parsers for every language I touch (lua, rust, go, elixir/heex, python, ts/
  tsx, svelte, prisma, graphql, bash, dockerfile, git, markdown, …)
- **textobjects** (`main`): `]f`/`[f` function, `]a`/`[a` argument,
  `<leader>rs`/`rS` swap argument
- **mini.ai** treesitter specs: `af`/`if` function, `ac`/`ic` class,
  `ao`/`io` loop/conditional

## The diff-review cockpit

- **diffview-plus.nvim** (maintained fork): `<leader>gd` toggle review,
  `<leader>gh`/`gH` history, `<leader>gD` review the **whole branch vs main**
- `diffopt`: `algorithm:histogram` + `linematch:60` + `indent-heuristic` +
  `inline:char` — aligns moved blocks, highlights the exact chars that changed
- gitsigns `]c`/`[c` hunk-hop now **recenters** after the jump

## Navigation — the "flip family" (cousins of `<C-o>`)

One key, no picker, jump to the *other* one:

- `<C-o>` / `<C-i>` — last **position** (jumplist)
- `<BS>` — the **alternate file** (`<C-^>`, friendlier key)
- `<C-w>p` — the **last window/split**
- `g<Tab>` — the **last tab**
- `<leader>wm` — **zoom toggle**: maximize a split, press again to restore the
  exact prior layout
- `<leader>wt` — break the current split into its own tab
- Orientation: `scrolloff=10`, `smoothscroll`, `splitkeep=screen`,
  cursorline only in the active window (fixed), `signcolumn=yes`

## Editing gems (bespoke `lua/custom/gems.lua`)

- `<leader>cf` — **flip** the word/operator under cursor, case-preserved
  (`true`↔`false`, `==`↔`!=`, `&&`↔`||`, `and`↔`or`, `let`↔`const`, …)
- `<leader>cn`/`cN` — change word, then `.` repeats onto the next/prev match
- `<leader>cc` — toggle a markdown checkbox (`[ ]`↔`[x]`); works over a range
- `<leader>cb` — copy the visual selection as a `` ```fenced `` code block
- `<leader>cr` — sweep a substitution across every file in the quickfix list
- `<leader>rv` — visual-selection substitute across the file (visual `<leader>ra`)
- visual `*` / `#` — search the exact selection
- `<leader>so` / `<leader>su` — sort / sort+dedupe a selection
- `<leader>r!` — filter a selection through a shell command (`jq`, `sort`, …)
- `:Redir <cmd>` — dump any ex/lua command's output into a scratch split
- `<leader>ns` — toggle a markdown scratch pad
- `<leader>U` — native `:Undotree`; `]<Space>`/`[<Space>` blank line below/above
- `]x`/`[x` — jump between git conflict markers
- `gF` — follow a `path:line` token under the cursor, centered
- `inccommand=split` live substitute preview · `updatetime=250`
- **Auto-reload** files the agent edits in another pane (autoread + checktime)
- 0.12 whimsy: a line flash on `MarkSet`; tmux pane border glows gold while
  an LSP is indexing

## Quickfix (`lua/custom/quickfix.lua`)

The quickfix is the connective tissue (server errors, `cr` sweep, conflicts,
diagnostics all feed it). quicker.nvim owns display + `<leader>qq` toggle; this
adds the picker-free ways to fill & walk it:

- `<leader>*` — grep the word under the cursor (or selection) → quickfix, via
  ripgrep, no picker; auto-opens when filled
- `]q` / `[q` — next/prev, centered + wrapping · `]Q` / `[Q` last / first

## Markdown / prose layer (`after/ftplugin/markdown.lua`)

For writing tickets & plans:

- Soft wrap + linebreak + breakindent; `formatoptions -t` (no auto hard-wrap;
  `gq` still reflows to textwidth — md 80, commits 72)
- `j`/`k` move by visual line when wrapped, but a count moves real lines
- Emphasis (visual): `\b` bold · `\i` italic · `\c` code · `\s` strike
- `\=` / `\-` promote / demote the heading on the current line
- `]]` / `[[` jump between headings; `\o` dumps an outline to the loclist

## Custom tools — the cockpit bridge

nvim stays the reviewer + shuttle; the agent and server live in tmux.

### satchel (`lua/custom/satchel.lua`) — a ticket writer's context basket
A *ticket* and its *bucket* are one thing. `<leader>sn` names one → creates a
`<ddmmyyyy>_<name>.md` ticket (its own tab) + a bucket of `@path#Lnn` refs.

- `sn` new · `se` enter · `sx` leave · `sc` clear · `ss` manage
- `st` toss file · (visual) toss selection + fenced code
- `sa{f,c,o,m}` / `sA{f,c,o,m}` — **treesitter node toss** (function/class/
  loop/module) with the symbol name as a label, e.g.
  `@auth/session.rs#L40-58 (fn redirect)` — to bucket / straight to ticket
- `sf` insert a file ref · `sd` drop chosen · `sD` dump at cursor
- `sg` go to the ticket and dump it all · `sT` toss straight into the ticket
- Active bucket shows in lualine (muted name + gold count), only when active

### agentsend (`lua/custom/agentsend.lua`)
Send an `@file` ref straight into a claude/codex session in a tmux pane
(`<leader>aa`/`aA`/`ad`/`as`) — detects the pane via the `@app` option,
injects via bracketed paste so it doesn't trigger the `@` file-picker.

### justrun (`lua/custom/justrun.lua`) — drive the dev server in tmux
nvim never runs the server; it lists the tmux panes **in its own window**, I
pick one, and `just <recipe>` is sent there.

- `jr` pick recipe → pick pane → run · `jc` send a command
- `jx` restart (C-c + rerun) · `jk` kill (C-c)
- `jl` float the pane's logs · `je` scan pane output for `file:line` → quickfix
- `jp` (re)pick the target pane

### nvim socket → tmux (the inbound channel)
On `VimEnter` (in tmux) nvim tags its **window** with its RPC socket
(`@nvim <servername>`, cleared on exit); a zsh precmd
(`~/.config/zsh/nvim-socket.zsh`) exports `$NVIM` in every pane of that window.
So the agent / a `just` recipe / any script can drive the reviewer:
`nvim --server "$NVIM" --remote-send '<cmd>edit foo.rs<CR>'`. Window-scoped, so
each window talks to its own nvim.

## The look — "quiet word"

- **rose-pine** only, **transparent** (via transparent.nvim + `extra_groups`)
- Lualine: mode as a soft lowercase word colored by mode, gold the one warm
  accent; dot diagnostics, `+/~/-` diff, navic breadcrumb; muted everywhere else
- Tabby: project name + tabs, active = gold, `●` modified dot, transparent
- `fillchars eob=' '` kills the `~` end-of-buffer tildes; `winborder=rounded`

## Fixes

- **`%` was broken** — the de-bloat had disabled `matchit`/`matchparen`;
  re-enabled (extended `%` for `if`/`end`, tags, + the matching-bracket glow)
- **transparency regression** — restored transparent.nvim after a Phase-1
  over-removal
- **`<leader>s` shadowed** — snacks spelling owned the bare `<leader>s`; moved to
  `<leader>sp` so satchel's group is a clean prefix
- cursorline-only-in-active-window was missing its `WinLeave` half
- `vim.highlight.on_yank` → `vim.hl.on_yank` (0.11+ name)

---

_Built collaboratively over one weekend, interview-style. Every commit verified
with headless tests before landing._
