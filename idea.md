# idea.md — brainstorm state

Running log of ideas proposed by Claude, with Ishan's verdicts. This file is the
algorithm's state: new batches get appended, selections marked, taste notes updated.

## Selected (the keepers list)

- **gate** — your own ngrok. `gate 3000` → public URL to localhost, E2E-encrypted
  with the upload split-key trick, Cloudflare Durable Objects + tunnels underneath.
- **vinyl** — Spotify shadow. Scrobbles every play into local SQLite forever;
  `vinyl wrapped`, `vinyl on-this-day`, `vinyl graph 2026`. Own the taste layer,
  let Spotify stay the dumb catalog.
- **stash** — where physical things are. `stash put passport "blue box, closet"`,
  `stash find passport`. Ten lines of Go, saves you on flight day.
- **burner** — `burner mail` → disposable address on stdout, incoming mail streams
  to the terminal live. Cloudflare Email Workers.
- **clip** — clipboard history as a Unix stream. Every copy lands in SQLite;
  `clip search`, `clip 3 | pbcopy`, `clip watch |` pipes copies live.
- **hook** — burner's twin for webhooks. `hook` → instant public URL, events
  stream to stdout as JSON lines. `hook | jq '.pusher'`.
- **beam** — netcat reborn. `beam file.png` one machine, `beam` on the other —
  Tailscale at home, WebRTC hole-punch outside. Pipes work across machines.
- **snoop** — Little Snitch as a Unix tool. `snoop watch` → live pipeable stream
  of which process talks to which host. macOS NetworkExtension depth.
- **otp** — 2FA codes out of Authenticator jail, into the Keychain shh-style.
  `otp github | pbcopy`. Signed binary, TouchID-gated, zero cloud.

## Batch 3 — only `short` landed

- **short** — SELECTED. bit.ly → yours: `short <url>` → `noobscience.in/l/fox`. Worker + KV.
- counted (personal analytics), hoard (encrypted incremental backup to R2),
  reel (Loom-style record→upload), meet (P2P WebRTC 1:1), page (uptime monitor),
  sinkhole (local Pi-hole), hum (terminal Shazam) — all meh.
- Lesson: **custodial tools flop** (backup/monitoring/analytics = becoming your own
  sysadmin = dependence with extra steps); replacing un-broken media tools flops.
  Winner profile: instant primitive — seconds to value, zero upkeep, identity stamp.

## Batch 4 — name, when, ports, wifi selected

- **name** — SELECTED. Word-triple generator liberated from upload (`quiet-purple-fox`
  for branches/servers/projects). His twist: AI-powered mode via his `ai` CLI —
  `name --ai "<what it is>"` → thematically-loaded triples. Two of his tools composing.
- **when** — SELECTED. `when 3pm PST` → IST, `when standup` with taught names.
- **ports** — SELECTED. Clean table of listeners + `ports kill 3000`.
- **wifi** — SELECTED. `wifi qr` → guest-scannable QR, password from Keychain.
- redact (secret-stripping pipe), frame (carbon.sh → yours), tld (domain availability),
  mock (instant fake API from JSON) — meh.
- Lesson refined: dev-flow *accessories* (redact/frame/mock) flop; **tiny everyday
  delights** land. Playful > professional.

## Batch 5 — total flop

- stats (pipe → histogram), timer, sun (Hyderabad weather one-liner), title (url →
  markdown link), conv (units/currency), emoji (fuzzy → clipboard), roll (decision
  dice) — none landed, "kind of a stretch."
- Lesson: instant-but-hollow fails. A one-liner convenience with no system underneath
  (no Keychain/network/Workers/state cave) isn't a keeper, it's an alias.
  **Both legs required: summoned in a second AND standing on something deep.**

## Batch 6 — total flop

- ghost (instant disposable VM), invite (browser terminal into a local sandbox),
  scan (LAN device census), leak (HIBP k-anonymity check), watch (page-change
  pinger), pdf (local sign/fill/flatten) — all no.
- Read: security/prudence/occasional-use tools don't excite him even with depth.
  Two consecutive flops after 14 hits → the vein is likely mined out; feed converged.

## Batch 7 (exploration spike: own-data given shape) — all rejected, "getting repetitive"

- tape (asciinema → yours, terminal recording → upload link), year (git wrapped
  across all local repos), grave (generated graveyard for dead projects with
  epitaphs), guestbook (90s guestbook on a Worker, terminal-readable), postcard
  (styled correspondence pages via upload), webring (dev-friends webring) — no.
- His steer: bespoke-CLI vein is dry; "punch up a little" — go bigger.

## Batch 8 (punched up: month-scale systems) — relay is FIRE, rest meh

- **relay** — SELECTED, emphatically. Own push-notification infrastructure: one
  brutally minimal phone app (a notification surface) + Workers backend = *his*
  channel into his pocket. burner mail → buzz, hook fires → buzz,
  `anything | relay send`. ntfy-shaped but native to his fleet.
- crest (own OIDC/passkey identity provider, "Sign in with Noob"), archive
  (personal Wayback Machine on R2), bazaar (own package registry + storefront for
  his fleet, `noob install gate`), oracle (you-as-an-API at api.noobscience.in),
  atlas (one search box over corpus/repos/clipboard/uploads) — meh.

## Batch 9 (punched-up channels) — none landed

- live (terminal → real-time streaming URL), mailbox (permanent terminal inbox on
  Email Workers), portal ("nice, but I can just forward the serve port"), teleport
  (cross-device clipboard), print (thermal receipt printer as physical stdout) — no.
- Lesson: a channel that *duplicates* one he already has (gate, ssh -L, Universal
  Clipboard, vox) is dead on arrival. Novelty of the pipe matters, not just pipe-ness.

## Batch 10 (AI as a Unix primitive) — all rejected

- speak (local TTS pipe, teletalk's inverse), as (universal anything → schema'd
  JSON extractor), why (summonable system diagnostician), teach (Learnings-explainer
  generator → upload), fix (scrollback-aware command corrector) — no.
- Lesson: **probabilistic tools break trust** — "would be wrong half the time."
  A primitive must be deterministic; AI belongs in his tools only where wrongness
  is cheap and reviewable (commit messages, name suggestions), never in the pipe's
  contract. Also: steered to explore beyond CLI tools.

## Batch 11 (non-CLI forms) — all rejected

- typeface (fork Iosevka into his own coding font), dynamic wallpaper (Metal shader,
  live Hyderabad sky), Quick Look plugin (house-skin previews system-wide),
  cookbook (LiveView site from corpus recipes/), The Mailbox printed (bound zine) — no.

## Batch 12 (final wildcards) — AEGIS is a MASSIVE hit

- **aegis** — SELECTED, all-caps enthusiasm ("WOULD THAT EVEN BE POSSIBLE!?").
  0 A.D. replay analyzer: parse replay command stream, reconstruct the match
  timeline, visualize army-value curves and the exact moment the AI overcommits —
  the "post-commit vulnerability window" he discovered, made visible. A telescope
  for his own mastery of the game he actually plays.
- Elixir Minecraft server (process-per-player OTP madness) — "nah bro lol."
- Lesson: gaming-adjacent tooling for HIS existing play lands where building
  games never will. His joy + data + analysis = the sweet spot wildcards found.

## Aegis feasibility (researched, confirmed GREENFIELD)

- Replays at `~/Library/Application Support/0ad/replays/<version>/` —
  `commands.txt` (plaintext lockstep command stream: `turn N ms` + `cmd <player>
  <JSON>` lines) + `metadata.json` (end-of-game snapshot only).
- Commands only, no state on disk. State is recoverable: `pyrogenesis -replay=<path>`
  runs headless re-simulation ("for analysis purposes", documented); tap per-turn
  state via the AI scripting interface — `AIProxy` (position/owner/hitpoints/orders
  per entity) + `AIInterface` event stream (Attacked/Create/Destroy/TrainingFinished).
- Two-layer architecture: fast layer parses commands.txt directly (build orders,
  APM, attack-commitment = huge entity list + attack-walk toward base coords);
  deep layer = headless re-sim + spectator AI script → JSON snapshots → army-value
  / economy curves, post-commit vulnerability window as a shaded chart region.
- `hash` lines in the replay = built-in validation checksums for reconstruction.
- Caveat: replays are engine-version-locked; pin to installed build.
- Prior art: NONE. Community forum asked for exactly this, answer was "write it
  yourself." First-of-its-kind opportunity.

## Batch 13 (nvim/tmux plugins + full apps) — fossick, tapestry, embers selected

- **fossick.nvim** — SELECTED. Scrub a file through its git history like video,
  slider morphs the buffer commit-to-commit.
- **tapestry.tmux** — SELECTED. Mission Control for tmux: zoomable live minimap
  of all sessions/windows/panes with miniature pane contents.
- **embers.nvim** — SELECTED. Recently-edited lines glow and cool over minutes;
  working memory made visible. One autocmd + extmarks.
- margins.nvim (external marginalia w/ diff-anchoring), Observer-but-beautiful
  (LiveView BEAM visualizer), native SQLite studio (macOS app), — meh.
- Lesson: in editor-land, **ambient visual delight** wins; apps and functional
  systems lose. He wants the environment slightly alive, not more capable.

## Batch 14 (ambient-visual extrapolation of batch 13) — total flop

- patina.nvim (git-age sepia), tidemark.nvim (read-coverage marks), seasons.nvim
  (time-of-day palette drift), sonar.tmux (output pulse in periphery), stratum.nvim
  (nesting depth as elevation shading) — all no.
- META-LESSON (the big one): **extrapolation dies, jumps live.** Every
  batch built as "more of last batch's winners" flopped (3, 14); hits come from
  axis-jumps (relay, aegis, fossick). He's an exploration-maximizer — serve small,
  maximally-diverse batches; never mine the previous winner's neighborhood.
- Re-reading 13's winners: fossick/tapestry grant NEW POWERS (time-scrubbing,
  aerial view), not decoration. Passive tint = decoration = no.

## Batch 15 (three galaxies) — no verdicts given, presumed miss

- stowaway (dotfiles materialize on any remote box, evaporate on logout),
  twins.nvim (structural code-similarity search — his own "code smell search
  engine" idea as a plugin), scrimmage (overnight 0AD AI tournament harness).
- `capture` mystery: asked twice, still unanswered.

## Batch 16 (six galaxies, feasibility-blind) — no verdicts, presumed miss

- mirage (FUSE: APIs as files), ancestor (line genealogy through renames/refactors),
  doppler (behavioral diff between dependency versions), ley-lines (codebase as
  Beck-style metro map poster), smuggler (steganography as household tool),
  overworld (any file/repo as explorable procedural terrain).
- Steer after: "ideas like the pet" — ambitious-in-a-good-way, not ISP/Google scale.

## Batch 17 (living software / creatures) — HARD MISS, misread the steer

- village (desktop civilization), caravan (creature that migrates between devices,
  one place at a time), greenhouse (months-scale plant with genetics + giftable
  cutting files), genius loci (resident spirit on his website), angler (loading
  bars become fishing) — "I don't want to turn my laptop into a fucking zoo."
- Lesson: "like the pet" meant the QUALITIES (game-feel in real objects, craft,
  charm) — not more creatures. One pet is charm; five is a zoo.

## Batch 18 (game-feel, zero creatures) — all rejected

- The BEAM playable (OTP as explorable puzzle site), fantasy console ("build the
  console, not the game"), music box maker (punch-hole paper roll instrument),
  crypto workbench (drag-wire AES/PBKDF2 blocks, watch bytes flow),
  demoscene.noobscience.in (gallery of tiny generative cartridges) — nah.
- Steer after: lean into life management — people, dates, tasks.

## Batch 19 (life management, moni-DNA ledgers) — dates selected

- **dates** — SELECTED. One ledger for every date that matters: birthdays,
  renewals, expiries, warranties. `dates soon`, summoned never nagging.
- **folks** — SELECTED on second thought ("I don't mind it to be honest").
  Personal CRM ledger: `folks note ravi "..."`, `folks last`, `folks fading` —
  summoned, never notifying.
- docket (tasks-as-ledger), upkeep ("when did I last X"), paperwork
  (shh-for-documents) — no.
- Todo-genre is permanently dead, in his words: "I never go through with them.
  They sound good on paper, but are kinda useless." Consistent with his
  specifics-kill pattern — a todo list is a precise-commitment machine, and
  precise commitments have built-in moments to fail. Never propose task managers.
- Note: life MANAGEMENT is in (ledgers you summon); life INSTRUMENTATION stays
  banned (software that watches). noob_diet/moni-DNA: single binary, SQLite, --json.

## Batch 20 (life ledgers continued) — all remaining rejected

- capture (hotkey → thought → single inbox; theory that this was the empty repo's
  destiny — no bite), folio (investment ledger + XIRR), quorum (decision journal),
  pantry (kitchen inventory) — nah.

## Batch 21 (summoned facts / BEAM query / calendar) — hard NO, "done with CLIs"

- whence (download provenance from quarantine xattrs), beamql (SQL over a live
  BEAM node), agenda (EventKit calendar in terminal) — NOOO.
- Steer: CLI territory is CLOSED. Wants SaaS/tools/apps + proper deep nvim/tmux
  exploration. Called out lazy thinking — put real effort in.

## Batch 22 (deep nvim/tmux + products) — loupe & quarry selected

- **loupe.nvim** — SELECTED ("I love loupe"). Recursive inline call-graph peek:
  drill into callees in floating overlays without moving the cursor. LSP optics.
- **quarry.nvim** — SELECTED ("noice"). Quickfix lists as named, persistent,
  composable objects with set algebra (union/subtract/intersect saved lists).
- understudy.nvim (macros as editable buffers + replay preview), switchboard.tmux
  (patch-bay cables between panes), amber.tmux (workspace fossils with scrollback) — nah.
- exhibit (HTML-artifact hosting SaaS — "I already have upload"), viewport
  (JSON endpoint → home-screen widget app), capsule-as-consumer-product — nah.
- Lessons: nvim READING/navigation powers hit (fossick, embers, loupe, quarry,
  tapestry); DOING powers die (macros, plumbing, snapshots). tmux is mostly mined
  out (only tapestry ever hit). Product ideas keep dying when they overlap his
  fleet or smell like running a business.

## Batch 23 (reading powers II) — chamber & crossfire selected

- **chamber.nvim** — SELECTED. Two functions from anywhere, side-by-side aligned
  semantic diff — "are these twins?"
- **crossfire.nvim** — SELECTED. Every callsite of a symbol as a grid of live
  mini-windows at once, not a one-by-one list.
- tributary.nvim (value-flow highlighted as a river system), constellation.nvim
  (marks as a spatial sky map) — no.

## Batch 24 (reading powers III + apps-for-himself) — all rejected

- counterpoint.nvim (test↔impl as facing pages), itinerary.nvim (topo-sorted
  reading order for a branch diff), Lens (macOS hover-measure craft tool),
  Stacks (native library for his HTML artifacts — "literally just a browser
  folder lol") — nah.
- Reading-power vein now decaying too (3 hits then dry, the usual curve).

## Batch 25 — butler rejected ("too risky")

- butler (summoned file-tidying rules with plan-approve-execute) — no. Not meh:
  RISKY. Taste-law: tools that MOVE/DELETE his data are out, even with approval
  gates. Winners are read-only, append-only, or trivially reversible.

## Batch 26 (creative apps with soul) — Waypoint & One Plate selected

- **Waypoint** — SELECTED, with his twist: fog-of-war map of **MUMBAI** (not
  Hyderabad — he's Mumbai-based now, corpus is stale), streets reveal permanently
  as walked, PLUS pinnable wishlist places (cafes, spots to visit) waiting in the
  fog. Game-bleeding-into-life, on-device.
- **One Plate** — SELECTED ("kinda good"). One photo from your past per day, full
  screen, keep/toss/nothing. Daily memory ritual, accidental curation, no cloud.
- Antenna (shortwave dial for internet radio), Cellar (blind-mode coffee palate
  journal), Relic (Object Capture museum of his objects) — meh.
- Chord confirmed: **game mechanics applied to real life** (fog of war) and
  **gentle rituals over his own data** (One Plate) land. Apps-with-soul vein is ALIVE.

## Batch 27 (apps with soul II) — Galley selected, loudly

- **Galley** — SELECTED ("OH MY god"). Craft journal for his cooking — each
  invented dish gets a plate: photo, method, accumulating v2 tweaks; shuffle mode
  answers "what tonight" from his OWN repertoire. Not macros (noob_diet's job) —
  craft memory.
- Slow Camera (photos develop overnight, no preview), Skyline (AR city legend
  for Mumbai) — nah.
- Lesson: journals of what he MAKES land (Galley); journals of what he consumes
  die (Cellar/coffee). Creation > connoisseurship.

## Batch 28 — Firsts selected

- **Firsts** — SELECTED. A ledger that only accepts firsts — one dated line per
  threshold crossed, no streaks, no goals, write-only-after-the-fact so it can
  never guilt. The anti-todo autobiography.
- Monsoon (Mumbai rain verdict app), Mixtape (cassette-bodied playlist gifts) — meh.
- Social/gifting is now 0-for-everything tonight (guestbook, webring, postcard,
  invite, greenhouse-cuttings, mixtape). Genre formally dead. Utility-weather dead
  twice. Winning chord: retrospective rituals over his own life (One Plate,
  Firsts, Waypoint's fog).

## Batch 29 (life rituals III) — all no, LIFE DIRECTION CLOSED by decree

- Save State (deliberate snapshot ritual before life transitions), Heirloom
  (capture mom's recipes with her voice/phrasing), Sunday (one photo + one line
  weekly scrapbook) — no. "Stop in the life direction."

## Batch 30 — Iron selected (his request: workout logging)

- **Iron** — SELECTED ("noice"). Gym ledger for the zen workout: two-tap set
  logging pre-filled from last session; ledger-never-plan (no programs, no
  streaks — skips don't exist in the data model); one quiet feedback signal
  ("last: 15kg × 12"); progress on request only; body-weight monthly; sibling of
  noob_diet (calories in / work done / weight trend as one SQLite family).
  Design laws derived from his specifics-kill physics — the anti-optimization
  defenses ARE the product.

## Batch 31 (new axes after the six-plugin build) — rosetta & bloodhound selected

- **rosetta.nvim** — SELECTED ("rosetta is cool"). Decode gibberish under cursor:
  base64, JWT, URL-encoding, unix timestamps, hex, escaped JSON → float. His twist:
  explicit controls too, `:Rosetta base64 <text>` style, not just auto-detect.
- **bloodhound.nvim** — SELECTED ("too!!"). Clipboard stack trace → parsed frames →
  quickfix, auto-detecting Python/Elixir/JS/Go/Rust formats, alien path prefixes
  resolved. Composes with quarry.
- seance (deleted-code graveyard), cauldron (live-eval scratch buffer),
  reliquary (binary files rendered readable), darts (repo roulette) — no verdict.
- Build note: the six batch-13/22/23 plugins shipped as single-file modules in
  lua/custom/ (embers, quarry, fossick, loupe, crossfire, chamber), built by
  parallel agents in ~3 min, tested headless. fossick got "super cool" live +
  a github-permalink key (o); loupe got live use immediately (q pops one frame,
  Q collapses — his correction after going 3 layers deep).

## Proposed, not selected

- **cast** — markdown → house-skin self-contained HTML (`cast plan.md | upload`).
- **chess-by-URL** — correspondence games, entire game state in the URL fragment.
- **fridge** — kitchen photo → 3 cookable dishes + macros (Gemini pipeline).
  (Got an "okay okay" on first serve but didn't make the final cut.)
- **post** — send half of burner: `cat brief.html | post manager@ --subject ..`.
- **notif** — every macOS notification into SQLite; `notif search otp`, `notif watch |`.
- **menu** — restaurant-menu photo → what fits today's macros.

## The original five — APPROVED (he'd liked these from the start; "parked" meant yes)

- **capsule** — SELECTED. Timelock encryption via drand; messages that cannot be opened early.
- **sig** — SELECTED. Sign/verify anything against GitHub SSH keys (`ssh-keygen -Y`).
- **glass** — SELECTED. Screenshot region → OCR text on stdout (Vision framework).
- **trip** — SELECTED. Self-hosted canary tokens on Workers (fake AWS keys that phone home).
- **postmark** — SELECTED. File-existence proof via OpenTimestamps.

## Taste notes (what the swipes taught)

- Hits cluster on: **personal infrastructure primitives** (corporate SaaS →
  300 lines of yours: ngrok, temp-mail, webhook.site, Little Snitch, Authenticator)
  and **invisible streams made pipeable** (clipboard, notifications, network).
- Keeper formula: touched often + a mechanism worth an architecture.md + owned.
- Dead directions (do not revisit unprompted): tmux/nvim/agent-loop glue,
  life-instrumentation, replacing rented consumer moments (reels/Spotify/idle
  time), games-as-products, "which substrate to spelunk" framing.
