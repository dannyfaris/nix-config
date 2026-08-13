# Keybindings

> **Status — audited target architecture, doc-before-code.** This document
> specifies the keybind taxonomy agreed in the 2026-06-23 cross-platform
> keybind audit. It lands in phases through the single-source capability
> registry (`lib/capabilities.nix`; [ADR-039](../decisions/ADR-039-capability-registry.md),
> #384, Epic F #428), which generates every surface from one source. The Linux
> Hyper layer (niri + keyd) has cut over to the `Ctrl+Alt` base. macOS now runs
> **yabai + skhd** as its window manager ([ADR-047](../decisions/ADR-047-macos-window-manager-yabai.md),
> superseding [ADR-040](../decisions/ADR-040-macos-window-manager-aerospace.md)): the Hyper binds are realized by
> hand-authored `skhd-exec` bodies (skhd has no verb emitter), and Hammerspoon
> remains retired — see [§Implementation status](#implementation-status).

**Terminology.** We say **`Super`** for the Cmd-position modifier throughout.
niri's KDL writes it `Mod`; that is the same key — an implementation detail, not
a taxonomy distinction.

**Keyboards.** The operator's external keyboards and the Mac are
**Mac-layout**. The physical `Cmd`-position key therefore emits `Super` on Linux and
`Cmd` on macOS, and the `Option`-position key emits `Alt`/`Opt` — which is why
`Super` (the Cmd-position key) is the natural home for macOS-convention commands
on both platforms.

**Markdown.** Soft-wrapped (one line per paragraph) — formatter-enforced once dprint is wired (#435 PR B; [ADR-046](../decisions/ADR-046-markdown-formatter.md)).

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
3. **Escalators.** `Hyper+Shift` = *act on the window* — on-screen moves (move
   column, move window-in-column), send-window-to-workspace, *and* window
   geometry (resize, preset-width, center, fullscreen, maximize — migrated from
   base `Hyper` in #762), plus the floating toggle (`Space`, the i3/sway
   convention); `Hyper+Super` = *switch workspace*. "Shift acts on
   the window, Super switches." Bare `Hyper` is left to navigate, switch, and
   launch. Still aligned with the dominant i3/sway convention (`$mod+Shift+N`
   sends a window to workspace N).
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
  On macOS these are **native Mission Control Desktops** (`Hyper+1‑9`
  synthesizes macOS's own "Switch to Desktop N" shortcuts), reversing ADR-040's
  tiler-owned single-native-Space model (ADR-047).

`Hyper` navigates the *immediate* level (columns, windows-in-column) — on niri, `Hyper+↑/↓` additionally falls through to the workspace above/below once it runs out of column to traverse, so the outer level stays one chord away without a modifier; `Hyper+Shift` *acts on the window* — moves (column, window-in-column, send-to-workspace `1‑9`) and geometry; `Hyper+Super` *switches* workspace (`↑/↓`) unconditionally regardless of position in the column, which is why both binds survive alongside the fallthrough.

## The `Hyper` layer

The bind inventory below is **generated from the capability registry**
(`lib/capabilities.nix`) — do not hand-edit; run `just gen-keybinds` (the
[ADR-037](../decisions/ADR-037-doc-mutability-contracts.md) generated-facts
contract; #457). Chords are the friendly tier form; the per-platform cells are
the short action label (`—` where a platform doesn't realize the bind). The
behavioural nuance the one-line cells can't carry — the macOS edge-scroll
fallthrough, the geometry cluster's `Hyper+Shift` home — lives in the notes that
follow.

<!-- BEGIN GENERATED: hyper-bindings — source lib/capabilities.nix; run `just gen-keybinds` -->
| Chord | niri | macOS |
|---|---|---|
| `Hyper+←` | Focus column left | Focus window left |
| `Hyper+→` | Focus column right | Focus window right |
| `Hyper+↑` | Focus window or workspace up | Focus window up |
| `Hyper+↓` | Focus window or workspace down | Focus window down |
| `Hyper+Tab` | Overview | Last workspace |
| `Hyper+Shift+−` | Shrink column width | — |
| `Hyper+Shift+=` | Grow column width | — |
| `Hyper+Shift+R` | Cycle column width | — |
| `Hyper+Shift+C` | Center column | — |
| `Hyper+Shift+F` | Fullscreen window | — |
| `Hyper+Shift+M` | Maximize column | — |
| `Hyper+Shift+Space` | Toggle floating | Toggle floating |
| `Hyper+Return` | Open terminal | Open terminal |
| `Hyper+B` | Focus or open browser | Focus or open browser |
| `Hyper+F` | Open file manager | Open Finder |
| `Hyper+C` | Focus or open Claude | — |
| `Hyper+/` | Open 1Password | Open 1Password |
| `Hyper+Shift+←` | Move column left | Move window left |
| `Hyper+Shift+→` | Move column right | Move window right |
| `Hyper+Shift+↑` | Move window up | Move window up |
| `Hyper+Shift+↓` | Move window down | Move window down |
| `Hyper+Super+↑` | Switch workspace up | — |
| `Hyper+Super+↓` | Switch workspace down | — |
| `Hyper+1‑9` | Focus workspace N | Switch to Desktop N |
| `Hyper+Shift+1‑9` | Move window to workspace N | Move window to workspace N |
| `Hyper+M` | — | Open Messages |
| `Hyper+E` | — | Open Outlook |
| `Hyper+S` | — | Open Slack |
| `Hyper+,` | — | Toggle bsp/stack layout |
| `Hyper+Shift+;` | — | Service mode |
| `Hyper+Shift+M` | — | Maximise |
| `Hyper+Shift+Return` | — | Cycle terminal windows |
<!-- END GENERATED: hyper-bindings -->

**Not in the registry (reserved, no realization yet).** `Hyper+Escape` → power /
session menu (logout, lock, reboot, …); `Hyper+Space` → action menu. These have
no chord→action realization to generate from, so they stay hand-listed here.
`Hyper+Space` is the action-menu door — part of the chooser family
([§Chooser family](#the-chooser-family)); session quit/logout lives inside the
`Hyper+Escape` power menu (it subsumes the old `Super+Shift+E` quit).

### Focus & navigation

> Both platforms carry an edge fallthrough, on different axes and with different edge behaviour. On niri, `Hyper+↑/↓` moves focus within the column (window-in-column) — or, when a floating window holds focus, to the nearest floating window in that direction, since niri's directional focus dispatches through whichever layer is active — and, once there is nothing further that way, falls through to the workspace above/below. This **clamps** at the first/last workspace, it does not wrap. Note the floating consequence: a lone floating window (the `open-floating` utility-palette rule) has nothing above or below it, so `Hyper+↑/↓` switches workspace and leaves it behind — where the old non-fallthrough bind was simply inert. On macOS these are **yabai** binds via skhd (ADR-047): `Hyper+↑/↓` = `window --focus north/south` — vertical focus within the BSP tree, with no workspace fallthrough. `Hyper+←/→` carry a darwin-specific **edge-scroll fallthrough**: `window --focus west/east`, but at the space edge they fall through to a synthesized native shortcut instead of a yabai command — the plain step synthesizes macOS's own Move-a-space (`Ctrl+←/→`), and the wrap (last Desktop back to first) synthesizes a numbered Switch-to-Desktop, because Move-a-space does not wrap. This is a deliberate inconsistency (ADR-047 §Decision): within-space focus rides yabai's instant SIP-free cut, while the edge-of-space step/wrap ride the slower native Mission Control slide. The Karabiner Mission-Control remaps that once occupied these chords remain retired.

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
> On macOS the move binds are **yabai** `window --swap north/south/west/east`
> (swap the focused window with its BSP-tree neighbour). `Hyper+Super+←/→/↑/↓`
> (switch-workspace) is **darwin-N/A** — workspace switching is `Hyper+1‑9`
> (synthesized native Switch-to-Desktop), the `Hyper+←/→` edge-scroll, and
> `Hyper+Tab` (`space --focus recent`, yabai's SIP-free gesture path); native
> Mission Control itself is back as the Desktop switcher, reversing ADR-040's
> single-native-Space model (ADR-047).

### Window geometry

> The geometry cluster lives on `Hyper+Shift` (migrated from base `Hyper` in
> #762 — "Shift acts on the window"). macOS geometry is **darwin-N/A** under
> yabai's auto-balanced BSP layout (ADR-047): the tiler auto-tiles, so the
> per-window geometry cluster (resize `−/=`, preset-width `R`, center `C`) is
> dropped there. Bare `Hyper+M` is reused on macOS for app-launch (Messages);
> the focus-stable "maximize" (`Hyper+Shift+M`) is a stable, reversible
> `window --toggle zoom-fullscreen` — replacing AeroSpace's one-way
> maximise-by-isolation workaround and answering #491/#492 (ADR-047
> §Rationale; shares its chord with niri's Maximize column as the
> action-analogue). The niri geometry capability IDs stay for the Linux side.
> History: [macos-window-management.md](./macos-window-management.md).

### Spawn & session

> `Hyper+Return` opens a terminal (floating foot on niri; on macOS `open -na Ghostty.app` — always a *new* window, a new app instance per window); `Hyper+B` focus-or-opens the browser (niri: focus the existing Firefox window via `niri-focus-or-spawn`, else `xdg-open` the default browser; `open -a "Google Chrome"` focus-or-launch on macOS); `Hyper+F` opens the file surface — one capability, exact chord parity: Nautilus on niri, focus-or-launch Finder on macOS (see docs/desktop/file-manager.md); `Hyper+C` focus-or-opens Claude Desktop (niri only, on the hosts that carry it — the app is single-instance, so a plain re-spawn raises and focuses the existing window; #683); `Hyper+/` focus-or-opens 1Password (niri: focus the existing window via `niri-focus-or-spawn`, app-id pinned from a live probe, else spawn the tray app — single-instance, so the spawn raises the existing window if one is open; `open -a 1Password` focus-or-launch on macOS). macOS also adds app-launch on `Hyper+M/E/S` (Messages/Outlook/Slack) — all hand-authored `skhd-exec` bodies (ADR-047).

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
  + Noctalia on Linux, hand-authored `skhd-exec` bodies on macOS), *not* remaps.

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

> **Bare `<mod>+Space` chords are reserved** for spotlight-style chooser surfaces
> ([§Chooser family](#the-chooser-family)) — escalated forms are exempt
> (`Hyper+Shift+Space` is the floating toggle, an act-on-the-window bind).
> `Super+Tab` is likely realized as a chooser provider (window/app switcher),
> since niri has no native app-switcher.

## Screenshots — native-parity, outside `Hyper`

Mirrors macOS's native screenshot chords on the `Super` (Cmd-parity) modifier,
**swapped** so bare = clipboard, `+Ctrl` = file:

| Chord | Action |
|---|---|
| `Super+Shift+3 / 4 / 5` | screen / region / window → clipboard |
| `Super+Ctrl+Shift+3 / 4 / 5` | screen / region / window → file |
| `Print` / `Ctrl+Print` / `Alt+Print` | region / screen / window → disk+clipboard (hardware keys) |

## Hardware & media keys

`XF86Audio*` (volume/media), `XF86MonBrightness*` (brightness) — their own namespace, bound in niri to Noctalia's IPC verbs. Why `noctalia msg` over `wpctl`/`playerctl`, and the `allow-when-locked` and keyboard-backlight scope calls: docs/desktop/audio.md.

| Key | Target |
|---|---|
| `XF86AudioRaiseVolume` | `noctalia msg volume-up` (allow-when-locked) |
| `XF86AudioLowerVolume` | `noctalia msg volume-down` (allow-when-locked) |
| `XF86AudioMute` | `noctalia msg volume-mute` (allow-when-locked) |
| `XF86AudioMicMute` | `noctalia msg mic-mute` |
| `XF86AudioPlay` | `noctalia msg media toggle` |
| `XF86AudioNext` | `noctalia msg media next` |
| `XF86AudioPrev` | `noctalia msg media previous` |
| `XF86MonBrightnessUp` | `noctalia msg brightness-up` |
| `XF86MonBrightnessDown` | `noctalia msg brightness-down` |
| `XF86PowerOff` | `noctalia-lock-and-blank` — session lock + `dpms-off` (`repeat = false`) |

The `Print` family is bound to screenshots (above).

**`XF86PowerOff` locks the session and blanks the displays (#651), on niri hosts only.** niri hard-binds this key to `Suspend`; `input.power-key-handling.enable = false` — set fleet-wide in `home/nixos/niri.nix` — turns that hardcoded bind off, so the key falls through to this configured bind instead. `repeat = false` so a held key doesn't spam the lock IPC, and `allow-inhibiting = false` so a client holding a shortcuts inhibitor cannot withhold locking. The blank is a second step (`noctalia msg dpms-off`) because Noctalia's DPMS rides the *idle* ladder, which a keypress resets — without it a deliberate lock would leave the panel lit longer than simply walking away does. This is why the key no longer appears in [§Inherited reservations](#inherited-reservations--not-ours-always-live) below: it moved from an inherited default to an owned bind. Out of scope for this doc: electra (headless, no niri — keeps a declared `poweroff` at the logind layer) and celaeno (Darwin — macOS owns the key).

## Inherited reservations — not ours, always live

| Chord | Action | Note |
|---|---|---|
| `Ctrl+Alt+F1‑F12` | VT switch (niri, **unbindable**) | **The `Ctrl+Alt` base must never bind the F-row** — the one hard collision the cutover introduces. |
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
- **Handlers** — niri actions (Linux); **skhd** hand-authored `skhd-exec`
  bodies (macOS — focus/move/workspace/app-launch/edge-scroll/maximise/
  cycle-terminal-windows, all hand-authored since skhd has no verb emitter to
  parallel `niri-action` — ADR-047 §Decision); the action menu.
- **macOS terminal** (`Hyper+Return`) — `open -na Ghostty.app` (yabai then
  tiles the new window); a new app instance per window, paired with
  `quit-after-last-window-closed = true` in `ghostty.nix`.
- **Generation** — every surface is emitted from the single-source registry
  (#384; Epic F #428); the new base shape lands **atomically** (never
  half-migrated).

## Implementation status

This document is the **audited target**, landing in phases through the
single-source capability registry (`lib/capabilities.nix`; ADR-039, #384). The
**Linux Hyper layer cut over** to the `Ctrl+Alt` base: `home/nixos/niri.nix`
(binds generated by the registry) and `modules/nixos/keyd.nix` (the Caps→Hyper
substrate reading the same constant).

The **macOS Hyper layer runs on yabai + skhd** (ADR-047, superseding ADR-040
and ADR-039 §7): `home/darwin/karabiner.nix` (Caps→`Ctrl+Opt`, reading the
same `tiers.hyper.darwin` constant; the Mission-Control/Space-jump remaps stay
retired — `karabinerHyperRemapKeys` emptied) and `home/darwin/skhd.nix` (the
full Hyper keymap — every darwin-realized capability is a hand-authored
`skhd-exec` body, since skhd has no verb emitter to parallel `niri-action`).
`modules/darwin/keyboard-shortcuts.nix` carries **no `Hyper` base** — it owns
only the screenshot chord swap. The native `Ctrl+1‑9` "Switch to Desktop N"
shortcuts are declared instead in `home/darwin/symbolic-hotkeys.nix`
(re-applied at every activation) and are load-bearing again: `Hyper+1‑9`
synthesizes them rather than calling `yabai -m space --focus`, to keep the
native Mission Control slide (ADR-047 §Decision).

The focus/move binds are **shipped** (no longer a deferred mirror): `Hyper+↑/↓`
= yabai `window --focus north/south`, `Hyper+←/→` = focus with edge-scroll
fallthrough to a synthesized native shortcut at the space edge,
`Hyper+Shift+arrows` = `window --swap`. Bind *inventory* grows incrementally
on the registry; the base *shape* is atomic per platform.

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
  when a Chrome window is parked on another Desktop: verify macOS *follows*
  to that Desktop rather than leaving focus split (on-box check).

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
