# ADR-040: AeroSpace as the macOS window manager

**Date**: 2026-07-02
**Status**: Accepted, Implementation pending (Phase B — #494)

> Adopt **AeroSpace** as neptune's window manager, superseding [ADR-039](./ADR-039-capability-registry.md) §7's pure-Hammerspoon / native-fullscreen-Spaces realization. AeroSpace owns the workspace layer on a single native macOS Space (i3-flat tiling, no SIP), installed declaratively (`pkgs.aerospace` + `programs.aerospace`), with binds single-sourced through a new `aerospace-action` emitter. **Hammerspoon retires from the interaction stack entirely** — Karabiner (Hyper substrate) + AeroSpace only. This reverses a frozen decision on the strength of a live Phase-A trial (GO); the *why* lives in the design note [`docs/design/macos-deterministic-tiling.md`](../design/macos-deterministic-tiling.md), this ADR freezes the decision.

## Context

[ADR-039](./ADR-039-capability-registry.md) §7 settled macOS window management as **pure Hammerspoon, no tiling WM**: maximized-columns-as-native-fullscreen-Spaces plus stateless geometry hotkeys and a Hammerspoon focus/move-mirror. That was the right call *at the time* — no tiler cleared the repo's posture bar (SIP-free, declarative, correct on the Electron-heavy app set), so the within-a-Space layer stayed hand-driven. The design note [`macos-deterministic-tiling.md`](../design/macos-deterministic-tiling.md) then reframed the requirement: the **need** is deterministic auto-tiling on open; "mimic niri/Linux by tiling *within* native Spaces" was one *means*, wrongly frozen as immovable. Separating them reopened the field — a tiler that *owns* workspaces (as niri already does on Linux) becomes acceptable if it clears the immovable forces. A live Phase-A trial on neptune (2026-06-29 → 2026-07-02, verdict **GO**) confirmed AeroSpace does, and that living without native Spaces is acceptable day-to-day. Because this reverses a *frozen* decision, it is recorded as a superseding ADR (the ADR-028→029 pattern), not an in-place amendment.

## Decision

Adopt **AeroSpace** as the window manager on neptune, replacing ADR-039 §7's realization wholesale:

- **Workspace model.** A single native macOS Space; AeroSpace owns the workspace layer, parking inactive windows off-screen (no SIP — public Accessibility API + one private window-ID call). Layout is **i3-flat `tiles`** (manual nesting via `join-with`) with an `accordion` toggle — *not* dwindle/auto-BSP, and *not* scrollable columns (the sharpest accepted limitation). Native fullscreen and Mission Control navigation are given up.
- **Packaging (declarative).** `pkgs.aerospace` (the nixpkgs `aarch64-darwin` derivation, not a cask) + the `programs.aerospace` home-manager module in `home/darwin/aerospace.nix`, with **`launchd.enable`** for start-at-login (enabling `launchd` forces `start-at-login = false` + an empty `after-login-command` — build against that).
- **Binds single-sourced (ADR-039 principle preserved).** A new **`aerospace-action`** emitter in `lib/capabilities.nix` parallels `niri-action`, emitting the simple verbs (focus/move/workspace/app-launch) into `programs.aerospace.settings`. Two **complex binds are hand-authored** (the edge-scroll fallthrough on `Hyper+←/→`, and maximise-by-isolation on `Hyper+Shift+M`); the collision lint must extend to the **merged** chord namespace (emitted ∪ hand-authored). `karabinerHyperRemapKeys` is emptied permanently and `darwinReservedChords` dropped (freeing `Ctrl+Opt+arrows` / `Ctrl+Opt+1‑9` for AeroSpace).
- **Hammerspoon retired entirely.** The Ghostty-new-window spike (Phase-B Stage 0) found `open -na Ghostty.app` is a Hammerspoon-free new-window path (multi-instance, accepted, paired with `quit-after-last-window-closed = true` in `ghostty.nix`). So *all* app-launch is `aerospace-action exec-and-forget`, the 6 geometry handlers retire, and Hammerspoon leaves the interaction stack — **Karabiner (Hyper substrate) + AeroSpace only**. This also closes the Hammerspoon launch-at-login gap and the AeroSpace/Hammerspoon event-tap coexistence question.
- **Border + geometry from theme tokens.** JankyBorders (`services.jankyborders`) draws the active-window border AeroSpace lacks natively: active `base0D` (`tokens.color.role.focus`), inactive `base03` (`tokens.color.role.muted`), width 6, `style=round`. Gaps: inner `tokens.layout.gap` (16), outer 10.
- **Settled keymap** (full table in the design note §Design): focus `Hyper+←/→/↑/↓` (`←/→` carry a darwin-specific edge-scroll fallthrough to the adjacent workspace); move `Hyper+Shift+←/→/↑/↓`; workspaces **`Hyper+1‑9`**, move-to-workspace `Hyper+Shift+1‑9`; `Hyper+Shift+M` maximise-by-isolation (AeroSpace has no stable maximize); `Hyper+,` tiles↔accordion; `Hyper+Tab` `workspace-back-and-forth`; `Hyper+Shift+;` service mode; app-launch `Hyper+Return`/`B`/`F`/`M`/`E`/`S`/`/` → Ghostty/Chrome/Finder/Messages/Outlook/Slack/1Password.

**Preserved from ADR-039** (this ADR touches only §7): the single-source registry itself (§1–6), the Hyper taxonomy (base `Ctrl+Alt` on Linux / `Ctrl+Opt` on macOS, parity-not-identity), the three-dimension schema, the eval-time collision lint (§8), and extraction-readiness (§9) all stand. Karabiner remains the Hyper substrate; the `aerospace-action` emitter is a *new realization type* alongside `niri-action`, not a departure from the architecture. The niri-side capability IDs for the dropped geometry (`center`/`maximize`/preset-width) are kept — only their `platforms.darwin` realization is dropped.

## Rationale

- **The §7 disqualification rested on a negotiable.** ADR-039 §7 rejected AeroSpace as "i3 tree, not scrollable — wrong paradigm." The characterisation is accurate — AeroSpace genuinely cannot do niri-style scrollable columns — but "not scrollable" maps to negotiable force 9 (niri-feel), not an immovable. Once that constraint is relaxed (as it already is on Linux, where the tiler owns workspaces), the paradigm objection dissolves and AeroSpace clears every immovable: deterministic auto-tiling on open, no SIP, declarative (`pkgs.aerospace` + HM module), single-sourceable (the `aerospace-action` emitter), and correct on the Electron set (it implements the `AXEnhancedUserInterface` resize workaround).
- **The maintenance tiebreaker picks AeroSpace over Amethyst.** Both clear the immovables and both are recently active; AeroSpace carries the momentum (≈21k vs ≈16k stars, higher commit activity per the design note's de-risk survey) and is the best-Nix-packaged (nixpkgs derivation + HM module vs cask + YAML). Amethyst's only edge was honouring native Spaces — a negotiable, so it stops counting.
- **The load-bearing assumption was de-risked live, not asserted.** The trial's decisive question was whether *living without native Spaces* is tolerable day-to-day; three days on neptune said yes, alongside confirming Electron tiling and no-collision Hyper chords. Documentary-only confidence would not have justified reversing a frozen decision.
- **Retiring Hammerspoon is earned, not incidental.** The one thing blocking a Karabiner-only substrate was the terminal's "always spawn a new window" (plain `open -a` only focuses). The spike found `open -na Ghostty.app` does it without Hammerspoon — at the cost of a new app instance per window, judged acceptable under tiling (and made clean by `quit-after-last-window-closed = true`). With that, the entire Hammerspoon dependency (cask, `init.lua`, launch-at-login, Accessibility grant, event-tap coexistence) is shed for a strictly smaller stack.

## Consequences

- ✓ **The standing need is met** — windows auto-tile deterministically on open, the destination since ADR-039 §7.
- ✓ **The interaction stack shrinks to Karabiner + AeroSpace.** Hammerspoon leaves entirely, closing its launch-at-login gap and the event-tap coexistence question (no shared hotkeys remain).
- ✓ **Binds stay single-sourced** (ADR-039's principle): the `aerospace-action` emitter parallels `niri-action`, so a capability is still declared once.
- ✓ **macOS converges on the niri action-verb model**, opening a (non-committal) path to macOS↔Linux parity if Linux later moves to Hyprland — parity at the *verb* level, not the layout paradigm.
- ✗ **Permanent divergence from stock macOS** — no native Spaces, native fullscreen, or Mission Control navigation; a real relearning cost, accepted after the trial.
- ✗ **No true scrollable columns** — only `tiles` (cram) / `accordion` (slivers); the `Hyper+←/→` edge-scroll reconstructs continuity only at *workspace* granularity.
- ✗ **Betting the daily-driver WM on a Beta** — AeroSpace is v0.20.x-Beta, pre-1.0, load-bearing all day.
- ✗ **Multi-instance terminal** — each `Hyper+Return` is a new Ghostty app instance (process-per-window); mitigated by `quit-after-last-window-closed = true`, and mostly cosmetic under tiling.
- ✗ **Off-screen-emulation quirks are permanent**, not bugs to fix: Mission Control mis-sizes parked windows, inactive windows leave 1px slivers.
- ✗ **A new `aerospace-action` emitter to build and maintain** — real engineering, partly offset by retiring the Hammerspoon geometry handlers.
- ⚠ **Migration trigger — AeroSpace instability or abandonment.** If the Beta proves unreliable as a daily driver, or upstream stalls, fall back to ADR-039 §7's manual/native path (or reassess the field). No automatic revisit.
- ⚠ **Migration trigger — a scrollable-columns macOS tiler matures.** If a SIP-free tiler delivers niri/PaperWM-style scrollable columns without the fragility that ruled those out, the no-scroll acceptance is worth revisiting.

## Implementation

Decision-only ADR; the build is **Phase B (#494)**, staged and each stage gated by peer review:

1. **Core declarative build** — `home/darwin/aerospace.nix` (`programs.aerospace` + `launchd`); the `aerospace-action` emitter + merged-namespace collision lint in `lib/capabilities.nix`; the two hand-authored complex binds; empty `karabinerHyperRemapKeys` + drop `darwinReservedChords`; retire `home/darwin/hammerspoon.nix` and drop the Hammerspoon cask; `quit-after-last-window-closed = true` in `home/darwin/ghostty.nix`.
2. **Borders** — `services.jankyborders` with colours/width and AeroSpace gaps sourced from `lib/theme-tokens.nix`.
3. **Runbook** (`docs/runbooks/darwin-bootstrap.md`) — the non-declarable manual steps: disable "Automatically rearrange Spaces", Accessibility grants for AeroSpace + JankyBorders.
4. **Teardown** — `rm ~/.config/aerospace/aerospace.toml` before the first `nh darwin switch` with the module (activation clobbers the pre-existing unmanaged file); delete the throwaway `trial/aerospace` branch once live and verified.

The gotchas the emitter must bake in (package-derived absolute `aerospace` path, `--no-stdin` on implicit-stdin subcommands, `exec-and-forget` swallowing errors → per-bind on-box verification) are detailed in the design note §Design.

## References

- [`docs/design/macos-deterministic-tiling.md`](../design/macos-deterministic-tiling.md) — the design note (the *why*): the need-vs-means reframe, the force classification, the settled keymap, and the trial corrections this ADR freezes.
- [ADR-039](./ADR-039-capability-registry.md) — §7 (macOS realization) superseded here; §1–6, §8–9 preserved.
- #494 — Phase B (this ADR's implementation); #440 — the original macOS window-management placement; #488 — the Karabiner empty-manipulator filter (merged, relied on by the emptied `karabinerHyperRemapKeys`).
- The Phase-A trial (throwaway `trial/aerospace` branch) — GO; its dated findings are preserved in §History below and its design corrections graduated into the design note.

## History

The trial's findings log lived on the throwaway `trial/aerospace` branch (deleted at Phase-B teardown); its durable provenance is captured here.

- **2026-06-29 — Phase-A trial began** (`nix profile` install of `pkgs.aerospace` + a scratch `~/.config/aerospace/aerospace.toml`, representative Hyper keymap, 6 Hammerspoon geometry handlers disabled). Day-1 findings: tiling works and is a daily win; AeroSpace is **i3-flat + accordion, not dwindle/BSP** (the design note's "dwindle cousin" framing corrected); **no scrollable columns** — the sharpest limitation, reconstructed as `Hyper+←/→` edge-scroll at workspace granularity; `exec-and-forget` gotchas found (no nix profile on `PATH` → absolute path; `workspace next|prev` needs `--no-stdin`; errors swallowed → silent no-ops); JankyBorders chosen for the active-window border AeroSpace lacks; Hyper dies over Screen Sharing (Karabiner grabs the physical keyboard; injected CGEvents bypass it) but literal `Ctrl+Opt+<key>` works.
- **2026-07-02 — maximise-by-isolation settled** (`Hyper+Shift+M`): AeroSpace's `fullscreen` drops on focus-change, so isolating a window onto an empty workspace is the focus-stable equivalent. Two bugs recorded: `list-windows --count` counts floating windows (Stage-1 fix: filter floating); "no empty workspace → silent no-op" (documented limitation).
- **2026-07-02 — trial concluded GO.** Auto-tiling is a daily win, the Hyper keymap feels right, the Electron set tiles, living without native Spaces is acceptable, and Hammerspoon (de-fullscreened spawns) + AeroSpace coexist.
- **2026-07-02 — Phase-B Stage-0 Ghostty-new-window spike.** `+new-window` is Linux/GTK-only; macOS has no scriptable single-instance new-window; `open -na Ghostty.app` is the only Hammerspoon-free path and spawns a **new app instance per window** (verified on-box: no instance coalescing). Decision: retire Hammerspoon entirely, accept the multi-instance model, pair with `quit-after-last-window-closed = true` in `home/darwin/ghostty.nix`.
