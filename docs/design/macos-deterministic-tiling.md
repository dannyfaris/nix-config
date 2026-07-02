# Deterministic window tiling on macOS

**Status:** Accepted — design note (`docs/design/`). Frames the **need** — deterministic window tiling on macOS — and splits requirements into *immovable* (the need + repo posture stances) vs *negotiable* (constraints that served our original "mimic niri/Linux" approach). Among the approaches explored, **AeroSpace was selected, and the choice was confirmed by a live Phase-A trial on neptune** (2026-06-29 → 2026-07-02, verdict **GO**): it clears the immovable forces while relaxing negotiable ones (native Spaces, niri-mimicry), and daily use showed that trade is worth taking. Supersedes this note's prior selection (Amethyst — PR #484) and its within-Space framing. The reversal of [ADR-039 §7](../decisions/ADR-039-capability-registry.md)'s macOS realization is recorded in [ADR-040](../decisions/ADR-040-macos-window-manager-aerospace.md); the Phase-B declarative implementation is [#494](https://github.com/dannyfaris/nix-config/issues/494). Trial corrections — the i3-flat paradigm, no scrollable columns, no stable maximize (maximise-by-isolation), the settled keymap, and the retire-Hammerspoon topology from the Ghostty-new-window spike — are folded into the sections below and marked *(trial)*.

## Summary

The need: **windows on macOS should tile automatically into a deterministic layout as they open** (the Hyprland pattern), rather than piling up to be hand-arranged. This note frames that need first and treats every workspace/Spaces decision as a *means* to it. We explored three approaches — native macOS tiling driven from keybinds (manual), Amethyst (auto-tiling *within* native Spaces), and AeroSpace (auto-tiling with a tiler-owned workspace layer) — and separate the requirements into **immovable** (the need itself, plus the repo's posture stances) and **negotiable** (the constraints that merely served our initial "mimic the niri/Linux experience on macOS" approach). AeroSpace clears every immovable force but breaks several negotiable ones (it owns workspaces instead of using native Spaces); because those constraints are negotiable, that was acceptable *provided a live trial showed the result was good enough to justify relaxing them*. The Phase-A trial showed exactly that (GO), so AeroSpace is the settled choice; Phase B ([#494](https://github.com/dannyfaris/nix-config/issues/494)) is its declarative implementation.

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

**Of the approaches explored, AeroSpace is the selected tool** — it clears every immovable force (1–5) while breaking negotiables 6–9 (it owns the workspace layer), and the Phase-A trial confirmed the relaxation is worth it. The other approaches and why they place lower are in Rationale; the mechanism, as settled by the trial:

**Tool + packaging.** Install via **`pkgs.aerospace`** (a real nixpkgs derivation, `aarch64-darwin`, built from the upstream release zip — not a cask wrapper), with the **`programs.aerospace`** home-manager module (`home/darwin/aerospace.nix`) owning the config: it renders a `settings` attrset to `~/.config/aerospace/aerospace.toml` and can manage the launchd agent so AeroSpace starts at login — fully declarative (immovable force 3), no Homebrew cask.

**Workspace model — the negotiated relaxation.** neptune runs a **single native macOS Space**; AeroSpace owns the workspace layer, emulating workspaces by parking inactive windows off-screen (no SIP — it does not drive the private Spaces API). This *relaxes* negotiables 6–8: native-fullscreen-Spaces navigation and the §7 stateless geometry handlers go away, replaced by AeroSpace's auto-tiling tree (`tiles`/`accordion` layouts, placement-on-open).

**Keybind remapping.** The change is layered; the substrate is untouched and most chords keep their *meaning*, changing only their *realization* to `aerospace-action`.

- **Substrate — unchanged.** Karabiner keeps producing Hyper (Caps→`Ctrl+Opt`, `tiers.hyper.darwin`); AeroSpace binds on `ctrl-alt-*`, so the chord it catches *is* Hyper. Shifting AeroSpace's default `alt`-based scheme onto Hyper is also strictly *better* than its default — bare Option stays free for special-character input (`⌥e` → é).
- **Delete the Karabiner Mission-Control layer.** The remaps that send `Hyper+arrows`/`Hyper+1‑9` to native Mission Control / Spaces are removed — along with `caps.karabinerHyperRemapKeys` and the `darwinReservedChords` it derives — which *frees* those chords for AeroSpace and drops their lint reservation.
- **Retire the 6 Hammerspoon geometry handlers** (`shrink/grow/snapPresetWidth/center/fullscreen/maximize`); manual geometry is superseded by AeroSpace's tiling. The trial confirmed them redundant.
- **AeroSpace claims both sets of chords** — those freed by deleting the Karabiner Mission-Control layer *and* those vacated by the retired Hammerspoon handlers — via a new `aerospace-action` realization (immovable force 4), mirroring the `niri-action` bind for the same capability ID. AeroSpace binds are *verbs* in its TOML `[mode.main.binding]` block — the same shape as `niri-action` — and accept `ctrl-alt` (§De-risk), so the Hyper chord maps directly. The trial settled the mapping below; Phase B ([#494](https://github.com/dannyfaris/nix-config/issues/494)) single-sources it through the `aerospace-action` emitter (simple verbs) with two hand-authored complex binds (edge-scroll, maximise-by-isolation):

| Chord | Capability (was) | → AeroSpace realization | Status *(trial-settled)* |
|---|---|---|---|
| `Hyper+←/→` | focus-column-left/right | edge-scroll fallthrough — `focus --boundaries-action fail` ` \|\| workspace --wrap-around` + land-far-column (hand-authored) | Remapped — *darwin-specific*, not a faithful `focus-column` mirror |
| `Hyper+↑/↓` | focus-window-up/down | `focus up/down` | Remapped |
| `Hyper+Shift+←/→/↑/↓` | move-* | `move left/right/up/down` | Remapped |
| `Hyper+1‑9` | focus-workspace-N | `workspace N` | Remapped — 1–9, see ¹ |
| `Hyper+Shift+1‑9` | move-to-workspace-N | `move-node-to-workspace N` | Remapped — 1–9, see ¹ |
| `Hyper+Tab` | overview | `workspace-back-and-forth` | Repurposed (no AeroSpace overview) |
| `Hyper+Shift+M` | maximize-column (niri-ism) | maximise-by-isolation — move to first empty workspace (hand-authored) | New — AeroSpace has no stable maximize |
| `Hyper+,` | — | `layout tiles accordion` (single toggle) | New |
| `Hyper+Shift+;` | — | `mode service` (modal leader for low-frequency ops) | New |
| `Hyper+Return` | spawn-terminal (was HS) | `exec-and-forget open -na Ghostty.app` (always a new window — the spike) | Remapped — **HS retired** |
| `Hyper+B` | spawn-browser (was HS) | `exec-and-forget open -a "Google Chrome"` | Remapped — **HS retired** |
| `Hyper+F` · `M` · `E` · `S` · `/` | fullscreen · maximize · — · — · — | `open -a` Finder · Messages · Outlook · Slack · 1Password | New — app-launch (reuses the freed geometry keys) |
| `Hyper+−` / `=` | shrink/grow (was HS) | — | **Dropped** — geometry is auto-tiled |
| `Hyper+R` · `C` · `Super+↑/↓` | preset-width · center · switch-workspace | — | **Dropped** — darwin N/A (capability IDs kept for Linux) |

¹ The trial exercised workspaces **1–4**; **Phase B binds all nine (1–9)** — an operator decision to extend, not a trial-settled count. The registry already generates the 1–9 workspace capabilities (`focusWorkspaces`/`moveToWorkspaces` over `lib.range 1 9` in `lib/capabilities.nix`), so nine is the natural emitter output.

- **Focus/move use the arrow keys only to start** (operator preference). AeroSpace's default `H/J/K/L` focus/move mirrors are a trivial later addition (and would re-align with the niri side's vim mirrors) — deferred, not adopted now.
- **Terminal-spawn topology — resolved by the Ghostty-new-window spike *(Phase-B Stage 0, 2026-07-02)*.** The trial de-fullscreened the two app-launch handlers (`Hyper+Return`, `Hyper+B`) so their spawned windows tile instead of taking a native Space; the open question was whether the terminal could spawn a **new window** without Hammerspoon (`Hyper+Return` must *always* open a new window; plain `open -a` only focuses). **Spike finding:** Ghostty's `+new-window` CLI action is **Linux/GTK-only** (its `gtk-single-instance` IPC), and macOS exposes no scriptable "new window in the running instance" — so `open -na Ghostty.app` (verified on-box) is the only Hammerspoon-free path, and it opens the window as a **new app instance each time** (process-per-window; synthesizing a single-instance Cmd+N would need Hammerspoon or an Accessibility grant). **Decision: retire Hammerspoon entirely** — accept the multi-instance model (mostly cosmetic under tiling: no Dock/app-switcher/tabs reliance), which shrinks the stack to **Karabiner + AeroSpace only** and closes both the HS launch-at-login gap and the event-tap coexistence question. So *all* app-launch becomes `aerospace-action exec-and-forget` (`open -na Ghostty.app` for the terminal, `open -a` for the rest). One paired Stage-1 setting makes the multi-instance model clean: **`quit-after-last-window-closed = true` in `home/darwin/ghostty.nix`** (macOS quits immediately — the delay knob is Linux-only), so each instance exits with its window instead of lingering windowless. Binds single-source through the registry, never a hand-split.
- **The three niri-isms** (`Hyper+R` preset-width-cycle, `Hyper+C` center, `Hyper+M` maximize) have no BSP equivalent: **drop their `platforms.darwin` realization** (a structural "darwin: N/A", not commented-out code — `deadnix` would flag the latter) but **keep the capability IDs** — the Linux side still uses them, and a future Hyprland move could re-realize `center`/`maximize` (§Future). Of their freed chords, `Hyper+M` is reused for `open -a Messages` app-launch (and maximise-by-isolation takes `Hyper+Shift+M`); `Hyper+R` and `Hyper+C` stay unbound initially.
- **Registry + lint.** The `aerospace-action` emitter parallels `niri-action`; dropping `darwinReservedChords` (empty `karabinerHyperRemapKeys` permanently) frees the chords and drops their reservation — single-sourcing (force 4) preserved. The duplicate-chord lint must extend to the **merged** namespace (emitted ∪ the two hand-authored complex binds), which the current within-emitter guard does not yet cover (§Unresolved). *(Multi-monitor binds omitted — neptune is single-display.)*

**How the forces are met.** Clears all immovables — auto-tiling on open (1, AeroSpace's core behaviour); no SIP (2, Accessibility-only); declarative (3, `pkgs.aerospace` + HM TOML, confirmed running under `nix profile` on Tahoe/aarch64 in the trial; Phase B moves to launchd); single-sourcing (4, via the `aerospace-action` emitter); Electron correctness (5, the `AXEnhancedUserInterface` workaround — confirmed tiling the real app set in the trial). On the **tiebreaker**, it is the most actively-maintained option (what separates it from Amethyst). It *breaks* negotiables 6–9 (owns workspaces, no native Spaces/fullscreen, not niri-scrollable) — acceptable by construction, and the trial confirmed the trade is worth it.

**Layout paradigm & its limits *(trial)*.** AeroSpace is **i3-style — flat siblings plus manual nesting (`join-with`), with an `accordion` mode — not dwindle/auto-BSP** like Hyprland. (Documentation elsewhere in this note that called it a "dwindle cousin" was wrong; corrected here and in §Future.) The sharpest standing limitation follows: **AeroSpace cannot do niri/PaperWM-style scrollable off-screen columns.** Only `tiles` (subdivide the visible screen — many windows *cram*) and `accordion` (stack; focused expands, the rest collapse to slivers). This is a permanent property, not a gap to close. The `Hyper+←/→` **edge-scroll fallthrough** reconstructs continuous scroll at *workspace* granularity (not column): at a workspace edge, `focus` exits non-zero, so the bind falls through to `workspace --wrap-around --no-stdin <next|prev>` and then focuses to the far column — a deliberate darwin-specific behaviour, *not* a faithful `focus-column-left` mirror.

**No stable maximize → maximise-by-isolation *(trial)*.** AeroSpace's only built-in maximize is `fullscreen`, which **silently drops on focus-change** (confirmed in its command docs), so it can't hold "give this window the whole screen." The focus-stable equivalent, bound on `Hyper+Shift+M`: if the focused window is alone on its workspace, no-op; else move it to the first empty workspace (focus follows). Note `move-node-to-workspace next` steps to the *adjacent* workspace whether occupied or not, so the empty target is computed via `list-workspaces --monitor focused --empty`. **Two trial-found bugs; Phase-B disposition:** (a) `list-windows --count` counts *floating* windows too, so a lone tiled window beside a floating one reads as ≥2 and still moves — **to be fixed in Stage 1 by filtering floating from the count**; (b) with no empty workspace left the move is a silent no-op — carried as a documented limitation. It is one-way (the window doesn't remember its origin — no free un-maximise); a reversible toggle is deferred unless daily use demands it.

**`exec-and-forget` gotchas — the emitter must bake these in *(trial)*.** `exec-and-forget` runs a bare `/bin/bash -c` with **no nix profile on `PATH`**, so `aerospace` must be called by an **absolute path** — and Phase B derives it from the package (`lib.getExe`/the app-bundle binary), *not* `$HOME/.nix-profile/bin/aerospace`, since that store-path staleness (a `nix profile upgrade` breaking the path) is exactly what the declarative module fixes. `workspace next|prev` (and any implicit-stdin subcommand) needs an explicit **`--no-stdin`** under `exec-and-forget` (no TTY; AeroSpace v0.20 forbids implicit stdin). And `exec-and-forget` **swallows errors → silent no-ops**, so every generated bind needs on-box verification (the CLAUDE.md runtime-verification rule).

## De-risk evidence

Verification began **documentary** — AeroSpace docs/README/source, nixpkgs, and the home-manager module, read 2026-06-29 — and was then **confirmed on-box by the Phase-A trial** (2026-06-29 → 2026-07-02, verdict **GO**). The trial ran `pkgs.aerospace` via `nix profile` with a scratch `aerospace.toml` and a representative Hyper keymap, and answered the load-bearing question — whether *relaxing the negotiable constraints* (chiefly: living without native Spaces) delivers the need acceptably in daily use. The full dated findings log is throwaway (the `trial/aerospace` branch, deleted at Phase-B teardown); its durable graduation is this note plus [ADR-040 §History](../decisions/ADR-040-macos-window-manager-aerospace.md).

- **AeroSpace owns workspaces / does not use native Spaces — confirmed (documentary).** Its guide: "reimplements Spaces and calls them Workspaces," parking inactive windows off-screen; "only have one macOS Space … and don't interact with macOS Spaces anymore." This is the model we are *accepting*, so the prior note's disqualifier becomes this note's premise.
- **No SIP — verified (README, source).** "Doesn't require disabling SIP … will never require you to disable SIP." Public Accessibility API + one private window-ID call; no Dock injection (the yabai SIP trigger).
- **Electron resize handled — verified (source).** `Sources/AppBundle/tree/MacApp.swift` reads `AXEnhancedUserInterface`, disables it, `setFrame`s synchronously, restores — crediting yabai commit `3fe4c77` and Rectangle PR #285.
- **Nix packaging — verified.** `pkgs.aerospace` at `pkgs/by-name/ae/aerospace/package.nix` (v0.20.x, `meta.platforms = darwin`, fetchzip, MIT); `programs.aerospace` in home-manager with `enable`/`package`/`launchd`/`settings` (attrset → TOML).
- **Activity vs Amethyst — verified (GitHub API, 2026-06-29).** AeroSpace ~21.4k stars, commits daily, last release v0.20.3-Beta (2026-03-08); Amethyst ~16.2k stars, last commit 2026-04-05. AeroSpace has the momentum — but is still self-labelled **Beta**.
- **Bindings accept arbitrary modifiers incl. `ctrl-alt` — confirmed (documentary).** `[mode.main.binding]` modifiers (`cmd/alt/ctrl/shift`) are freely combinable, so a Hyper (`Ctrl+Opt`) chord binds directly — load-bearing for the keybind-remap design.
- **Confirmed by the trial (GO):** (a) `pkgs.aerospace` runs and grants Accessibility on neptune (Tahoe/aarch64) — via `nix profile` + manual launch; the clean launchd/TCC path is the Phase-B packaging concern; (b) the reclaimed `Ctrl+Opt` chords fire without collision; (c) Electron tiling on the *actual* app set works; (d) — decisively — *living without native Spaces* is acceptable day-to-day; (e) app-launch resolves to `open -na`/`open -a`, and the **Ghostty-new-window spike (YES)** retires Hammerspoon entirely (no shared hotkeys → the event-tap coexistence question is moot).
- **Deferred to Phase B (#494) verification (declarative-adoption, not experience):** `pkgs.aerospace` as a proper menu-bar agent under **launchd** (the trial used `nix profile` + manual launch); the `programs.aerospace` `settings` schema against our pinned home-manager rev (HM issue #6790 flagged a config-schema breaking change — build against `settings`, and note `launchd.enable` forces `start-at-login = false` + empty `after-login-command`); and per-bind on-box verification (the `exec-and-forget` silent-no-op failure mode).

## Drawbacks

Reasons one might not pursue the need this way — or at all:

- **Relaxing the native-Spaces constraint has a real daily cost.** Abandoning native Spaces, native fullscreen, and Mission Control navigation is a large behavioural change and relearning, and a permanent divergence from stock-macOS muscle memory. This was the biggest reason-against; the trial weighed it directly and judged the need worth it (GO).
- **No scrollable columns.** AeroSpace's `tiles`/`accordion` can't reproduce niri/PaperWM off-screen column scrolling; the `Hyper+←/→` edge-scroll reconstructs it only at *workspace* granularity (§Design). A permanent trade, accepted.
- **Betting the daily-driver WM on a Beta.** AeroSpace is v0.20.x-Beta — active, but pre-1.0, and a WM is load-bearing all day.
- **The off-screen-emulation quirks are permanent**, not bugs to be fixed: Mission Control mis-sizes parked windows, inactive windows leave 1px slivers, and residual native fullscreen conflicts with the model (issues #238/#1615).
- **Couples the macOS experience to one upstream project** — far less fragile than a bespoke tiler, but a single (active) maintainer's pre-1.0 tool at the centre of the desktop.

## Cost

The accepted standing price, once AeroSpace is chosen: **a new `aerospace-action` emitter to build and maintain** in `lib/capabilities.nix` — modest, because it parallels the existing `niri-action` emitter, and partially offset by retiring the Hammerspoon geometry handlers. (The lived divergence from stock-macOS conventions is a *reason-against* the direction, weighed in Drawbacks, not a standing engineering price — so it is not restated here.)

## Rationale & alternatives

Approaches are weighed against the **immovable** forces (1–5); negotiables 6–10 are relaxable, so they do not decide the choice. Where two options both clear 1–5, the **maintenance tiebreaker** separates them:

- **AeroSpace (selected).** Clears all of 1–5; breaks 6–9. **Chosen** because it clears every immovable *and* wins the maintenance tiebreaker (most active, best-Nix-packaged), and breaking the negotiables was permitted once the trial earned it (GO). Note this reverses [ADR-039 §7](../decisions/ADR-039-capability-registry.md), which rejected AeroSpace as "i3 tree, not scrollable — wrong paradigm": scrollability was negotiable force 9 (niri-feel), so the paradigm objection dissolves once that constraint is relaxed. (The "i3 tree, not scrollable" *characterisation* was accurate — see §Design's no-scrollable-columns limitation — it was only the *disqualification* that rested on a negotiable.)
- **Amethyst (this note's prior selection, PR #484).** Also clears 1–5 *and* honours negotiables 6–8 (tiles within native Spaces). Its only edge over AeroSpace was a *negotiable* constraint — so once 6–8 are relaxable, that edge stops counting, and AeroSpace wins the maintenance tiebreaker and packaging (`pkgs.aerospace` + HM module vs cask + YAML). **Superseded** — it was the right pick only while 6–8 were (wrongly) treated as immovable.
- **Native macOS tiling driven from Hyper (manual).** Fails immovable force 1 (manual, not auto). It was the acceptable *intermediary*, never the destination. Rejected as an endpoint.
- **Bespoke Hammerspoon within-Space tiler.** Fails immovable force 5 (net-new fragile code we own; no prior art to fork). Rejected.
- **yabai.** Fails immovable force 2 (SIP). Rejected.
- **Do nothing (ADR-039 §7 status quo).** Fails force 1 (no auto-tiling). The fallback only if the trial shows AeroSpace's relaxations are intolerable in practice.

**On cross-platform convergence (negotiable force 10):** AeroSpace is selected on forces 1–5 *independently* of any Linux story. That it makes macOS converge with the niri/Linux action-verb model — and opens a path to macOS↔Linux parity if Linux later moves to Hyprland — is a genuine directional bonus, but it changes no head-to-head and partly rests on a future this note does not commit to. Weighed as a bonus, not a deciding force.

**Impact of doing nothing:** the standing need — deterministic auto-tiling — stays unmet.

**ADR relationship.** Adopting AeroSpace *replaces* ADR-039 §7's macOS realization wholesale (native-fullscreen-Spaces → AeroSpace-owned workspaces; Hammerspoon geometry → AeroSpace tiling; Hammerspoon retired; new `aerospace-action` realization). Because that reverses a *frozen* decision, it is recorded as a **superseding ADR — [ADR-040](../decisions/ADR-040-macos-window-manager-aerospace.md)** — following the ADR-028→029 pattern (a direction change gets a new ADR, not an in-place amendment), rather than a §7 rewrite.

## Prior art

- **AeroSpace (nikitabobko/AeroSpace)** — the selected tool and model: i3-style auto-tiling, no SIP, off-screen workspace emulation, TOML config. Its guide is the canonical statement of the workspace-ownership design this note's relaxation accepts.
- **niri** (this repo's Linux compositor) — the `niri-action` realization the `aerospace-action` emitter (Phase B) parallels; the precedent that the registry already speaks action-verbs.
- **Hyprland** — the Linux destination the operator is weighing (dwindle/auto-BSP — *unlike* AeroSpace's i3-flat manual tiling; the parity is at the verb level, not the layout paradigm — see §Future), and the endgame of the parity bonus.
- **yabai / Rectangle** — the `AXEnhancedUserInterface` resize workaround AeroSpace adopts (source credits both).
- The full verification survey (the approaches compared, the native-Spaces-conflict evidence, packaging) is suggested as a `docs/research/` companion (§Unresolved) rather than restated here.

## Unresolved questions

*Resolved by the trial (GO) — kept for provenance:* the live experiment (living without native Spaces is acceptable; the reclaimed `Ctrl+Opt` chords fire without collision; Electron tiles on the real app set); **app-launch binds** (settled on `exec-and-forget open -na`/`open -a`, and the Ghostty spike **retires Hammerspoon entirely**); **event-tap coexistence** (moot — no shared hotkeys); **packaging path** (`pkgs.aerospace` runs — the Beta nixpkgs build, not the cask). Open items carried into Phase B (#494):

- **The `aerospace-action` emitter design** — build it paralleling `niri-action` (add an `isAerospaceAction` predicate + an emitter mirroring `hammerspoonBindsFor`), emitting the simple verbs into `programs.aerospace.settings`; the two complex binds (edge-scroll, maximise-by-isolation) are hand-authored. The **collision guard must operate on the merged chord namespace** (emitted ∪ hand-authored), which the current within-emitter `darwinCollisionsFor` does not yet cover.
- **Focusing an off-workspace window.** With `open -a "Google Chrome"` (Hammerspoon's cross-Space focus-most-recent retired), verify that activating Chrome makes AeroSpace *follow* to the window's workspace rather than leaving focus split — an on-box Phase-B check.
- **Borders module shape.** `services.jankyborders` `settings` is a string block; interpolate the theme tokens with the `0x`+`ff`-alpha wrap. Confirm the exact option shape against the pin (a typed-option variant also exists — pick one).
- **`programs.aerospace` schema vs the pinned HM rev** (#6790) and **launchd** start-at-login (the trial used `nix profile` + manual launch).
- **Capture the verification survey as `docs/research/macos-tiling-prior-art.md`?** Substantial and load-bearing; convention favours a research note this design cites. Suggested, not assumed — pending endorsement (scope discipline).
- **Out of scope:** multi-monitor (neptune is single-display today — defer); the Linux niri→Hyprland migration itself (a separate future exercise, not gated by this).

## Future possibilities

- **Hyprland on Linux — the parity endgame (sketched; explicitly *not* a goal of this cycle).** If the operator later migrates Linux from niri to Hyprland, the same Hyper scheme carries over largely intact **at the action-verb level** — *not* because the layouts match (Hyprland is dwindle/auto-BSP; AeroSpace is i3-flat manual tiling — see §Design), but because the verbs map cleanly — roughly: `focus`→`movefocus`, `move`→`movewindow`, `workspace N`→`workspace N`, `move-node-to-workspace`→`movetoworkspace`, `resize smart`→`resizeactive`, `fullscreen`→`fullscreen,0`, the layout toggles→`layoutmsg, togglesplit` / `togglegroup`, and the service-mode leader→a `submap`. Three AeroSpace-isms don't carry (`flatten-workspace-tree`, `close-all-windows-but-current`, `join-with` — no dwindle equivalent). Notably `center`/`maximize` — *dropped* under AeroSpace — would be *revivable* under Hyprland (`centerwindow`, `fullscreen,1`), which is exactly why this note drops their darwin realization but **keeps the capability IDs**. This is a directional sketch only: Hyprland's config is actively shifting (e.g. `togglesplit`→`layoutmsg` at 0.54), so a real migration is a separate, freshly-verified exercise — held as a **limitation of the current design cycle** (we deliberately do not over-index on it; see §Unresolved out-of-scope).
- **~~Retire Hammerspoon from the keybind layer.~~ Realized this cycle** (no longer a future possibility): the Ghostty-new-window spike (§Design, §De-risk) let all app-launch move to AeroSpace `exec-and-forget`, so Hammerspoon is dropped entirely — the macOS interaction stack is now Karabiner + AeroSpace.
- **A thicker shared keybind story.** With macOS on `aerospace-action` and Linux on `niri-action`, the registry could express more capabilities once and emit to both — tightening the single-source guarantee ADR-039 set out to deliver.
