# ADR-029: niri-only desktop after DMS retraction

**Date**: 2026-05-29
**Status**: Accepted

> **Revision (2026-06-05):** stale module paths in this ADR were swept to the
> current flat layout (`home/core/…` → `home/…`, `modules/core/…` → `modules/…`)
> per [ADR-026](./ADR-026-drop-core-tier-prefix.md), which dropped the `core/`
> tier prefix. Navigability fix only — the decision recorded here is unchanged.

## Context

ADR-028 landed a coordinated three-part decision: Stylix in foundation; metis as the first desktop host via additive bundle composition; Dank Material Shell (DMS) as the metis shell. The §History 2026-05-29 amendment had already decoupled DMS theming from Stylix in response to the matugen-vs-GTK/Qt conflict surfaced during slice-3-readiness; that amendment kept DMS but disabled its dynamic theming (`programs.dank-material-shell.enableDynamicTheming = false`).

The slice-5 first activation on metis (2026-05-29 ~01:57 NZST, issue #67) reached greetd but login failed: greetd → niri-session blocked because niri.service didn't exist. The root cause was a niri-flake gap (the package ships systemd user units but the nixosModule doesn't register them); PR #68 closed that with `systemd.packages = [ config.programs.niri.package ]`.

The retry surfaced two new failures that ADR-028's design hadn't anticipated:

1. **niri-config parse failure.** DMS's `niri.includes.enable = true` generates `include "..."` directives in the niri config — but niri 25.08 does not recognise `include` as a top-level node. DMS's source explicitly comments this as a HACK pending [sodiboo/niri-flake#1548](https://github.com/sodiboo/niri-flake/pull/1548) (unmerged at the time of writing). Our niri-flake pin predates the PR. niri silently fell back to defaults; no binds, no shell.

2. **DMS shell crash.** DMS 1.5-beta's `shell.qml` uses `pragma AppId com.danklinux.dms`; the quickshell 0.2.1 in our nixpkgs closure does not recognise that pragma. The shell exited 255 × 5 → systemd start-limit-hit. The DMS shell did not run at all.

Both failures are upstream version-skew across DMS / quickshell / niri-flake. The operator's stance after triage: abandon DMS rather than ride bleeding-edge coordination across three projects with different release cadences. ADR-028's §History 2026-05-29 amendment had narrowed DMS's role; the slice-5 failures widened the gap further than incremental remediation could close.

## Decision

Retract the DMS portion of ADR-028. Preserve the rest.

**Retracted from ADR-028:**

- **§Decision item 3** ("DMS theming is decoupled from Stylix") — superseded. DMS is removed from the configuration entirely, not merely decoupled from Stylix's theme engine.
- **§Implementation slice 4** — already deferred indefinitely in the 2026-05-29 amendment; now formally closed.
- All DMS-specific scaffolding lands deleted from the code tree: `home/nixos/dms.nix`, `modules/nixos/dms-home-bridge.nix`, the `dank-material-shell` flake input, the corresponding imports from both `desktop-env` bundles.

**Preserved from ADR-028:**

- **§Decision item 1** — Stylix in foundation, per-host base16 palettes as the single source of truth for TUI / foot / GTK/Qt / niri-chrome theming. Stands.
- **§Decision item 2** — metis as the first desktop host via additive bundle composition. Stands.
- The niri compositor + foot terminal + greetd session entry remain the desktop stack. Stylix targets continue to cover the TUI surface and foot.

**New direction (replacing the "DMS as cohesive shell" framing):**

Per-tool selection. Each component (application launcher, notification daemon, status bar, browser, IDE) lands as its own deliberate selection captured in a `docs/desktop/<tool>.md` document with rationale, alternatives considered, sharp edges. The tracking lives in issues #72-#77 opened concurrent with #69's close-out. Cohesion is sacrificed for explicitness and per-tool stability.

The first two living documents (`docs/desktop/keybinds.md`, `docs/desktop/fonts.md`) landed during #69 and capture cross-cutting selections (keybinds + fonts respectively) on the same model.

## Rationale

**The version-skew pattern is structural, not a one-off.** DMS 1.5-beta is bleeding edge; nixpkgs's quickshell 0.2.1 trails; niri-flake's pinned niri-stable 25.08 trails further. NixOS rewards stable pinned inputs; an imperative rolling-release distro could ride this stack and survive on `paru -Syu` muscle memory. We cannot. Three independently-pinned upstreams with different release cadences means every minor bump risks new combinatorial failures. The slice-5 incidents (parse-failure + pragma-failure) were the third and fourth in a sequence — matugen-vs-GTK was the first, niri-flake's systemd-units gap was the second. The trend was unmistakable.

**Cohesion was the bet; it didn't pay.** DMS replaces three components (waybar + fuzzel + mako) with one project. That cohesion is real and aesthetically meaningful when it works. It pays back only if the upstream-coordination cost is acceptable. For a personal NixOS configuration with operator-as-only-user, the cost is the operator's own time fighting compatibility — which is not what the operator wants to do.

**Per-tool selection is more honest.** Each of waybar, fuzzel, mako, Firefox, Cursor is independently maintained, stably packaged in nixpkgs, and individually documentable. The doc-before-code rule established during #69 (`feedback_doc_before_code` memory) means each selection lands with its rationale and sharp edges captured. Per-tool decisions are smaller, more reversible, and easier to audit.

**No production-grade replacement at hand.** No equivalent of "DMS-but-stable" exists. The `tier3-desktop-deferred` git tag — waybar/fuzzel/mako/Stylix — IS the production-grade Linux Wayland desktop stack. Returning to it is not a defeat; it is recognising that the experiment did not displace it.

## Consequences

- ✓ Codebase reads as "niri-only by design" rather than carrying disabled DMS scaffolding indefinitely. Future contributors don't ask "why is this here disabled?"
- ✓ Upstream-coordination cost drops to per-component (waybar's nixpkgs release cadence, fuzzel's, etc.) rather than the cross-project burden.
- ✓ Per-tool selection model — captured in `docs/desktop/<tool>.md` per issue — produces durable per-component rationale.
- ✓ ADR-028's Stylix-foundation portion continues unchanged. The TUI surface, foot, and niri-chrome theming work as designed; the new per-tool selections layer on the same Stylix base.
- ✗ The desktop has no persistent status bar, application launcher, or notification daemon until the per-tool issues (#73, #74, #75) land. Slice-5 close-out delivered niri-only with foot and curated keybinds; everything beyond that is deliberate per-tool work.
- ✗ DMS's cohesion is a real loss — the operator loses single-project shell management until further notice. Reintroducing a DMS-like project is not foreclosed; if upstream version-skew resolves (DMS/quickshell/niri-flake align), the experiment may be reopened. No timeline.
- ✓ Closure size drops on metis: Qt6 + Quickshell + matugen-buildtime-dep + DMS shell.qml all leave the closure. Unambiguous win.
- ⚠ **Migration trigger 1 — DMS+quickshell+niri-flake stabilise.** If upstream version-coordination resolves (e.g. niri-flake#1548 merges + quickshell catches up with DMS's pragma) AND the operator wants to retry, reopen this decision. No automatic revisit.
- ⚠ **Migration trigger 2 — multiple desktop hosts.** ADR-028's §History 2026-05-29 amendment flagged that mothership arrival would be the natural moment to revisit per-host theming at the shell layer. With DMS abandoned, that revisit becomes "does the chosen replacement (waybar/etc.) support per-host palette signal?" rather than a DMS retry.

## Implementation

This ADR is decision-only. The code change is tracked under #70:

1. **ADR-029 + ADR-028 §History amendment + top-level docs sweep** — this PR.
2. **DMS scaffolding deletion** — separate PR. Deletes the two DMS module files, removes bundle imports, removes the `dank-material-shell` flake input.
3. **Stale-issue close-outs** — `gh issue close` operations on #33 (slice 3 framing) and #35 (slice 5 runbook). Resolution comment added to closed #67.

Per-tool selections (#72-#77) and the workflow-conventions doc (#78) are tracked as parallel work, not blocked by or blocking this ADR.

## References

- ADR-027 — foundation + bundles model; unchanged by this ADR.
- ADR-028 — partially superseded (§Decision item 3 retracted; §Implementation slice 4 formally closed; §Decision items 1+2 preserved).
- #67 — slice-5 first-activation incident (niri.service stub).
- PR #68 — niri-flake `systemd.packages` fix; closed #67.
- #69 — niri-only baseline close-out (4 PRs: #79 + #80 + #81 + #82). Acceptance criteria all met.
- #70 — this issue (DMS retraction + cleanup).
- #72-#77 — per-tool selection follow-ons.
- `docs/desktop/keybinds.md`, `docs/desktop/fonts.md` — first two living documents under the new `docs/desktop/` category; demonstrate the per-tool selection model.
- `tier3-desktop-deferred` git tag — older waybar/fuzzel/mako stack referenced in §Rationale ¶4; un-superseded by this ADR.
