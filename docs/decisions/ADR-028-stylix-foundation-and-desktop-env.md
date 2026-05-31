# ADR-028: Stylix in foundation; desktop environment arrives on metis

**Date**: 2026-05-28
**Status**: Amended by ADR-029 (item 3 retracted; items 1–2 stand and are implemented)

## Context

ADR-027 (foundation + bundles) landed an additive composition model in which a host's capabilities are expressed by which bundles it imports. The desktop environment has been the prototypical case the model was designed to absorb: under ADR-027, a host evolving from headless to desktop is `imports += [ bundles/desktop-env.nix ]`, not a role migration or category rename.

Two project facts have evolved together since ADR-027:

1. **Metis is operationally ready to be the first desktop host.** Originally bootstrapped as a personal dev box following the headless template (ADR-022 install, ADR-018 sops identity, ADR-027 composition). The hardware (HP ProDesk 600 G3 Desktop Mini, x86_64-linux, Intel iGPU) supports Wayland compositing natively — the constraint that justified deferring the desktop env (UTM's Apple Virtualization Framework lacks `EGL_EXT_device_drm`) doesn't apply to metis. Older planning named `mothership` as the first desktop host because no other x86_64 candidate existed at the time; metis's existence and capability change that.

2. **Dank Material Shell (DMS) supersedes most of the originally-planned shell layer.** The `tier3-desktop-deferred` git tag preserved a stack of `niri + waybar + fuzzel + mako + ghostty + stylix`. DMS — a Quickshell-based Material You shell — supersedes waybar (bar), fuzzel (launcher), and mako (notifications) into one coherent shell, and exposes a documented "custom theme" mode that lets an external palette source feed it directly.

Concurrently, where Stylix should live in the module tree has been an open question. Issue #4 framed Stylix as deferred-with-the-desktop, but that grouping was a project-organisation call rather than a technical constraint: most of Stylix's targets are TUI tools every host already runs. With the desktop now arriving on metis, the artificial separation between "Stylix for TUI" and "Stylix for desktop" disappears.

## Decision

Adopt a coordinated three-part decision, scoped to land as one ADR because the three parts are inseparable in motivation:

**1. Stylix is promoted to foundation, with per-host base16 palettes as the single source of truth for theming.** `inputs.stylix.nixosModules.stylix` is imported by `modules/core/nixos/foundation.nix`. A new `lib/host-palettes.nix` maps `hostName → base16-scheme-name`; foundation reads this map keyed on `hostContext.hostName` (the field name set by ADR-019). Missing-host lookups fail loudly at eval. Stylix governs all colour/font surfaces across both the TUI surface (helix, bat, zellij, starship, lazygit, yazi, btop, fish) and — via the wiring below — the desktop shell.

**2. Metis is the first desktop host.** A new `desktop-env` bundle at `modules/core/nixos/bundles/desktop-env.nix` aggregates the system-level desktop components (niri compositor enablement, greetd session entry, desktop fonts not already in foundation). A parallel `home/core/nixos/bundles/desktop-env.nix` aggregates the home-manager pieces (DMS, Foot, niri user config). Metis imports both bundles; mercury (work, headless) and nixos-vm (UTM, no DRM) do not.

**3. DMS theming is decoupled from Stylix** (decision rebased then retracted 2026-05-29; see §History entries below — fully retracted per ADR-029). DMS uses its own built-in palette and runtime wallpaper picker. `programs.dank-material-shell.enableDynamicTheming = false` suppresses matugen so it doesn't fight Stylix's GTK/Qt targets. `stylix.image` is not set on DMS-driven hosts; Stylix has no wallpaper consumer there. Stylix remains canonical for the TUI surface, foot terminal, GTK/Qt apps, and niri focus-ring/cursor.

The desktop stack is **niri compositor + DMS shell + Foot terminal + greetd session entry + Stylix theming across the TUI surface, foot, GTK/Qt apps, and niri focus-ring/cursor.** Waybar, fuzzel, mako, and matugen do not enter the configuration — DMS replaces the first three; the fourth is suppressed via `programs.dank-material-shell.enableDynamicTheming = false` so it doesn't fight Stylix's GTK/Qt targets. (Foot supersedes the originally-named Ghostty for the Linux desktop; see §History. DMS theming was originally planned as a Stylix consumer; that bridge is deferred indefinitely — see §History.)

## Rationale

**The Stylix question and the desktop question collapse into one.** Issue #4 argued for pulling Stylix into foundation "for TUI theming, with desktop targets coming for free later when mothership arrives." That framing made sense while the desktop was a remote eventuality. Once metis is the imminent first desktop, the two halves are the same decision; splitting them into separate ADRs would be process for its own sake.

**Metis-first inverts a constraint, not a choice.** The desktop env's deferral was always conditional on "x86_64 hardware exists." Metis is the x86_64 host. Naming `mothership` as the first desktop host in older planning was placeholder, not commitment: at the time, no x86_64 host existed and `mothership` was the named slot. Metis filling that slot first is a re-binding of the placeholder, not a re-decision of the design.

**DMS over waybar/fuzzel/mako is a strict simplification.** Three modules collapse into one cohesive shell. DMS's design language matches the visual coherence Stylix targets — it doesn't fight Stylix, it consumes a palette and presents it. The alternative (waybar + fuzzel + mako, individually Stylix-themed) would deliver less while maintaining more configuration.

**Stylix-canonical DMS theming preserves single-source-of-truth.** Three patterns were considered for Stylix↔DMS:
- Shared image, two derivations — both engines read `stylix.image`; visually divergent palettes, no Nix-side coordination.
- Stylix seeds matugen — pick a base16 colour as a matugen seed; M3-shaped palette ungrounded in base16's specifics.
- Stylix-canonical, emit DMS theme directly — `config.lib.stylix.colors → pkgs.writeText JSON → DMS customThemeFile`. Stylix is unambiguously canonical; DMS is a downstream consumer with no parallel theme engine running.

The third pattern matches philosophy.md's single-source-of-truth principle. The "consumer reads an artifact `home.file`-deployed by Nix" shape is already established by ADR-024 (claude-statusline); what is new here is sourcing that artifact's content from `config.lib.stylix.colors` at evaluation time. Issue #7 is the sibling that applies the same from-Stylix-colors derivation to the claude statusline; this ADR's slice 4 and #7's work are structurally identical, just targeting different consumers.

**No production-grade prior art exists for Stylix→DMS.** Research found no Nix wiring between the two; the closest adjacent work (Stylix→matugen, [nix-community/stylix#2031](https://github.com/nix-community/stylix/issues/2031)) is in draft and not expected before mid-2026. The mapping is genuinely new work, but the surface is small: DMS's custom-theme schema is ~16 required M3 tokens, documented at [docs/CUSTOM_THEMES.md](https://github.com/AvengeMedia/DankMaterialShell/blob/master/docs/CUSTOM_THEMES.md), and the official DMS Nix home module exposes `programs.dank-material-shell.settings` as the wiring surface.

**The base16 → M3 mapping is lossy by construction; the choice is which losses to take.** Base16 has 16 positional slots; M3 has ~20 named semantic tokens (primary, on-primary, surface families, outline, etc.). No bijection exists. The mapping is a hand-rolled aesthetic call documented next to the wiring module. Acceptable because (a) Stylix is unambiguously canonical; (b) the mapping changes only when the operator wants different aesthetics, not in response to upstream churn; (c) the alternative ("matugen-canonical, Stylix downstream") inverts the upstream chain in a way the rest of the repo's theming wouldn't follow.

**Greetd over autologin or display-manager-less boot.** Metis is a personal device; the operator sits at it. Display-manager-less boot offers no advantage. Autologin is rejected because metis carries SSH keys, sops identity, and 1Password data; the lock screen is the cheapest first defence against passers-by, and the session-start cost is one passphrase.

## Consequences

- ✓ Metis acquires the desktop by adding two bundles. No host file rename, no role migration, no PRD contradiction — ADR-027's design pays off. (ADR-027 sketched a future `desktop-apps` bundle alongside `desktop-env`; that split is deferred until apps actually need grouping per the rule-of-two-with-intent-to-grow.)
- ✓ One theme source (`config.lib.stylix.colors`) drives TUI surfaces and DMS shell. New themable surfaces require emitting one more derived config file from the same source.
- ✓ Stylix-in-foundation serves both TUI hosts (mercury, nixos-vm) and the new desktop host (metis) with one promotion; no separate "Stylix for desktop" effort later.
- ✓ The SSH-context signal stack (issues #4, #6, #7, #17) is unblocked: layers driven by `config.lib.stylix.colors` (TUI palette, macchina banner, claude-statusline) get their source-of-truth import in place. Issues #6 and #17 supply the runtime text/glyph layers; they are independent of this ADR's prereqs but layer on top of its theming source.
- ✓ DMS-on-Stylix is novel and worth publishing back to nix-community as a Stylix custom target once the mapping settles. Out of scope for this ADR; flagged as follow-up.
- ✗ Closure grows on metis: Qt6 + Quickshell + matugen (buildtime dep even with dynamic theming off) + fonts + greetd. Unchanged on mercury and nixos-vm.
- ✗ The base16 → M3 mapping is a hand-rolled aesthetic call. Each base16 scheme assigned to a host requires an eyeball pass on rendered DMS palette.
- ✗ DMS upstream is fast-moving (master pushed daily). The 16-key custom-theme schema has been stable across recent releases but is not contractually frozen.
- ✗ Stylix tracks `nixos-unstable`; nixpkgs pin divergence can break Stylix targets. Unchanged risk from the unpromoted state, just now on the critical path.
- ⚠ **Migration trigger 1 — DMS schema drift.** New required keys would break the generated JSON. Pin DMS flake input; re-verify schema at each upgrade.
- ⚠ **Migration trigger 2 — Stylix→matugen upstream lands.** If [stylix#892](https://github.com/nix-community/stylix/pull/892) merges, revisit and consume Material You tokens directly rather than hand-mapped base16, eliminating the lossy mapping.
- ⚠ **Migration trigger 3 — mothership arrives.** The `desktop-env` bundles already exist; `lib/host-palettes.nix` gets a new entry. Additive.

## Implementation

Decision-only landing; implementation in subsequent slices, each peer-reviewed on staged diff with operator sign-off before commit. Issue #17 (host-glyph starship prompt) is independent of this ADR and may land at any point.

1. **Slice 1 (this PR) — Documentation reconciliation.** ADR-028 authored; `docs/decisions/README.md` lifecycle convention; CLAUDE.md / PRD / TODO.md framing updates; issue #4 body update. No code changes.
2. **Slice 2 — Stylix in foundation, TUI targets.** Stylix flake input; `lib/host-palettes.nix` (metis, mercury, nixos-vm); foundation import; HM-side Stylix targets for existing TUI tools; macchina banner recolour. Hard prereq for slices 3–5.
3. **Slice 3 — desktop-env bundle scaffolding.** New `modules/core/nixos/bundles/desktop-env.nix` (niri + greetd + desktop fonts) and `home/core/nixos/bundles/desktop-env.nix` (niri user config + Foot + DMS). The home-side bundle directory `home/core/nixos/bundles/` is created as part of this slice (it does not exist yet; existing HM bundles live in `home/core/shared/bundles/`, but the desktop stack is Linux-only and belongs under `nixos/` per the shared-purity rule). Metis's `default.nix` adds both imports. Build-verify; no activation.
4. **Slice 4 — DMS↔Stylix theme wiring [retracted per ADR-029; see §History 2026-05-29 (DMS retracted)].** Originally planned as a standalone HM module emitting DMS custom-theme JSON from `config.lib.stylix.colors`. Decoupled from Stylix on 2026-05-29 then retracted entirely on the same date when DMS was removed from the configuration. Slice numbering preserved for archaeological consistency.
5. **Slice 5 — First activation on metis.** `nh os switch`. End-to-end verify: niri launches, DMS in metis palette, Foot themed, TUI surfaces match.
6. **Slice 6 (follow-up) — Issue #7 (Claude statusline) ceding colours to Stylix.** Another `config.lib.stylix.colors` consumer; independent of desktop work.

## References

- ADR-027 — foundation + bundles model that makes this additive.
- ADR-024 — claude-statusline precedent for build-time generated config from `config.lib.stylix.colors`.
- ADR-019 — `hostContext` flow used for per-host palette lookup.
- Issues #4, #6, #7, #17. #4 and #7 are downstream consumers of slice 2; #6 and #17 are independent runtime-signal layers that layer on top of this ADR's theming source.
- DMS docs — [CUSTOM_THEMES.md](https://github.com/AvengeMedia/DankMaterialShell/blob/master/docs/CUSTOM_THEMES.md), [home.nix module](https://github.com/AvengeMedia/DankMaterialShell/blob/master/distro/nix/home.nix), [Theme.qml singleton](https://github.com/AvengeMedia/DankMaterialShell/blob/master/quickshell/Common/Theme.qml).
- Stylix upstream — [issue #2031](https://github.com/nix-community/stylix/issues/2031), [PR #892 (draft)](https://github.com/nix-community/stylix/pull/892).
- `tier3-desktop-deferred` git tag — older waybar/fuzzel/mako stack; superseded.

## History

### Terminal swapped from Ghostty to Foot (2026-05-28)

The original Decision named **Ghostty** as the metis terminal — inherited
from the `tier3-desktop-deferred` stack and carried unexamined into
this ADR. Slice 3 scaffolded a `programs.ghostty.enable = true` module
on metis (PR #55).

Caught while drafting a prior-art research prompt for slice 4: the
operator's actual intent is **Foot** on Linux desktop hosts, with
Ghostty reserved for macOS clients. The original ADR text propagated
the wrong terminal through Decision, Implementation, and Consequences.
Slice 3 had landed but slice 4 had not, so the surgery is bounded:
replace `ghostty.nix` with `foot.nix`, swap the `Mod+T → ghostty`
keybind to `Mod+Return → foot` (also taking the moment to use the
tiling-WM-canonical `Mod+Return` for terminal-launch), and amend the
ADR + companion docs to match.

**Rationale for Foot over Ghostty on Linux desktop:**

- Foot is Wayland-native; doesn't carry the GPU-accelerated TUI
  feature surface Ghostty brings (less of which is needed inside niri,
  which already does compositor-level GPU work).
- Foot's closure is meaningfully smaller — no embedded scripting
  runtime, no platform abstraction layer.
- Foot is the historical "lightweight first-class Wayland terminal"
  in the niri/wlroots/sway lineage; aligns with niri's design
  philosophy. ADR-011's earlier remote-dev-QoL note already
  anticipated "linux-workstation lands with foot" — that anticipation
  is now reality.
- Ghostty is retained on **macOS clients** (operator's Mac) and via
  the unchanged `modules/core/shared/ghostty-terminfo.nix` standalone
  module, which ships the `xterm-ghostty` terminfo entry on every
  host so SSH'ing in from a Ghostty-on-Mac terminal renders cleanly.
  The Ghostty client posture (Mac → SSH → any host) is untouched.
- A future `home/core/darwin/` tree (per the mac-mini onboarding
  epic, #11) will add `programs.ghostty.enable` for Darwin hosts.
  The Linux/Darwin split is now: Linux desktop uses Foot, macOS uses
  Ghostty.

Files touched: see the amendment commit (`git log --grep "metis terminal"`).
Note: line 14's reference to the `tier3-desktop-deferred` git tag is preserved
verbatim because it accurately describes a historical artefact, not the
current decision. Stylix's `foot` target is enabled centrally in
`home/core/shared/bundles/theming.nix` alongside the other TUI targets
(inert on non-desktop hosts because Stylix gates the target on
`programs.foot.enable`).

### DMS theming decoupled from Stylix (2026-05-29)

The original Decision (item 3 above) named **DMS** as a downstream
Stylix consumer, with slice 4 to deliver a custom-theme JSON bridge
emitting from `config.lib.stylix.colors`. Slice 3 landed without
slice 4, and slice 4 itself never started.

Deferring slice 4 indefinitely. Rationale:

- **Aesthetic-only payoff, not load-bearing.** The bridge would make
  the DMS bar/launcher/notification surfaces shift palette with the
  host's base16 scheme. Useful when there are multiple desktop hosts
  to distinguish (e.g. tab between metis and mothership); pays off
  precisely zero today since metis is the only desktop host. The
  per-host SSH-context signal value (cited in Consequences above)
  applies at the TUI layer for remote work, not at the DMS-shell
  layer for local work.

- **Cost was real.** The base16 → M3 mapping is lossy by construction
  (16 positional slots vs ~20 named semantic tokens); the §Rationale
  paragraph above documents the lossiness. Each host's palette would
  need an eyeball pass on the rendered DMS surface. DMS's schema
  expanded across v1.x — `settings: allow custom json to render all
  theme options` shipped in v1.4.4 — so the field set is live-mutating
  and would require tracking.

- **Pattern misfit.** Stylix-consumer modules are downstream readers
  of `config.lib.stylix.colors` (the macchina banner and Claude
  statusline are precedents). DMS doesn't quite fit: it ships its own
  theme engine (matugen) that we would have to actively suppress on
  every host that imports the bundle. The integration is an
  always-on subtraction, not an additive consumer.

- **No production-grade prior art at decision time; one reference has
  since surfaced.** The §Rationale paragraph "No production-grade
  prior art exists for Stylix→DMS" was accurate when written; the
  closest public reference (otherdelusions/nixos-config) was found
  during slice-4 research and its mapping disagrees with the table
  this ADR sketched in 9 of ~18 token assignments. Choosing among
  aesthetically-defensible mappings is not the work the operator
  wants to spend their time on for a single-desktop-host setup.

**Revised framing.** Stylix is canonical for the TUI surface (helix,
bat, fzf, starship, zellij, yazi, lazygit, fish), foot terminal,
GTK/Qt apps, niri focus-ring/cursor, macchina banner, and Claude
Code statusline. **DMS is self-contained for its shell theme and
wallpaper.** `programs.dank-material-shell.enableDynamicTheming =
false` is load-bearing — it's the single gate in DMS's
`distro/nix/common.nix:19` that prevents matugen from running
against the wallpaper and writing files
(`~/.config/gtk-{3,4}.0/dank-colors.css`,
`~/.config/qt{5,6}ct/colors/matugen.conf`) that would conflict with
Stylix's GTK/Qt targets.

`stylix.image` is intentionally not set anywhere in the
configuration. Stylix has no wallpaper consumer on a DMS-driven host
(DMS provides its own runtime wallpaper picker; tuigreet has no
graphical background; DMS owns the lock screen). On headless hosts
(mercury, nixos-vm), `stylix.image` would be dead weight.

**Consequences specific to this amendment.**

- Slice 4 (issue #34) closes as deferred. No bridge module ships.
- Two original §Consequences become moot: "Closure grows on metis:
  ... + matugen (buildtime dep even with dynamic theming off)" is no
  longer relevant because matugen is now suppressed by the
  `enableDynamicTheming` gate before reaching the closure;
  "Migration trigger 2 — Stylix→matugen upstream lands" is no longer
  a trigger because we no longer have a Stylix↔DMS interface to
  revisit.
- Migration trigger 1 (DMS schema drift) and trigger 3 (mothership
  arrives) still stand. Mothership arrival is the natural moment to
  revisit slice 4 — at two desktop hosts, the per-host signal at the
  DMS-shell layer starts paying off.
- ADR-028's "single source of truth for theming" claim becomes
  **scoped** rather than universal: Stylix is canonical for
  Stylix-target-bearing surfaces, not for shell engines that own
  their own theme system.

The corresponding code change (adding
`programs.dank-material-shell.enableDynamicTheming = false` to
`home/core/nixos/dms.nix` plus a header-comment rewrite, alongside
two other slice-5-readiness hardening edits) lands in a separate
follow-up PR. This amendment is docs-only.

### DMS retracted; per-tool selection model adopted (2026-05-29)

The Decision (item 3 above) named DMS as the metis shell; the
amendment immediately above narrowed DMS's role to "Stylix-decoupled
but still present." This amendment goes further: **DMS is retracted
from the configuration entirely.** See [ADR-029](./ADR-029-niri-only-desktop.md)
for the full retraction record.

The retraction was triggered by the slice-5 first-activation on
metis (issue #67), which surfaced two upstream version-skew failures
that the 2026-05-29 decoupling amendment above had not anticipated:

1. DMS's `niri.includes.enable = true` generates `include "..."`
   directives that niri 25.08 does not parse (DMS source explicitly
   comments this as a HACK pending [sodiboo/niri-flake#1548](https://github.com/sodiboo/niri-flake/pull/1548)
   — unmerged at the time of writing). niri silently fell back to
   defaults; no binds, no shell.
2. DMS 1.5-beta's `shell.qml` uses `pragma AppId com.danklinux.dms`,
   which the nixpkgs-pinned quickshell 0.2.1 does not recognise. The
   shell exited 255 × 5 → systemd start-limit-hit.

Both failures are structural — three independently-pinned upstreams
with different release cadences. The operator's stance after triage:
retract DMS rather than continue incremental remediation.

**Retracted from this ADR:**
- §Decision item 3 ("DMS theming is decoupled from Stylix") —
  superseded; DMS removed entirely, not merely decoupled.
- §Implementation slice 4 — formally closed.

**Preserved from this ADR:**
- §Decision items 1 and 2 stand unchanged (Stylix in foundation;
  metis as the first desktop host via additive bundle composition).
- The niri compositor + foot terminal + greetd session entry remain
  the desktop stack. Stylix targets continue to cover the TUI
  surface, foot, GTK/Qt apps, and niri focus-ring/cursor.

**New direction:** per-tool selection. Each component (application
launcher, notification daemon, status bar, browser, IDE) lands with
its own selection rationale in `docs/desktop/<tool>.md`. The first
two living documents (`docs/desktop/keybinds.md`,
`docs/desktop/fonts.md`) landed during issue #69's close-out
(PRs #79 + #80 + #81 + #82). Per-tool follow-on work is tracked in
issues #72–#77.

The corresponding code change — deleting `home/core/nixos/dms.nix`,
`modules/core/nixos/dms-home-bridge.nix`, the `dank-material-shell`
flake input, and the bundle imports from both `desktop-env` bundles
— ships in a separate follow-up PR under issue #70. This amendment
is docs-only.

### Stylix palette moved from foundation into stylix-palette.nix (2026-05-31)

Decision item 1 above placed Stylix in foundation by importing
`inputs.stylix.nixosModules.stylix` *and setting the per-host palette
inline* in `modules/core/nixos/foundation.nix`. That inline block
violated ADR-027's `bundle-purity` rule (foundation must be a pure
`imports` list), a contradiction that surfaced when #54 P5.1 went to
build the enforcing lint.

The stylix module import and the per-host `base16Scheme` lookup now live
in a dedicated `modules/core/nixos/stylix-palette.nix`, which foundation
imports. **Decision items 1 and 2 are unchanged in substance** — Stylix
is still foundation-wide (every host imports foundation, which imports
stylix-palette.nix), and the per-host base16 palette from
`lib/host-palettes.nix` is still the single source of truth. Only the
*placement* of the wiring moved, so foundation stays a uniform
imports-list aggregator. Full rationale and the alternatives weighed are
in ADR-027 §History (2026-05-31). This amendment is docs-only; the code
change ships under #54.
