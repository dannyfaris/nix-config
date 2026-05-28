# ADR-028: Stylix in foundation; desktop environment arrives on metis

**Date**: 2026-05-28
**Status**: Accepted, Implementation pending

## Context

ADR-027 (foundation + bundles) landed an additive composition model in which a host's capabilities are expressed by which bundles it imports. The desktop environment has been the prototypical case the model was designed to absorb: under ADR-027, a host evolving from headless to desktop is `imports += [ bundles/desktop-env.nix ]`, not a role migration or category rename.

Two project facts have evolved together since ADR-027:

1. **Metis is operationally ready to be the first desktop host.** Originally bootstrapped as a personal dev box following the headless template (ADR-022 install, ADR-018 sops identity, ADR-027 composition). The hardware (HP ProDesk 600 G3 Desktop Mini, x86_64-linux, Intel iGPU) supports Wayland compositing natively — the constraint that justified deferring the desktop env (UTM's Apple Virtualization Framework lacks `EGL_EXT_device_drm`) doesn't apply to metis. Older planning named `mothership` as the first desktop host because no other x86_64 candidate existed at the time; metis's existence and capability change that.

2. **Dank Material Shell (DMS) supersedes most of the originally-planned shell layer.** The `tier3-desktop-deferred` git tag preserved a stack of `niri + waybar + fuzzel + mako + ghostty + stylix`. DMS — a Quickshell-based Material You shell — supersedes waybar (bar), fuzzel (launcher), and mako (notifications) into one coherent shell, and exposes a documented "custom theme" mode that lets an external palette source feed it directly.

Concurrently, where Stylix should live in the module tree has been an open question. Issue #4 framed Stylix as deferred-with-the-desktop, but that grouping was a project-organisation call rather than a technical constraint: most of Stylix's targets are TUI tools every host already runs. With the desktop now arriving on metis, the artificial separation between "Stylix for TUI" and "Stylix for desktop" disappears.

## Decision

Adopt a coordinated three-part decision, scoped to land as one ADR because the three parts are inseparable in motivation:

**1. Stylix is promoted to foundation, with per-host base16 palettes as the single source of truth for theming.** `inputs.stylix.nixosModules.stylix` is imported by `modules/core/nixos/foundation.nix`. A new `lib/host-palettes.nix` maps `hostName → base16-scheme-name`; foundation reads this map keyed on `hostContext.hostName` (the field name set by ADR-019). Missing-host lookups fail loudly at eval. Stylix governs all colour/font surfaces across both the TUI surface (helix, bat, zellij, starship, lazygit, yazi, btop, fish) and — via the wiring below — the desktop shell.

**2. Metis is the first desktop host.** A new `desktop-env` bundle at `modules/core/nixos/bundles/desktop-env.nix` aggregates the system-level desktop components (niri compositor enablement, greetd session entry, desktop fonts not already in foundation). A parallel `home/core/nixos/bundles/desktop-env.nix` aggregates the home-manager pieces (DMS, Ghostty, niri user config). Metis imports both bundles; mercury (work, headless) and nixos-vm (UTM, no DRM) do not.

**3. DMS reads its palette from Stylix.** A small home-manager module emits a DMS custom-theme JSON derivation from `config.lib.stylix.colors`, wired via `programs.dank-material-shell.settings.customThemeFile` + `currentThemeName = "custom"`, with `enableDynamicTheming = false` to suppress matugen. The base16 → Material 3 mapping is hand-rolled and lives next to the wiring module.

The desktop stack is **niri compositor + DMS shell + Ghostty terminal + greetd session entry + Stylix theming across both TUI and desktop surfaces.** Waybar, fuzzel, mako, and matugen do not enter the configuration — DMS replaces the first three; the fourth is suppressed via `enableDynamicTheming = false`.

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
3. **Slice 3 — desktop-env bundle scaffolding.** New `modules/core/nixos/bundles/desktop-env.nix` (niri + greetd + desktop fonts) and `home/core/nixos/bundles/desktop-env.nix` (niri user config + Ghostty + DMS). The home-side bundle directory `home/core/nixos/bundles/` is created as part of this slice (it does not exist yet; existing HM bundles live in `home/core/shared/bundles/`, but the desktop stack is Linux-only and belongs under `nixos/` per the shared-purity rule). Metis's `default.nix` adds both imports. Build-verify; no activation.
4. **Slice 4 — DMS↔Stylix theme wiring.** Standalone HM module emitting DMS custom-theme JSON from `config.lib.stylix.colors`; wire via `programs.dank-material-shell.settings`; document the base16→M3 mapping inline.
5. **Slice 5 — First activation on metis.** `nh os switch`. End-to-end verify: niri launches, DMS in metis palette, Ghostty themed, TUI surfaces match.
6. **Slice 6 (follow-up) — Issue #7 (Claude statusline) ceding colours to Stylix.** Another `config.lib.stylix.colors` consumer; independent of desktop work.

## References

- ADR-027 — foundation + bundles model that makes this additive.
- ADR-024 — claude-statusline precedent for build-time generated config from `config.lib.stylix.colors`.
- ADR-019 — `hostContext` flow used for per-host palette lookup.
- Issues #4, #6, #7, #17. #4 and #7 are downstream consumers of slice 2; #6 and #17 are independent runtime-signal layers that layer on top of this ADR's theming source.
- DMS docs — [CUSTOM_THEMES.md](https://github.com/AvengeMedia/DankMaterialShell/blob/master/docs/CUSTOM_THEMES.md), [home.nix module](https://github.com/AvengeMedia/DankMaterialShell/blob/master/distro/nix/home.nix), [Theme.qml singleton](https://github.com/AvengeMedia/DankMaterialShell/blob/master/quickshell/Common/Theme.qml).
- Stylix upstream — [issue #2031](https://github.com/nix-community/stylix/issues/2031), [PR #892 (draft)](https://github.com/nix-community/stylix/pull/892).
- `tier3-desktop-deferred` git tag — older waybar/fuzzel/mako stack; superseded.
