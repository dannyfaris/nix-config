# ADR-039: Single-source capability registry — the cross-platform keybind & interaction architecture

**Date**: 2026-06-24
**Status**: Accepted, Implementation pending

> One semantic capability registry (`lib/capabilities.nix`) becomes the single source for the cross-platform interaction layer: it generates the keybind configs (niri/keyd/Karabiner/Hammerspoon), a unified action/cheatsheet **palette**, and the `keybinds.md` reference table — from one declaration per capability. Freezes the load-bearing decisions of the 2026-06-23 keybind audit and the interaction-design thread: the Hyper taxonomy keystone (Hyper = primary cross-platform layer at `Ctrl+Alt`/`Ctrl+Opt`, parity-not-identity; Super = the Cmd-parity command modifier), the three-dimension schema (chord-tokens · per-platform realization · descriptive metadata), the atomic base-shape cutover, the unified palette, and the pure-Hammerspoon macOS realization. Detail lives in the living docs (`keybinds.md`, the research notes) and the build issues (#384/#437/#442/#440); this ADR is the frozen *why*.

## Context

The cross-platform interaction layer is realized across five hand-authored surfaces — `keyd`, `home/nixos/niri.nix`, `home/darwin/karabiner.nix`, `home/darwin/hammerspoon.nix`, and `docs/desktop/keybinds.md`. Each restates the same capabilities, so a single change — redefining the Hyper base, adding a bind — is a five-place hand-edit that drifts. A 2026-06-23 keybind audit re-derived the taxonomy (now `keybinds.md`, #439), and a prior-art scan (#432) found no *surveyed* tool single-sourcing keybinds across a Linux compositor *and* macOS with collision/availability linting — partially served at the component level, but genuinely open as the integrated whole (the verdict is survey-bounded). Epic F (#428) frames the registry, Epic C (#425) the interaction surface, Epic E (#427) the runtime/declarative boundary.

## Decision

Adopt a single semantic **capability registry** (`lib/capabilities.nix`) as the one source for the cross-platform interaction layer. Each capability is declared once; emitters generate every surface.

**1. One source → emitter families.** Keybind configs (niri / keyd / Karabiner / Hammerspoon); the unified **capability palette** (#442), fed by an external Nix-authoritative dataset (#437); and the generated `keybinds.md` reference table.

**2. The capability schema — three dimensions.**
- **Chord** — `tier + key` tokens (the base16 "name by slot, not tone" discipline), resolved per-platform from one `Hyper` constant. *Parity-not-identity*: same UX, the chord may differ per platform.
- **Realization** — per-platform, typed: `niri-action` · `karabiner-remap` · `hammerspoon-handler` · `menu/command`. Designed against the *hardest* consumers (Karabiner consumed-modifier remaps, the Hammerspoon Lua-handler split, the palette dataset) — a flat `command.{linux,darwin}` string can't express a niri verb or a keystroke-remap.
- **Descriptive** — `label · description · keywords`: what the palette searches and the doc table renders. A **shared default** at the capability's top level, with an **optional per-platform override** (`platforms.<p>` may carry its own `label`/`description`/`keywords`) for the cases where the prose genuinely diverges — niri's *column* vocabulary has no macOS analogue (macOS speaks only of *windows*), and a chord whose action differs per platform (e.g. niri switch-workspace vs macOS Mission Control) needs platform-specific text and keywords too. Effective descriptive for platform `p` = `platforms.<p>.<field>` falling back to the shared default; the common case stays single-authored.

Concretely — one capability (illustrative shape; the full field spec is #384's):

```nix
{
  id = "lock-screen";

  # descriptive (shared default; a platform may add a `label`/`description`/
  # `keywords` override under `platforms.<p>` where the prose diverges) —
  # searched & shown by the palette; rendered into the doc table
  label       = "Lock screen";
  description = "Lock the session and show the login screen";
  keywords    = [ "logout" "secure" "away" ];

  # chord — an attrset of tier + key tokens (plus optional `mods = [ "Shift" ]` /
  # `[ "Super" ]` escalators); the `hyper` tier resolves per-platform (Ctrl+Alt / Ctrl+Opt)
  chord = { tier = "hyper"; key = "Escape"; };

  # realization — per-platform, typed; the payload follows the type. A
  # niri-action carries its verb under `action.<verb>`; a hammerspoon-handler
  # names a Lua handler whose body is hand-authored in hammerspoon.nix.
  platforms.linux  = { realization = "niri-action";        action.spawn = [ "loginctl" "lock-session" ]; };
  platforms.darwin = { realization = "hammerspoon-handler"; handler = "lockScreen"; };
}
# other declared realization types, not yet emitted: karabiner-remap (→ keystroke) · menu/command
```

**3. The Hyper taxonomy (keystone).** `Hyper` = the primary command layer, base `Ctrl+Alt` (Linux) / `Ctrl+Opt` (macOS); `Super` = the Cmd-parity command modifier (app-commands, text-nav, launcher, app-switch). The minimal two-modifier base deliberately frees `Shift` and `Super`/`Cmd` to stack as escalators — individually or together (e.g. `Hyper+Shift`, `Hyper+Super`) — which is the whole point of dropping the old all-four base. niri's spatial model is the organizing frame (macOS Space ≈ niri column, by spatial cognition). The full, living taxonomy — the per-tier bind table — is `keybinds.md` (#439); this ADR freezes only the load-bearing shape, not the bind inventory.

**4. Substrate boundary.** Caps→`Hyper` *production* stays hand-authored substrate (keyd `layer`, Karabiner `capsLockToHyper`); the registry owns chord→action only. `Hyper` is a single-sourced `lib` constant both substrate and emitters consume, so the base-shape change is one edit. **kanata stays a documented, gated fallback — never part of the registry** (it's a runtime input engine, not an emitter; `keyd.md` §Alternatives, #428).

**5. Atomic base-shape cutover.** The first generation emits the new `Ctrl+Alt`/`Ctrl+Opt` shape across all surfaces at once — never the superseded all-four `Super+Ctrl+Alt+Shift` then migrate. Bind *inventory* still grows incrementally (one-bind-per-ceremony); the base *shape* is atomic.

**6. The unified capability palette (#442).** The action menu and the keybind cheatsheet are *one* surface: a flat, type-to-filter spotlight over the registry, where every entry shows its keybind + description and is invokable, with no ranking hierarchy. Dataset = registry-only (Tier 1; app-internal and un-declared-OS binds out). niri's `show-hotkey-overlay` retires when it lands. Renderer per the research (Noctalia dmenu / `hs.chooser`); fuzzel excluded (decommissioned with the Noctalia adoption, ADR-036 / #385).

**7. macOS window-management realization** *(resolves #440's open ADR-placement)*. Pure Hammerspoon, standalone — **no tiling WM**. Maximized columns = native full-screen Spaces (navigated natively, leaning on macOS's fullscreen-state memory); stateless geometry hotkeys; a Hammerspoon focus/move-mirror gives niri-like 2-D directional focus/move. Rejected with rationale (full detail in #440): AeroSpace (i3 tree, not scrollable), Paneru/OmniWM (0.x single-maintainer — daily-driver risk), PaperWM.spoon/custom tiler (stateful-tiler fragility), yabai (SIP), Magnet (non-declarative).

**8. Validation.** Collision lint at eval time — a new check riding the eval-check machinery ADR-033 established (`lib/stances.nix` → `parts/checks.nix`) — from Phase 1; availability lint (chord not shadowed by OS/WM/app-reserved binds, HotkeyClash-style) later. The one hard inherited reservation honored from day one: **the `Ctrl+Alt` base never binds the F-row** (`Ctrl+Alt+F1‑12`, niri's unbindable VT switch).

**9. Extraction-ready.** Structure `lib/` as a clean, repo-decoupled unit so future packaging stays cheap — *designed-for-the-option*, not publishing now (#428 scope note 1).

## Rationale

- **Why single-source.** The five-surface hand-edit is the drift this exists to kill; the Hyper base-shape change must be one edit. The prior-art scan (#432) indicates the integrated emitter-plus-lint is unserved (survey-bounded), so it's worth building rather than adopting.
- **Why parity-not-identity.** Native modifiers aren't free on both platforms (`Cmd+Arrow` = macOS text-nav; `Ctrl+Arrow` = Linux word-nav). `Hyper` (from Caps) is the one modifier free on both — same UX, best-fit chord per platform.
- **Why a realization-typed schema.** niri verbs, Karabiner consumed-modifier remaps, and Hammerspoon Lua handlers are not shell commands; a flat command string fits only the menu case. Designing against the hardest consumers keeps the emitters honest.
- **Why one unified palette.** A keybind and a menu entry are the same capability (id · chord · description) differing only in trigger; the registry shows chords inline for free, so one surface serves both "invoke" and "learn the bind." A separate cheatsheet would duplicate the data.
- **Why atomic cutover.** Half-migrating a modifier base across five surfaces is precisely the drift the registry exists to prevent.
- **Why pure Hammerspoon on macOS.** Native-fullscreen-as-column is the stable, supported, niri-approximate path; making a 0.x single-maintainer project the window manager of a daily-driver Mac is a reliability bet, and the mature option (AeroSpace) is the wrong paradigm. Drag-to-reflow is conceded as the one niri behaviour macOS doesn't get (it needs a stateful tiler).
- **Why kanata stays out.** It's a runtime input engine, not an emitter; the input layer needs no engine beyond plain modifier stacking + tap-hold + chord-opens-chooser.

## Consequences

- ✓ The Hyper base-shape change becomes one edit; surfaces cannot drift.
- ✓ `keybinds.md`, the palette, and the configs all derive from one declaration — a new bind lands everywhere at once.
- ✓ The unified palette is both action menu and searchable cheatsheet; niri's overlay retires.
- ✓ Collision linting (and later availability linting) becomes possible at eval time.
- ✗ A new `lib/` codegen primitive plus emitters to build and maintain — the registry is real engineering, not config.
- ✗ The schema couples the keybind and palette features at the source (mitigated: emitters ship independently; the palette is added without touching the keybind emitters).
- ✗ macOS gives up true scrollable tiling and drag-to-reflow — a deliberate trade of fidelity for native stability.
- ⚠ Revisit **kanata** only if a concrete input-layer residue emerges beyond plain stacking + tap-hold + chord-opens-chooser. Revisit the **macOS tiling** stance if a scrollable WM matures past 0.x / single-maintainer.
- ⚠ The Super-layer realization (copy/paste + text-nav via xremap, #323) and the palette **renderer** choice (#442) ride parallel tracks; this ADR does not settle them.

## Implementation

Build sequence, walking-skeleton first:

1. **#384** — registry + the three-dimension schema + collision lint + the **niri emitter (walking skeleton)** + the atomic `Ctrl+Alt` cutover. The keyd→niri `ISO_Level3_Shift` delivery verify rides this phase — it decides only the optional AltGr padding; bare `Ctrl+Alt` is the known-good fallback.
2. macOS emitters (the `Hyper`-constant consumer in keyd, Karabiner, Hammerspoon) + **#440** (the macOS window-management realization).
3. The generated `keybinds.md` table — **prioritised ahead of the palette**: the table is still hand-maintained, so the doc-drift this registry exists to kill is live today (a handler change still has to be mirrored into prose by hand), and the table generates from the registry's already-built descriptive dimension, so it is also the cheapest remaining surface.
4. **#437** — the external capability dataset (the data-home / declarative-boundary contract).
5. **#442** — the unified capability palette (renderer per the research; niri overlay retires on landing); then, deferred, the availability lint.

Living detail is single-sourced elsewhere (ADR-032), not restated here: the taxonomy → `docs/desktop/keybinds.md`; the analysis → `docs/research/{hyper-layer-redesign, cross-platform-action-menu, keymap-single-sourcing-prior-art, launcher-strategy}.md`; the macOS realization → #440; the epics → #428 (F), #425 (C), #427 (E).
