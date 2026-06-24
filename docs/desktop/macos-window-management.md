# macOS window management

How the macOS host (neptune) gets niri's geometry/column *feel* — directional focus/move plus the geometry cluster (resize / preset-width / center / fullscreen / maximize) — without a tiling window manager. The decision is **pure Hammerspoon leaning on native macOS primitives**, frozen in [ADR-039 §7](../decisions/ADR-039-capability-registry.md) and scoped by [#440](https://github.com/dannyfaris/nix-config/issues/440); this doc is the canonical selection record that issue calls for.

## Selection

**Pure Hammerspoon, standalone — no tiling WM.** The geometry cluster is realized as **stateless hotkeys** acting on the focused window; "maximized columns" are **native full-screen Spaces** navigated natively (`Ctrl+←/→`, `Ctrl+1‑9`), leaning on macOS's own fullscreen-state memory (apps reopen fullscreen) rather than a per-app pinning engine. The result approximates niri's scrollable-column model with native, supported primitives — trading true off-screen scrolling and drag-to-reflow (which intrinsically need a stateful tiler) for reliability on a daily-driver Mac.

The hotkeys land on the `Hyper` layer (`Ctrl+Opt` on macOS — produced from Caps Lock by Karabiner, see [karabiner.md](./karabiner.md)) and are generated from the single-source capability registry (`lib/capabilities.nix`) by the Hammerspoon emitter, so the bind inventory is single-sourced with the niri side. Karabiner produces the chord; Hammerspoon binds Lua handlers to it (see [hammerspoon.md](./hammerspoon.md) for the tool selection).

## The geometry cluster

Stateless handlers, each acting on `hs.window.focusedWindow()`. The bind table is in [keybinds.md §Window geometry](./keybinds.md#window-geometry--hyper--letter); the *behaviour* of each is pinned here:

| Chord | Handler | Behaviour |
|---|---|---|
| `Hyper+F` | `fullscreenWindow` | **Native fullscreen** — the window animates onto its own Space (*positional* — reached by `Ctrl+←/→`). The niri `fullscreen-window` analogue. |
| `Hyper+M` | `maximizeToFrame` | **Maximize to the screen's visible frame** — fills the current numbered Desktop (*number-addressable* — reached by `Ctrl+1‑9`), menu-bar and Dock respected. The niri `maximize-column` analogue. |
| `Hyper+C` | `centerWindow` | Center the window on screen at its current size. |
| `Hyper+R` | `snapPresetWidth` | **Stateless preset-width snap** (Rectangle-style): read the window's current width as a fraction of the screen and snap to the next preset in the cycle (e.g. ½ → ⅔ → maximize → ½), keeping the window's vertical extent. *Stateless* — the next step is inferred from the current frame, never stored, so this stays clear of the rejected stateful-tiler path. |
| `Hyper+−` / `Hyper+=` | `shrinkWindow` / `growWindow` | Shrink / grow the window's width by a fixed step around its current center. |

**`F` vs `M` is deliberate and not interchangeable.** `F` is true native fullscreen — a *positional* Space with no menu bar, navigated by the `Ctrl+←/→` Space-slide. `M` is a maximize-to-frame on a *numbered* Desktop, navigated by `Ctrl+1‑9`. The two map onto macOS's two distinct "big window" models (own-Space fullscreen vs. a maximized window on a numbered Desktop); collapsing them would lose the positional-vs-numbered distinction the Mission Control navigation relies on.

## Rejected alternatives

Decided through a `selecting-tooling` exploration; the full rationale lives in [#440](https://github.com/dannyfaris/nix-config/issues/440) and [ADR-039 §7](../decisions/ADR-039-capability-registry.md). In brief:

- **AeroSpace** — i3-style *tree* tiling, not scrollable; lacks preset-width + center. Wrong paradigm despite the best packaging (nixpkgs + module).
- **Paneru / OmniWM** — genuinely scrollable (niri-like) but 0.x, single-maintainer → daily-driver reliability risk. (Paneru trialled; native-fullscreen stability preferred.)
- **PaperWM.spoon / a custom Hammerspoon tiler** — stateful-tiler fragility: `hs.spaces` private-API flakiness, Electron AX misreporting, no true off-screen scroll.
- **yabai** — its scripting addition requires partially disabling SIP → a posture dealbreaker.
- **Magnet** — duplicates Hammerspoon, non-declarative, paid/MAS. (Rectangle / Loop noted as fallbacks only.)

## Configuration

- **Handlers** — hand-authored Lua in `home/darwin/hammerspoon.nix`. The handler *bodies* live there; the registry references each by *name* and the emitter (`lib/capabilities.nix`, `hammerspoonBindsFor`) generates the `hs.hotkey.bind(...)` calls. This mirrors the niri side's `niriBindsFor` (the emitter emits bindings; the module owns the rest) and keeps `capabilities.nix` pure codegen (ADR-039 §9, extraction-ready).
- **Substrate** — Caps Lock → `Hyper` (`Ctrl+Opt`) is hand-authored in `home/darwin/karabiner.nix`, reading the single-sourced `tiers.hyper.darwin` constant from the registry (ADR-039 §4). The base-shape change is one edit.
- **Collision lint** — the eval-time keybind lint covers the macOS chords too: no two Hammerspoon handlers may claim one chord, and a handler may not land on a chord the Karabiner substrate already reserves (the `Ctrl+Opt+arrow` Mission-Control remaps and `Ctrl+Opt+1‑9` Space jumps). See `lib/capabilities.nix` and [ADR-039 §8](../decisions/ADR-039-capability-registry.md).

## Sharp edges

- **Electron AX misreporting.** The Electron-heavy app set (Chrome, Cursor, Claude, ChatGPT, Slack, Obsidian) is where the Accessibility API misreports windows — per-app rules and any drag-move are least reliable there. The stateless geometry handlers act on `hs.window.focusedWindow()` and are the reliable case; native apps (Ghostty, system apps) are reliable throughout.
- **Cross-Space moves are deferred and known-fragile.** The focus/move-mirror (directional focus/move with cross-Space edge fallthrough) leans on Hammerspoon's `hs.spaces` handling — a private, flaky macOS surface. It is **not** part of this slice; see [keybinds.md §Open questions](./keybinds.md#open-questions).
- **Runtime behaviour is on-box only.** Hammerspoon + Karabiner runtime cannot be exercised from Linux — the geometry hotkeys and the `Ctrl+Opt` substrate are verified at the neptune keyboard, not in CI (CI only evaluates that the generated `init.lua` + Karabiner JSON build).

## Scope — what this slice does *not* do

Deferred to later slices on the same `keybinds.md` taxonomy: the focus/move-mirror (`focusWindow{East,West,North,South}` + the `Hyper`/`Hyper+Shift`/`Hyper+Super` arrow tiers + cross-Space edge fallthrough); role-based float for dialogs/utilities; fullscreen-on-spawn for new windows; visual cues (`hs.window.highlight` focus-ring + `hs.canvas`/`hs.alert` on-action feedback); optional `Mod`+drag-move/resize. Drag-to-reflow is permanently out (it needs a stateful tiler).

## References

- [ADR-039](../decisions/ADR-039-capability-registry.md) §7 — the frozen macOS-realization decision (and §4 substrate boundary, §8 validation).
- [#440](https://github.com/dannyfaris/nix-config/issues/440) — the decided design + the full rejected-alternatives rationale + the Electron-AX caveat.
- [keybinds.md](./keybinds.md) — the cross-platform taxonomy; this work fills its macOS geometry cells.
- [hammerspoon.md](./hammerspoon.md) — the Hammerspoon tool selection (the action layer).
- [karabiner.md](./karabiner.md) — the Caps → `Hyper` substrate (the modifier-production layer).
