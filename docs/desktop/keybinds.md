# Keybindings

> **Status — audited target architecture, doc-before-code.** This document
> specifies the keybind taxonomy agreed in the 2026-06-23 cross-platform
> keybind audit. It lands in phases through the single-source capability
> registry (`lib/capabilities.nix`; [ADR-039](../decisions/ADR-039-capability-registry.md),
> #384, Epic F #428), which generates every surface from one source. The Linux
> Hyper layer (niri + keyd) has cut over to the `Ctrl+Alt` base. macOS now runs
> **AeroSpace** as its window manager ([ADR-040](../decisions/ADR-040-macos-window-manager-aerospace.md),
> #494, superseding ADR-039 §7): the Hyper binds are realized by the
> `aerospace-action` emitter, and Hammerspoon is retired — see
> [§Implementation status](#implementation-status).

**Terminology.** We say **`Super`** for the Cmd-position modifier throughout.
niri's KDL writes it `Mod`; that is the same key — an implementation detail, not
a taxonomy distinction.

**Keyboards.** Both machines (metis/Linux, neptune/macOS) use **Mac-layout
keyboards**. The physical `Cmd`-position key therefore emits `Super` on Linux and
`Cmd` on macOS, and the `Option`-position key emits `Alt`/`Opt` — which is why
`Super` (the Cmd-position key) is the natural home for macOS-convention commands
on both platforms.

**Markdown.** Soft-wrapped (one line per paragraph).

## The organizing principle

Two modifier families carry the design, chosen by *what an action is*:

- **`Hyper`** — the **primary command layer**: window/space navigation, window
  geometry, app-spawn, session, the action menu. Produced from **Caps Lock**.
  `Hyper` = `Ctrl+Alt` (Linux) / `Ctrl+Opt` (macOS) — a minimal two-modifier
  base that frees `Shift` and `Super`/`Cmd` as escalators.
- **`Super`** (the Cmd-position key) — the **macOS-convention command
  modifier**: app commands (copy/paste/close/quit), text navigation, app-switch,
  the launcher. Kept deliberately *clear* so it can mirror `Cmd` on both
  platforms.

Principles:

1. **Parity, not identity.** The objective is the same *UX* on both platforms
   (one physical chord, the same action-analogue), not an identical modifier set.
   Each platform uses its best-fit chord (Linux `Hyper` = `Ctrl+Alt`; macOS
   `Hyper` = `Ctrl+Opt`).
2. **`Hyper` is the primary layer, not "cross-platform-only."** Cross-platform
   parity is achieved per-bind; niri-only actions (geometry, vertical window nav)
   live on `Hyper` too. A **divergent leaf** — an action present on one platform
   only — is correct, not a gap.
3. **Escalators.** `Hyper+Shift` = *move* — on-screen moves (move column, move
   window-in-column) *and* send-window-to-workspace; `Hyper+Super` = *switch
   workspace*. "Shift moves, Super switches." This aligns with the dominant
   i3/sway convention (`$mod+Shift+N` sends a window to workspace N).
4. **Mild duplication is allowed** when it rewards muscle memory (e.g. overview
   reachable two ways). Distinct from *transitional* duplication (migration
   scaffolding), which is retired at cutover.
5. **Escalator choice favours the mnemonic.** Number-moves (send-to-workspace)
   sit on `Hyper+Shift+1‑9`, so "Shift = move" holds across both arrows and
   numbers, matching i3/sway. The mild `Shift+number` reach is accepted for a
   low-frequency action — a deliberate reversal of an earlier draft that put
   number-moves on `Hyper+Super` to spare the pinky.
6. **Name by tier, not literal chord.** Binds are expressed as `tier + key` (the
   base16 "name by slot, not tone" discipline), resolved per-platform from one
   `Hyper` definition — so the base shape is a single edit.
7. **Substrate boundary.** Caps→`Hyper` *production* stays hand-authored
   substrate (keyd / Karabiner); the registry binds chord→action only. `Hyper`
   is a single-sourced constant both consume.

## The spatial model

niri's spatial structure is the organizing frame — it is the richer of the two
window models, so the taxonomy is built on it and macOS follows:

- **Columns** — the horizontal scroll-strip within a workspace. **Spatially
  equivalent to macOS Spaces** (both a horizontal strip you slide along) — a
  deliberate *spatial-cognition* choice over the structural "Space ≈ workspace"
  reading. **Refined** by the macOS focus/move-mirror (below): Mac *windows* are
  the fine horizontal unit (≈ columns), and Spaces the coarse step at the edge.
- **Windows-in-column** — the vertical stack within a column (inner vertical). No
  macOS analogue.
- **Workspaces** — the vertical stack of workspaces (outer vertical), numbered.
  On macOS these are **AeroSpace workspaces** (`Hyper+1‑9`), tiler-owned rather
  than native Spaces (ADR-040).

`Hyper` navigates the *immediate* level (columns, windows-in-column); `Hyper+Shift`
*moves* (column, window-in-column, and send-to-workspace `1‑9`); `Hyper+Super`
*switches* workspace (`↑/↓`).

## The `Hyper` layer

The bind inventory below is **generated from the capability registry**
(`lib/capabilities.nix`) — do not hand-edit; run `just gen-keybinds` (the
[ADR-037](../decisions/ADR-037-doc-mutability-contracts.md) generated-facts
contract; #457). Chords are the friendly tier form; the per-platform cells are
the short action label (`—` where a platform doesn't realize the bind). The
behavioural nuance the one-line cells can't carry — the macOS edge-scroll
fallthrough, the geometry keys reused for app-launch — lives in the notes that
follow.

<!-- BEGIN GENERATED: hyper-bindings — source lib/capabilities.nix; run `just gen-keybinds` -->
| Chord | niri | macOS |
|---|---|---|
| `Hyper+←` | Focus column left | Focus window left |
| `Hyper+→` | Focus column right | Focus window right |
| `Hyper+↑` | Focus window up | Focus window up |
| `Hyper+↓` | Focus window down | Focus window down |
| `Hyper+Tab` | Overview | Last workspace |
| `Hyper+−` | Shrink column width | — |
| `Hyper+=` | Grow column width | — |
| `Hyper+R` | Cycle column width | — |
| `Hyper+C` | Center column | — |
| `Hyper+F` | Fullscreen window | — |
| `Hyper+M` | Maximize column | — |
| `Hyper+Return` | Open terminal | Open terminal |
| `Hyper+B` | Open browser | Open browser |
| `Hyper+Shift+←` | Move column left | Move window left |
| `Hyper+Shift+→` | Move column right | Move window right |
| `Hyper+Shift+↑` | Move window up | Move window up |
| `Hyper+Shift+↓` | Move window down | Move window down |
| `Hyper+Super+↑` | Switch workspace up | — |
| `Hyper+Super+↓` | Switch workspace down | — |
| `Hyper+1‑9` | Focus workspace N | Switch to workspace N |
| `Hyper+Shift+1‑9` | Move window to workspace N | Move window to workspace N |
| `Hyper+F` | — | Open Finder |
| `Hyper+M` | — | Open Messages |
| `Hyper+E` | — | Open Outlook |
| `Hyper+S` | — | Open Slack |
| `Hyper+/` | — | Open 1Password |
| `Hyper+,` | — | Toggle tiles/accordion |
| `Hyper+Shift+;` | — | Service mode |
| `Hyper+Shift+M` | — | Maximise (isolate) |
<!-- END GENERATED: hyper-bindings -->

**Not in the registry (reserved, no realization yet).** `Hyper+Escape` → power /
session menu (logout, lock, reboot, …); `Hyper+Space` → action menu. These have
no chord→action realization to generate from, so they stay hand-listed here.
`Hyper+Space` is the action-menu door — part of the chooser family
([§Chooser family](#the-chooser-family)); session quit/logout lives inside the
`Hyper+Escape` power menu (it subsumes the old `Super+Shift+E` quit).

### Focus & navigation

> On macOS these are **AeroSpace** binds (ADR-040). `Hyper+↑/↓` = `focus up/down`
> — vertical focus within a tiling stack (the niri within-column analogue; niche
> under AeroSpace's flat i3 tiling until you nest windows). `Hyper+←/→` carry a
> darwin-specific **edge-scroll fallthrough**: `focus left/right`, but at the
> workspace edge they wrap to the adjacent workspace (`--wrap-around`) and land on
> the far column — *not* a faithful `focus-column` mirror, a deliberate
> reconstruction of continuous scroll at *workspace* granularity (the design note's
> no-scrollable-columns limitation). The Karabiner Mission-Control remaps that
> once occupied these chords are retired.

### Move (`Hyper+Shift`) & switch-workspace (`Hyper+Super`)

> **Shift moves, Super switches.** `Hyper+Shift` is the universal **move** tier —
> on-screen moves (column `←/→`, window-in-column `↑/↓`) *and* send-window-to-
> workspace (`1‑9`); `Hyper+Super` is the **switch-workspace** tier (`↑/↓`). This
> puts send-to-workspace on `Hyper+Shift+1‑9`, matching the dominant i3/sway
> convention (`$mod+Shift+N` sends a window to workspace N) and keeping "Shift =
> move" true across both arrows and numbers. `Hyper+Super+←/→` and
> `Hyper+Super+1‑9` are deliberately free.
>
> **No WM force-close (audit correction).** An earlier draft put a `Hyper+Super+W`
> "force-close window" on this tier; niri has no force-close — only graceful
> `close-window` — so there is no such powerup. Window-close lives on `Super+W`
> (see [§App commands](#app-commands--superletter)).
>
> On macOS the move binds are **AeroSpace** `move left/right/up/down` (reorder the
> focused window within the workspace tree). `Hyper+Super+←/→/↑/↓` (switch-workspace)
> is **darwin-N/A** — under AeroSpace, workspace switching is `Hyper+1‑9`, the
> `Hyper+←/→` edge-scroll, and `Hyper+Tab`; there is no Mission Control to open
> (ADR-040).

### Window geometry

> macOS geometry is **darwin-N/A** under AeroSpace (ADR-040): the tiler auto-tiles,
> so the per-window geometry cluster (resize `−/=`, preset-width `R`, center `C`)
> is dropped. `F` and `M` are **reused** on macOS for app-launch (Finder,
> Messages); the focus-stable "maximize" is **maximise-by-isolation**
> (`Hyper+Shift+M` — move the window to its own empty workspace, since AeroSpace's
> `fullscreen` drops on focus-change). The niri geometry capability IDs stay for
> the Linux side. History: [macos-window-management.md](./macos-window-management.md).

### Spawn & session

> `Hyper+Return` opens a terminal (floating foot on niri; on macOS an
> `exec-and-forget open -na Ghostty.app` — always a *new* window, a new app
> instance per window); `Hyper+B` opens the browser (default browser on niri;
> `open -a "Google Chrome"` focus-or-launch on macOS). macOS also adds app-launch
> on `Hyper+F/M/E/S//` (Finder/Messages/Outlook/Slack/1Password) — all
> `aerospace-action` binds (ADR-040).

## The `Super` layer — the Cmd-position modifier

`Super` is the Cmd-position key — macOS's application-interaction modifier. It
carries two kinds of bind:

- **App commands** (copy/paste/close/quit, text navigation) — native `Cmd`
  behaviours on macOS; on Linux realized by an **app-aware remapper** (xremap)
  translating `Super+key` → the app's native command, with a **terminal
  carve-out** (the `Super+letter` *remaps* are excluded in the terminal —
  `Ctrl+key` there means SIGINT / delete-word / flow-control; the terminal
  handles its own analogues, or doesn't).
- **App access** (launcher, terminal, app-switch) — custom spawns/handlers (niri
  + Noctalia on Linux, AeroSpace `exec-and-forget` on macOS), *not* remaps.

### App commands — `Super+letter`

| Chord | Action | Realization |
|---|---|---|
| `Super+C / X / V` | copy / cut / paste | → `Ctrl+…` remap (Linux); native (Mac) |
| `Super+W` | close window | niri `close-window` (Linux); native `Cmd+W` (Mac) |
| `Super+Q` | quit application | **registry action** (SIGTERM, Linux); native (Mac) |
| `Super+A / S / F / T / N` | select-all / save / find / new-tab / new | reserved (same remap pattern) |

> `Super+letter` is a **mixed namespace**: most entries are app-command *remaps*
> (substrate/xremap), but two are not. `Super+Q` (quit) is a *registry action*
> because Linux has no reliable `Ctrl+Q` quit convention. `Super+W` (close) is the
> niri `close-window` WM action — niri has no force-close, and an app-level
> `Ctrl+W` tab-close remap is deferred to #323. `Super+Q` is an approximation of
> macOS's app-lifecycle quit, not parity (Linux has no window-independent app
> concept).

### Text navigation — claimed, realization deferred

| Chord | Action |
|---|---|
| `Super+←/→` | line start / end |
| `Super+↑/↓` | document start / end |
| `Alt/Opt+←/→` | word left / right |
| `Super`/`Opt` + Backspace | delete to line start / delete word |
| `Shift +` any of the above | extend selection |

> **Reserved** for macOS-convention text nav across GUI + terminal-shell +
> agentic-CLI input (Claude Code, Cursor CLI inside zellij). **Modal editors
> (helix) are out of scope.** The *how* (xremap + zellij pass-through; likely
> remap to readline motions) is a separate investigation — here we only claim the
> chords so nothing else takes them.

### App access

| Chord | Action |
|---|---|
| `Super+Return` | terminal (new window) |
| `Super+Tab` | app switcher (`Cmd+Tab` parity) — **reserved on niri**, realization pending |
| `Super+Space` | launcher (`Cmd+Space` parity) |

> **All `<mod>+Space` chords are reserved** for spotlight-style chooser surfaces
> ([§Chooser family](#the-chooser-family)). `Super+Tab` is likely
> realized as a chooser provider (window/app switcher), since niri has no native
> app-switcher.

## Screenshots — native-parity, outside `Hyper`

Mirrors macOS's native screenshot chords on the `Super` (Cmd-parity) modifier,
**swapped** so bare = clipboard, `+Ctrl` = file:

| Chord | Action |
|---|---|
| `Super+Shift+3 / 4 / 5` | screen / region / window → clipboard |
| `Super+Ctrl+Shift+3 / 4 / 5` | screen / region / window → file |
| `Print` / `Ctrl+Print` / `Alt+Print` | region / screen / window → disk+clipboard (hardware keys) |

## Hardware & media keys

`XF86Audio*` (volume), `XF86MonBrightness*` (brightness) — their own namespace,
unbound pending tooling. The `Print` family is bound to screenshots (above).

## Inherited reservations — not ours, always live

| Chord | Action | Note |
|---|---|---|
| `Ctrl+Alt+F1‑F12` | VT switch (niri, **unbindable**) | **The `Ctrl+Alt` base must never bind the F-row** — the one hard collision the cutover introduces. |
| `XF86PowerOff` | suspend | disableable via niri config |
| macOS MC defaults (IDs 79/81/32/33) | move-space / overview / exposé | the targets of the Karabiner `Hyper+arrow` remaps — must stay enabled |

## The chooser family

*Forward — under design.*

A single fuzzy-popup primitive with swappable **providers**: apps, actions,
window/app-switch, emoji, clipboard, settings, keybind-cheatsheet, calculator.
Triggers:

- `Super+Space` — primary universal launcher (apps + search + prefixes).
- `Hyper+Space` — action / command palette (#437).
- Prefixes within the launcher (`>emoji`, `>clip`, …) — the long tail.
- *(optional, deferred)* a leader key (Right Cmd) for fast modal access.

Engine: Noctalia's launcher (Linux) + `hs.chooser` (macOS); the action provider
reads the registry-generated `actions.json` (#437; renderer per #406, fuzzel
excluded). The keybind-cheatsheet provider renders **from the registry** — the
single-source tie-in. **Open:** macOS engine — native Spotlight (cheap, not
extensible) vs unified `hs.chooser` (full family, more work). See
[§Open questions](#open-questions).

## Realization & substrate (forward)

- **`Hyper` production** — keyd (Linux) / Karabiner (macOS), hand-authored
  substrate; `Hyper` is a single-sourced constant both substrate and emitters
  consume.
- **`Super`-command remaps + text nav** — xremap (app-aware, terminal-excluded);
  **pending verification** of niri app-detection.
- **Handlers** — niri actions (Linux); **AeroSpace** `aerospace-action` binds
  (macOS — focus/move/workspace/app-launch, emitted verbatim; the edge-scroll +
  maximise-by-isolation binds hand-authored as `aerospace-exec`); the action menu.
- **macOS terminal** (`Hyper+Return`) — `exec-and-forget open -na Ghostty.app`
  (AeroSpace then tiles the new window); a new app instance per window, paired
  with `quit-after-last-window-closed = true` in `ghostty.nix`.
- **Generation** — every surface is emitted from the single-source registry
  (#384; Epic F #428); the new base shape lands **atomically** (never
  half-migrated).

## Implementation status

This document is the **audited target**, landing in phases through the
single-source capability registry (`lib/capabilities.nix`; ADR-039, #384). The
**Linux Hyper layer cut over** to the `Ctrl+Alt` base: `home/nixos/niri.nix`
(binds generated by the registry) and `modules/nixos/keyd.nix` (the Caps→Hyper
substrate reading the same constant).

The **macOS Hyper layer runs on AeroSpace** (ADR-040, #494, superseding ADR-039
§7): `home/darwin/karabiner.nix` (Caps→`Ctrl+Opt`, reading the same
`tiers.hyper.darwin` constant; the Mission-Control/Space-jump remaps retired —
`karabinerHyperRemapKeys` emptied) and `home/darwin/aerospace.nix` (the full
Hyper keymap — focus/move/workspace/app-launch via the `aerospace-action`
emitter, plus the hand-authored edge-scroll + maximise-by-isolation
`aerospace-exec` binds). `modules/darwin/keyboard-shortcuts.nix` carries **no
`Hyper` base** — it owns only the screenshot chord swap. The native `Ctrl+1‑9`
"Switch to Desktop N" targets it used to declare were removed once AeroSpace
landed: the Karabiner `Hyper+N → Ctrl+N` remap that drove them is retired, and
AeroSpace owns workspaces on a single native Space, so they were inert.

The focus/move binds are **shipped** (no longer a deferred mirror): `Hyper+↑/↓`
= AeroSpace `focus up/down`, `Hyper+←/→` = focus with edge-scroll fallthrough,
`Hyper+Shift+arrows` = `move`. Bind *inventory* grows incrementally on the
registry; the base *shape* is atomic per platform.

## Open questions

- **macOS chooser engine** — native Spotlight vs unified `hs.chooser`.
- **`Hyper+Space` = action menu**, and whether to adopt the leader-key layer.
- **`Super+Tab` (app-switch) realization on niri** — likely a window/app chooser
  provider.
- **Text-nav realization** — xremap + zellij pass-through (target: GUI +
  terminal-shell + agentic CLIs; modal editors out).
- **xremap niri app-detection** — verification gating the `Super`-command + text-nav layers.
- **`Super+Return` (`Cmd+Return`) collision** — used for "submit/send" in some
  macOS apps; accept, or app-exclude via Karabiner.
- **macOS Chrome cross-workspace focus** — `Hyper+B` (`open -a "Google Chrome"`)
  when a Chrome window is parked on another AeroSpace workspace: verify AeroSpace
  *follows* to that workspace rather than leaving focus split (on-box check).

## Audit notes — deliberate calls & deviations

- All moves live on `Hyper+Shift` — column `←/→`, window-in-column `↑/↓`, and
  send-to-workspace `1‑9`; `Hyper+Super` is the switch-workspace tier (`↑/↓`).
  "Shift moves, Super switches" — matching i3/sway's `$mod+Shift+N`. This
  reverses an earlier draft that kept number-moves on `Hyper+Super`.
- niri has no WM force-close (only graceful `close-window`), so there is no
  `Hyper+Super+W` powerup; window-close is `Super+W`.
- Mild duplication is deliberate (overview via `Hyper+Tab` and macOS Mission
  Control via `Hyper+Super+↑`).
- macOS Space ≈ niri **column** (spatial cognition), not the structural
  workspace reading — refined by the focus/move-mirror: Mac *windows* are the fine
  horizontal unit (≈ columns), Spaces the coarse fallthrough.
- `Super` (not `Mod`) is our term; niri writes `Mod`.
- App-access sits on `Super` only for *non-letter* keys (`Return` / `Space` /
  `Tab`); app-access needing a letter (browser = `Hyper+B`) stays on `Hyper`,
  since `Super+letter` is the app-command space (e.g. `Super+B` = bold).
