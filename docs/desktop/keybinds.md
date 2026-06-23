# Keybindings

> **Status — audited target architecture, doc-before-code.** This document
> specifies the keybind taxonomy agreed in the 2026-06-23 cross-platform
> keybind audit. It is the *design*, not the current live state: implementation
> lands atomically through the single-source capability registry (#384, Epic F
> #428; the dedicated registry ADR is **not yet written**), which generates every
> surface from one source. Until that cutover,
> live binds remain the pre-cutover all-four-`Hyper` shape — see
> [§Implementation status](#implementation-status).

**Terminology.** We say **`Super`** for the Cmd-position modifier throughout.
niri's KDL writes it `Mod`; that is the same key — an implementation detail, not
a taxonomy distinction.

**Keyboards.** Both machines (metis/Linux, mac-mini/macOS) use **Mac-layout
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
3. **Escalators.** `Hyper+Super` = the *elevated/heavy* tier (move,
   workspace-level ops, force-close). `Hyper+Shift` is otherwise reserved (it
   holds one deliberate exception, below).
4. **Mild duplication is allowed** when it rewards muscle memory (e.g. overview
   reachable two ways). Distinct from *transitional* duplication (migration
   scaffolding), which is retired at cutover.
5. **Escalator choice balances semantics and ergonomics** — number-moves use
   `Hyper+Super` (the `Super`/`Cmd` thumb) rather than `Hyper+Shift` (a left-hand
   pinky cramp).
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
  macOS approximates by number (Spaces) and by the broader view (Mission Control
  / exposé).

`Hyper` navigates the *immediate* level (columns, windows-in-column); `Hyper+Super`
operates the *elevated* level (workspaces, moves).

## The `Hyper` layer

### Navigation — focus

| Tier + key | niri | macOS |
|---|---|---|
| `Hyper+←/→` | focus column | focus window E/W → next space at edge |
| `Hyper+↑/↓` | focus window-in-column | focus window N/S |
| `Hyper+1‑9` | focus workspace N | switch to Space N |
| `Hyper+Tab` | overview | overview (Mission Control) |

> On macOS the arrow-focus binds are **Hammerspoon directional focus**
> (`focusWindowEast/West/North/South`), not a Karabiner remap — so Mac mirrors
> niri's spatial focus in 2-D. `Hyper+←/→` falls through to **move-space** only at
> the horizontal edge (no window further that way); `Hyper+↑/↓` fills the vertical
> axis that has no native macOS analogue.

### Move & workspace ops — the `Hyper+Super` elevated tier

| Tier + key | niri | macOS |
|---|---|---|
| `Hyper+Super+←/→` | move column | move window E/W → next space at edge |
| `Hyper+Super+1‑9` | move window → workspace N | move window → Space N |
| `Hyper+Super+↑/↓` | switch workspace | Mission Control / exposé |
| `Hyper+Super+W` | WM force-close window | — |
| `Hyper+Shift+↑/↓` | move window-in-column | move window N/S |

> **Deliberate deviation (audit note).** Move-window-in-column is the *one* move
> that lives on `Hyper+Shift`, not `Hyper+Super` — because `Hyper+Super+↑/↓` is
> claimed by switch-workspace (the spatial outer-vertical, which we chose to
> preserve). Every other move is on `Hyper+Super`. `Hyper+Super` is therefore a
> *tier* (elevated/heavy ops), not a single verb.
>
> On macOS the move binds are **Hammerspoon** (reposition/swap — Mac windows
> float); `Hyper+Super+←/→` falls through to **move-window-to-adjacent-space** at
> the edge, mirroring the focus binds. Cross-space window moves lean on
> Hammerspoon's Spaces handling — a known-fragile macOS area (see Open questions).

### Window geometry — `Hyper` + letter (niri-only)

| Tier + key | Action |
|---|---|
| `Hyper+−` / `Hyper+=` | shrink / grow column |
| `Hyper+R` | cycle preset width |
| `Hyper+C` | center column |
| `Hyper+F` | fullscreen window |
| `Hyper+M` | maximize column |

### Spawn & session

| Tier + key | niri | macOS |
|---|---|---|
| `Hyper+Return` | floating terminal window (floating foot) | floating terminal (Hammerspoon-managed floating/quake Ghostty) |
| `Hyper+B` | default browser | browser (focus-or-new) |
| `Hyper+Escape` | power / session menu (logout, lock, reboot, …) | power / session menu |
| `Hyper+Space` | action menu | action menu |

`Hyper+Space` is the action-menu door — part of the chooser family
([§Chooser family](#the-chooser-family)). Session quit/logout lives
inside the `Hyper+Escape` power menu (it subsumes the old `Super+Shift+E` quit).

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
  + Noctalia on Linux, Hammerspoon on macOS), *not* remaps.

### App commands — `Super+letter`

| Chord | Action | Realization |
|---|---|---|
| `Super+C / X / V` | copy / cut / paste | → `Ctrl+…` remap (Linux); native (Mac) |
| `Super+W` | close tab / window | → `Ctrl+W` remap (Linux); native (Mac) |
| `Super+Q` | quit application | **registry action** (SIGTERM, Linux); native (Mac) |
| `Super+A / S / F / T / N` | select-all / save / find / new-tab / new | reserved (same remap pattern) |

> `Super+letter` is a **mixed namespace**: most entries are app-command *remaps*
> (substrate/xremap); `Super+Q` is a *registry action* because Linux has no
> reliable `Ctrl+Q` quit convention. `Super+Q` is an approximation of macOS's
> app-lifecycle quit, not parity (Linux has no window-independent app concept).

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
- **Handlers** — Hammerspoon (macOS Lua — incl. directional window-focus *and
  move* for the `Hyper` arrow binds), niri actions, the action menu.
- **macOS floating terminal** (`Hyper+Return`) — a Hammerspoon-managed floating /
  always-on-top Ghostty window: the chosen analogue to niri's floating terminal
  (toggle-vs-spawn is the only open sub-question).
- **Generation** — every surface is emitted from the single-source registry
  (#384; Epic F #428); the new base shape lands **atomically** (never
  half-migrated).

## Implementation status

This document is the **audited target**. Current live binds are the
**pre-cutover all-four `Hyper`** (`Super+Ctrl+Alt+Shift`) shape in
`home/nixos/niri.nix`, `modules/nixos/keyd.nix`, `home/darwin/karabiner.nix`,
`home/darwin/hammerspoon.nix`, plus the macOS symbolic hotkeys in
`modules/darwin/keyboard-shortcuts.nix`. The cutover to the `Ctrl+Alt` base
happens in one step via the registry (#384; the registry ADR is planned, not yet
written).

## Open questions

- **macOS chooser engine** — native Spotlight vs unified `hs.chooser`.
- **`Hyper+Space` = action menu**, and whether to adopt the leader-key layer.
- **`Super+Tab` (app-switch) realization on niri** — likely a window/app chooser
  provider.
- **Text-nav realization** — xremap + zellij pass-through (target: GUI +
  terminal-shell + agentic CLIs; modal editors out).
- **xremap niri app-detection** — verification gating the `Super`-command + text-nav layers.
- **macOS floating-terminal realization** — Hammerspoon-managed floating/quake
  Ghostty (`Hyper+Return`); toggle (quake-style) vs spawn-new still open.
- **`Super+Return` (`Cmd+Return`) collision** — used for "submit/send" in some
  macOS apps; accept, or app-exclude via Karabiner.
- **macOS cross-space window moves** — `Hyper+Super+→` (edge fallthrough) and
  `Hyper+Super+1‑9` move windows *between* Spaces, which relies on Hammerspoon's
  Spaces handling — a known-fragile macOS area (private APIs). Realization risk to
  verify.

## Audit notes — deliberate calls & deviations

- Move-window-in-column on `Hyper+Shift+↑/↓` is the one move outside `Hyper+Super`
  (preserves spatial workspace nav).
- Mild duplication is deliberate (overview via `Hyper+Tab` and macOS Mission
  Control via `Hyper+Super+↑`).
- macOS Space ≈ niri **column** (spatial cognition), not the structural
  workspace reading — refined by the focus/move-mirror: Mac *windows* are the fine
  horizontal unit (≈ columns), Spaces the coarse fallthrough.
- `Super` (not `Mod`) is our term; niri writes `Mod`.
- App-access sits on `Super` only for *non-letter* keys (`Return` / `Space` /
  `Tab`); app-access needing a letter (browser = `Hyper+B`) stays on `Hyper`,
  since `Super+letter` is the app-command space (e.g. `Super+B` = bold).
