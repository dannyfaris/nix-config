# Deterministic window tiling on macOS

**Status:** Proposed — design note (`docs/design/`). Not yet built. Frames the **need** — deterministic window tiling on macOS — and splits requirements into *immovable* (the need + repo posture stances) vs *negotiable* (constraints that served our original "mimic niri/Linux" approach). Among the approaches explored, **AeroSpace is the leading candidate, contingent on a live trial on neptune** (the de-risk gate, not a foregone conclusion): it clears the immovable forces but relaxes negotiable ones (native Spaces, niri-mimicry). Supersedes this note's prior selection (Amethyst — PR #484) and its within-Space framing; on acceptance, replaces [ADR-039 §7](../decisions/ADR-039-capability-registry.md)'s macOS realization → ADR-worthy (#440).

## Summary

The need: **windows on macOS should tile automatically into a deterministic layout as they open** (the Hyprland pattern), rather than piling up to be hand-arranged. This note frames that need first and treats every workspace/Spaces decision as a *means* to it. We explored three approaches — native macOS tiling driven from keybinds (manual), Amethyst (auto-tiling *within* native Spaces), and AeroSpace (auto-tiling with a tiler-owned workspace layer) — and separate the requirements into **immovable** (the need itself, plus the repo's posture stances) and **negotiable** (the constraints that merely served our initial "mimic the niri/Linux experience on macOS" approach). AeroSpace clears every immovable force but breaks several negotiable ones (it owns workspaces instead of using native Spaces); because those constraints are negotiable, that is acceptable *if a live trial shows the result is good enough to justify relaxing them*. AeroSpace is therefore the current trial candidate, not a settled choice.

## Motivation

The destination has always been **automatic, deterministic tiling** on macOS — windows open already placed into a layout. [ADR-039 §7](../decisions/ADR-039-capability-registry.md) settled for native-fullscreen-Spaces-as-columns plus *manual* stateless geometry hotkeys, because at the time no tiler cleared the repo's posture bar; that left the within-a-Space layer hand-driven, which is the gap this note closes.

The framing mistake worth naming explicitly (it cost several iterations): the original requirement **fused the need with an assumed means**. "Deterministic tiling" (the need) was bundled with "mimic niri/Linux by tiling within native macOS Spaces" (one *approach*), and once fused, every candidate got measured against the approach instead of the need — so a *negotiable* constraint ("complement native Spaces, never own workspaces") was treated as if it were immovable. Separating the two reopens the field: the need stands; the niri-mimicry was always relaxable.

So this note classifies the forces, and that classification is the heart of the reframe:

**Immovable — the need plus the repo's non-negotiable stances:**

1. **Deterministic auto-tiling on open** — *the need*. Manual-only solutions do not satisfy it.
2. **No SIP.** Accessibility-API only; a [CLAUDE.md](../../CLAUDE.md) deliberate stance, not up for renegotiation (rules out yabai).
3. **Declarative, in-git config.** Install + config live in the flake; no GUI-only state (core philosophy).
4. **Keybind single-sourcing through the registry** ([ADR-039](../decisions/ADR-039-capability-registry.md)). The *principle* is immovable; the *mechanism* (which emitter) is negotiable.
5. **Correct tiling of the Electron-heavy app set** (Chrome, Cursor, Claude, ChatGPT, Slack, Obsidian) — i.e. the `AXEnhancedUserInterface` resize problem must be handled by the tool, not us. A hard correctness gate: a solution that mis-sizes these is unusable here.

**Tiebreaker — a deciding preference, not a gate:** among solutions that clear *all* the immovables, prefer the most actively-maintained / least-bespoke (anti-fragility). This is what separates otherwise-equal options (it is the axis on which AeroSpace beats Amethyst in Rationale); it is a preference that breaks ties, not an absolute bar — so it is kept distinct from the immovable gates above.

**Negotiable — constraints that served the initial "mimic niri/Linux on macOS" approach, now open to relaxation:**

6. **Native macOS Spaces as the workspace layer.** Assumed, not required.
7. **Keep native fullscreen** (apps on their own Space). Assumed, not required.
8. **Complement-not-own workspaces** (the tiler must not own the workspace abstraction). This was the load-bearing constraint we wrongly treated as immovable.
9. **niri-feel parity** (scrollable columns / within-Space). A means to cross-platform consistency, not the need.
10. **Cross-platform convergence** — directional bonus only; decides no head-to-head (see Rationale).

On Linux the tiler *owns* the workspace layer (niri today, Hyprland tomorrow) — so relaxing 6–9 is not exotic; it is how the operator already works on the other platform. The whole point of the classification: a solution is acceptable if it clears 1–5, *whatever* it does to 6–10, provided the trial shows the trade is worth it.

## Design

**Of the approaches explored, AeroSpace is the leading trial candidate** — it clears every immovable force (1–5) while breaking negotiables 6–9 (it owns the workspace layer). The other approaches and why they place lower are in Rationale; the mechanism for the candidate being trialled:

**Tool + packaging.** Install via **`pkgs.aerospace`** (a real nixpkgs derivation, `aarch64-darwin`, built from the upstream release zip — not a cask wrapper), with the **`programs.aerospace`** home-manager module (`home/darwin/aerospace.nix`) owning the config: it renders a `settings` attrset to `~/.config/aerospace/aerospace.toml` and can manage the launchd agent so AeroSpace starts at login — fully declarative (immovable force 3), no Homebrew cask.

**Workspace model — the negotiated relaxation.** neptune runs a **single native macOS Space**; AeroSpace owns the workspace layer, emulating workspaces by parking inactive windows off-screen (no SIP — it does not drive the private Spaces API). This *relaxes* negotiables 6–8: native-fullscreen-Spaces navigation and the §7 stateless geometry handlers go away, replaced by AeroSpace's auto-tiling tree (`tiles`/`accordion` layouts, placement-on-open).

**Keybind remapping.** The change is layered; the substrate is untouched and most chords keep their *meaning*, changing only their *realization* to `aerospace-action`.

- **Substrate — unchanged.** Karabiner keeps producing Hyper (Caps→`Ctrl+Opt`, `tiers.hyper.darwin`); AeroSpace binds on `ctrl-alt-*`, so the chord it catches *is* Hyper. Shifting AeroSpace's default `alt`-based scheme onto Hyper is also strictly *better* than its default — bare Option stays free for special-character input (`⌥e` → é).
- **Delete the Karabiner Mission-Control layer.** The remaps that send `Hyper+arrows`/`Hyper+1‑9` to native Mission Control / Spaces are removed — along with `caps.karabinerHyperRemapKeys` and the `darwinReservedChords` it derives — which *frees* those chords for AeroSpace and drops their lint reservation.
- **Retire the 6 Hammerspoon geometry handlers** (`shrink/grow/snapPresetWidth/center/fullscreen/maximize`); manual geometry is superseded by AeroSpace's tiling. They are disabled for the trial to keep the read clean (§De-risk).
- **AeroSpace claims both sets of chords** — those freed by deleting the Karabiner Mission-Control layer *and* those vacated by the retired Hammerspoon handlers — via a new `aerospace-action` realization (immovable force 4), mirroring the `niri-action` bind for the same capability ID. AeroSpace binds are *verbs* in its TOML `[mode.main.binding]` block — the same shape as `niri-action` — and accept `ctrl-alt` (§De-risk), so the Hyper chord maps directly. Exact command arguments (resize deltas, the service-mode roster) are settled in the Phase B emitter work; the mapping shows the *shape*:

| Chord | Capability (was) | → AeroSpace | Status |
|---|---|---|---|
| `Hyper+←/→/↑/↓` | focus-column/window (Karabiner→native) | `focus left/right/up/down` | Remapped |
| `Hyper+Shift+←/→/↑/↓` | move-* (deferred) | `move …` | Remapped |
| `Hyper+1‑9` | focus-workspace-N (Karabiner→native) | `workspace N` | Remapped |
| `Hyper+Shift+1‑9` | move-to-workspace-N (deferred) | `move-node-to-workspace N` | Remapped |
| `Hyper+Tab` | overview (native) | `workspace-back-and-forth` | Repurposed (no AeroSpace overview — meaning changes) |
| `Hyper+Super+↑/↓` | switch-workspace-up/down (native) | `workspace prev/next` | Remapped |
| `Hyper+−` / `=` | shrink/grow (HS) | `resize smart` (∓ delta) | Remapped |
| `Hyper+F` | fullscreen-window (HS) | `fullscreen` (AeroSpace, not native) | Remapped |
| `Hyper+/` · `Hyper+,` | — | `layout tiles…` · `layout accordion…` | New |
| `Hyper+Shift+;` | — | `mode service` (modal leader for low-frequency ops) | New |

- **Focus/move use the arrow keys only to start** (operator preference). AeroSpace's default `H/J/K/L` focus/move mirrors are a trivial later addition (and would re-align with the niri side's vim mirrors) — deferred, not adopted now.
- **Keep the 2 app-launch handlers** (`Hyper+Return`, `Hyper+B`) in Hammerspoon — they spawn apps (AeroSpace then tiles the window) and don't fight tiling; migrating them to `exec-and-forget` (and retiring Hammerspoon from the keybind layer) is a follow-on the trial can settle.
- **The three niri-isms** (`Hyper+R` preset-width-cycle, `Hyper+C` center, `Hyper+M` maximize) have no BSP equivalent: **drop their `platforms.darwin` realization** (a structural "darwin: N/A", not commented-out code — `deadnix` would flag the latter) but **keep the capability IDs** — the Linux side still uses them, and a future Hyprland move could re-realize `center`/`maximize` (§Future). Their freed chords stay unbound initially.
- **Registry + lint.** The `aerospace-action` emitter parallels `niri-action`; dropping `darwinReservedChords` lets the existing duplicate-chord lint cover the new binds with no special-casing — single-sourcing (force 4) preserved. *(Multi-monitor binds omitted — neptune is single-display.)*

**How the forces are met.** Clears all immovables on documentary evidence — auto-tiling on open (1, AeroSpace's core behaviour); no SIP (2, verified Accessibility-only); declarative (3, `pkgs.aerospace` + HM TOML); single-sourcing (4, via the proposed `aerospace-action` emitter); Electron correctness (5, AeroSpace implements the `AXEnhancedUserInterface` workaround in source) — with two of these, (3) running correctly under launchd and (5) on the *actual* app set, pending the on-box trial (§De-risk). On the **tiebreaker**, it is the most actively-maintained option (what separates it from Amethyst). It *breaks* negotiables 6–9 (owns workspaces, no native Spaces/fullscreen, not niri-scrollable) — acceptable by construction, since those are negotiable and the trial tests whether the trade is worth it.

## De-risk evidence

Verification to date is **documentary, not on-box** — AeroSpace docs/README/source, nixpkgs, and the home-manager module, read 2026-06-29. The live experiment is the de-risk gate before any config lands; its most load-bearing question is whether *relaxing the negotiable constraints* (chiefly: living without native Spaces) actually delivers the need acceptably in daily use. Trial method: run AeroSpace on scratch/default binds with the 6 Hammerspoon geometry handlers disabled (superseded by tiling; off to keep the read clean); the full Hyper/registry integration (Karabiner-layer deletion + the `aerospace-action` emitter) is **Phase B**, only worth doing if the trial wins.

- **AeroSpace owns workspaces / does not use native Spaces — confirmed (documentary).** Its guide: "reimplements Spaces and calls them Workspaces," parking inactive windows off-screen; "only have one macOS Space … and don't interact with macOS Spaces anymore." This is the model we are *accepting*, so the prior note's disqualifier becomes this note's premise.
- **No SIP — verified (README, source).** "Doesn't require disabling SIP … will never require you to disable SIP." Public Accessibility API + one private window-ID call; no Dock injection (the yabai SIP trigger).
- **Electron resize handled — verified (source).** `Sources/AppBundle/tree/MacApp.swift` reads `AXEnhancedUserInterface`, disables it, `setFrame`s synchronously, restores — crediting yabai commit `3fe4c77` and Rectangle PR #285.
- **Nix packaging — verified.** `pkgs.aerospace` at `pkgs/by-name/ae/aerospace/package.nix` (v0.20.x, `meta.platforms = darwin`, fetchzip, MIT); `programs.aerospace` in home-manager with `enable`/`package`/`launchd`/`settings` (attrset → TOML).
- **Activity vs Amethyst — verified (GitHub API, 2026-06-29).** AeroSpace ~21.4k stars, commits daily, last release v0.20.3-Beta (2026-03-08); Amethyst ~16.2k stars, last commit 2026-04-05. AeroSpace has the momentum — but is still self-labelled **Beta**.
- **Bindings accept arbitrary modifiers incl. `ctrl-alt` — confirmed (documentary).** `[mode.main.binding]` modifiers (`cmd/alt/ctrl/shift`) are freely combinable, so a Hyper (`Ctrl+Opt`) chord binds directly — load-bearing for the keybind-remap design.
- **Still unverified (load-bearing → the live experiment):** (a) `pkgs.aerospace` runs as a proper menu-bar agent under launchd on neptune (Tahoe, aarch64); (b) the `programs.aerospace` `settings` schema against our pinned home-manager rev — HM issue #6790 flagged a config-schema breaking change; (c) the reclaimed `Ctrl+Opt` chords fire without collision; (d) Electron tiling on the *actual* app set; (e) — most importantly — whether *living without native Spaces* (Mission Control mis-sizing parked windows, the off-screen 1px slivers, any app you still want in native fullscreen) is acceptable day-to-day; (f) app-launch binds: Hammerspoon vs `exec-and-forget`.

## Drawbacks

Reasons one might not pursue the need this way — or at all:

- **Relaxing the native-Spaces constraint has a real daily cost.** Abandoning native Spaces, native fullscreen, and Mission Control navigation is a large behavioural change and relearning, and a permanent divergence from stock-macOS muscle memory. This is the biggest reason-against; the trial exists precisely to decide whether the need is worth it.
- **Betting the daily-driver WM on a Beta.** AeroSpace is v0.20.x-Beta — active, but pre-1.0, and a WM is load-bearing all day.
- **The off-screen-emulation quirks are permanent**, not bugs to be fixed: Mission Control mis-sizes parked windows, inactive windows leave 1px slivers, and residual native fullscreen conflicts with the model (issues #238/#1615).
- **Couples the macOS experience to one upstream project** — far less fragile than a bespoke tiler, but a single (active) maintainer's pre-1.0 tool at the centre of the desktop.

## Cost

The accepted standing price, once AeroSpace is chosen: **a new `aerospace-action` emitter to build and maintain** in `lib/capabilities.nix` — modest, because it parallels the existing `niri-action` emitter, and partially offset by retiring the Hammerspoon geometry handlers. (The lived divergence from stock-macOS conventions is a *reason-against* the direction, weighed in Drawbacks, not a standing engineering price — so it is not restated here.)

## Rationale & alternatives

Approaches are weighed against the **immovable** forces (1–5); negotiables 6–10 are relaxable, so they do not decide the choice. Where two options both clear 1–5, the **maintenance tiebreaker** separates them:

- **AeroSpace (leading candidate).** Clears all of 1–5; breaks 6–9. **Trialled** because it clears every immovable *and* wins the maintenance tiebreaker (most active, best-Nix-packaged), and breaking the negotiables is permitted if the trial earns it. Note this reverses [ADR-039 §7](../decisions/ADR-039-capability-registry.md), which rejected AeroSpace as "i3 tree, not scrollable — wrong paradigm": scrollability was negotiable force 9 (niri-feel), so the paradigm objection dissolves once that constraint is relaxed.
- **Amethyst (this note's prior selection, PR #484).** Also clears 1–5 *and* honours negotiables 6–8 (tiles within native Spaces). Its only edge over AeroSpace was a *negotiable* constraint — so once 6–8 are relaxable, that edge stops counting, and AeroSpace wins the maintenance tiebreaker and packaging (`pkgs.aerospace` + HM module vs cask + YAML). **Superseded** — it was the right pick only while 6–8 were (wrongly) treated as immovable.
- **Native macOS tiling driven from Hyper (manual).** Fails immovable force 1 (manual, not auto). It was the acceptable *intermediary*, never the destination. Rejected as an endpoint.
- **Bespoke Hammerspoon within-Space tiler.** Fails immovable force 5 (net-new fragile code we own; no prior art to fork). Rejected.
- **yabai.** Fails immovable force 2 (SIP). Rejected.
- **Do nothing (ADR-039 §7 status quo).** Fails force 1 (no auto-tiling). The fallback only if the trial shows AeroSpace's relaxations are intolerable in practice.

**On cross-platform convergence (negotiable force 10):** AeroSpace is selected on forces 1–5 *independently* of any Linux story. That it makes macOS converge with the niri/Linux action-verb model — and opens a path to macOS↔Linux parity if Linux later moves to Hyprland — is a genuine directional bonus, but it changes no head-to-head and partly rests on a future this note does not commit to. Weighed as a bonus, not a deciding force.

**Impact of doing nothing:** the standing need — deterministic auto-tiling — stays unmet.

**ADR relationship.** Adopting AeroSpace *replaces* ADR-039 §7's macOS realization wholesale (native-fullscreen-Spaces → AeroSpace-owned workspaces; Hammerspoon geometry → AeroSpace tiling; new `aerospace-action` realization). On acceptance that is a §7 rewrite or superseding ADR — a heavier decision-state move than the prior iteration's planned amendment, recorded honestly.

## Prior art

- **AeroSpace (nikitabobko/AeroSpace)** — the leading candidate's tool and model: i3-style auto-tiling, no SIP, off-screen workspace emulation, TOML config. Its guide is the canonical statement of the workspace-ownership design this note's relaxation accepts.
- **niri** (this repo's Linux compositor) — the `niri-action` realization the proposed `aerospace-action` emitter parallels; the precedent that the registry already speaks action-verbs.
- **Hyprland** — the Linux destination the operator is weighing; the dwindle/i3 paradigm AeroSpace mirrors on macOS, and the endgame of the parity bonus (§Future).
- **yabai / Rectangle** — the `AXEnhancedUserInterface` resize workaround AeroSpace adopts (source credits both).
- The full verification survey (the approaches compared, the native-Spaces-conflict evidence, packaging) is suggested as a `docs/research/` companion (§Unresolved) rather than restated here.

## Unresolved questions

- **The live experiment (the de-risk gate — due diligence before committing config).** Trial `pkgs.aerospace` + a scratch `aerospace.toml` on neptune: confirm it runs under launchd on Tahoe/aarch64; the `programs.aerospace` schema vs our pinned HM rev (#6790); that the reclaimed `Ctrl+Opt` chords fire without collision; Electron tiling on the real app set; and — decisively — whether *living without native Spaces* is acceptable day-to-day. This resolves whether relaxing the negotiable constraints actually delivers the need.
- **App-launch binds: Hammerspoon vs `exec-and-forget`** — and whether Hammerspoon can be retired from the keybind layer entirely (Karabiner stays for Hyper regardless).
- **Event-tap coexistence.** AeroSpace and Hammerspoon both register global hotkeys; verify they don't fight on the kept app-launch chords — disjoint sets *should* be fine, but macOS event ordering needs on-box confirmation.
- **The `aerospace-action` emitter design** — build it paralleling `niri-action`; settle TOML binding-block generation into `programs.aerospace.settings`.
- **Packaging path** — `pkgs.aerospace` (Beta) vs the upstream-recommended cask (Homebrew tap-trust caveat); confirm the nixpkgs build runs before committing to it.
- **Capture the verification survey as `docs/research/macos-tiling-prior-art.md`?** Substantial and load-bearing; convention favours a research note this design cites. Suggested, not assumed — pending endorsement (scope discipline).
- **Out of scope:** multi-monitor (neptune is single-display today — defer); the Linux niri→Hyprland migration itself (a separate future exercise, not gated by this).

## Future possibilities

- **Hyprland on Linux — the parity endgame (sketched; explicitly *not* a goal of this cycle).** If the operator later migrates Linux from niri to Hyprland, the same Hyper scheme carries over largely intact, because AeroSpace and Hyprland are dwindle/BSP cousins — roughly: `focus`→`movefocus`, `move`→`movewindow`, `workspace N`→`workspace N`, `move-node-to-workspace`→`movetoworkspace`, `resize smart`→`resizeactive`, `fullscreen`→`fullscreen,0`, the layout toggles→`layoutmsg, togglesplit` / `togglegroup`, and the service-mode leader→a `submap`. Three AeroSpace-isms don't carry (`flatten-workspace-tree`, `close-all-but-current`, `join-with` — no dwindle equivalent). Notably `center`/`maximize` — *dropped* under AeroSpace — would be *revivable* under Hyprland (`centerwindow`, `fullscreen,1`), which is exactly why this note drops their darwin realization but **keeps the capability IDs**. This is a directional sketch only: Hyprland's config is actively shifting (e.g. `togglesplit`→`layoutmsg` at 0.54), so a real migration is a separate, freshly-verified exercise — held as a **limitation of the current design cycle** (we deliberately do not over-index on it; see §Unresolved out-of-scope).
- **Retire Hammerspoon from the keybind layer.** If app-launch binds migrate to AeroSpace `exec-and-forget`, Hammerspoon could be dropped entirely (Karabiner stays for Hyper) — shrinking the macOS interaction stack to Karabiner + AeroSpace.
- **A thicker shared keybind story.** With macOS on `aerospace-action` and Linux on `niri-action`, the registry could express more capabilities once and emit to both — tightening the single-source guarantee ADR-039 set out to deliver.
