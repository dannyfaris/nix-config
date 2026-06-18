# Architecture Decision Records (ADRs)

This directory captures every load-bearing decision shaping this nix config.
Each ADR is a self-contained document with the context, the decision, the
rationale, and honest consequences.

## Format

We use a **light ADR format**:

```markdown
# ADR-NNN: [Title]

**Date**: YYYY-MM-DD
**Status**: Accepted, Implementation pending   # or Accepted, Implemented / Superseded by ADR-XXX / Amended by ADR-XXX / Withdrawn

## Context
[The forces driving the decision — project constraints, user preferences,
prior decisions that constrain this one. ~1 short paragraph.]

## Decision
[What we chose, 1–2 paragraphs.]

## Rationale
[The load-bearing reasoning — why this option over alternatives. The
honest comparison with rejected options.]

## Consequences
- ✓ [positive outcome]
- ✓ [positive outcome]
- ✗ [honest negative tradeoff]
- ⚠ [migration trigger — circumstances that would make this decision
   worth revisiting]

## Implementation
[Brief: which module file(s), key idioms, load-bearing config snippets.]
```

The shape is intentionally light: enough structure to make ADRs scannable
and consistent, but not so much that small decisions feel over-formalised.

## Index

| # | Topic | Choice | Summary |
|---|-------|--------|---------|
| [001](./ADR-001-shell.md) | Shell | fish | Interactive shell; chosen for clean out-of-box UX |
| [002](./ADR-002-prompt.md) | Prompt | starship | Declarative TOML; nix-shell indicator was the deciding factor |
| [003](./ADR-003-direnv.md) | Per-project envs | direnv + nix-direnv | Standard nix dev-shell activation pattern |
| [004](./ADR-004-multiplexer.md) | Multiplexer | zellij | Discoverable status bar; modern out-of-box UX |
| [005](./ADR-005-editor.md) | Editor | helix | Batteries-included; selection-first model |
| [006](./ADR-006-cli-utilities.md) | CLI utilities | rg, fd, fzf, bat, eza, zoxide, lazygit, lazydocker, yazi, htop, dust, jq | Modern Unix replacements |
| [007](./ADR-007-nix-tooling.md) | Nix tooling | nh, nom, nixd, nixfmt, statix, deadnix | Modern overlay on nix UX |
| [008](./ADR-008-agent-clis.md) | AI coding agents | Claude Code + Cursor (base), Codex + Gemini (extras) | OAuth login flows; extras opt-in per host |
| [009](./ADR-009-git.md) | Git | dual identity, HTTPS+token | personal/work split via gitdir; HTTPS via gh/glab credential helpers |
| [010](./ADR-010-ssh.md) | SSH | defaults only | Outbound key generation deferred (HTTPS git removes the need) |
| [011](./ADR-011-remote-dev-qol.md) | Remote-dev QoL | ~~mosh~~ + OSC52 | OSC52 cross-machine clipboard (mosh removed, #47 — session resilience now via SSH + zellij) |
| [012](./ADR-012-taxonomy.md) | Module taxonomy | Most-communicative term | The naming rule itself, as a meta-decision |
| [013](./ADR-013-composition-framework.md) | Composition framework | flake-parts + role-explicit imports | Roles list modules explicitly; no auto-discovery. **Amended by ADR-027** (role layer walked back; explicit-imports philosophy preserved) |
| [014](./ADR-014-independent-roles.md) | Role composition | independent, not inherited | Each role imports modules directly; no shared parents. **Superseded by ADR-027** (role layer removed entirely) |
| [015](./ADR-015-tier-as-directory.md) | Stability tier | encoded as directory | `core/` vs `experimental/` in the path. **Superseded by ADR-026** (tier-as-directory walked back; no module was ever classified experimental and the enforceability rationale had no inputs to enforce against). |
| [016](./ADR-016-host-identity.md) | Host identity | stable per physical machine | Hardware change = new host; software role change = no rename |
| [017](./ADR-017-headless-bootstrap-aws-ami.md) | Headless bootstrap (AWS) | NixOS AMI + amazon-image module | **Superseded by ADR-022.** Resolves PRD §12 deferral; chose AMI over nixos-anywhere/disko at the time (path changed when Mercury became an in-place Ubuntu conversion) |
| [018](./ADR-018-headless-secrets-sops.md) | Headless secrets | sops-nix | Resolves PRD §12 deferral; same pattern as the VM. **Amended by ADR-022** (host-key acquisition order) |
| [019](./ADR-019-host-parametrisation.md) | Per-host parametrisation | `_module.args.hostContext` + `extraSpecialArgs` | Per-host values reach home-manager modules via the function-arg forwarder |
| [020](./ADR-020-role-overlap-via-import-splits.md) | Work-vs-personal divergences | import splits, not host-keyed `mkIf` | One file = one configuration; choice expressed by which modules a host imports |
| [021](./ADR-021-docker-on-headless.md) | Docker on headless | rootless daemon, system-wide CLI, per-host opt-in | Resolves ADR-006's deferred daemon decision; host-level opt-in (Mercury + Metis), not in foundation or a bundle |
| [022](./ADR-022-headless-bootstrap-nixos-anywhere.md) | Headless bootstrap (revised) | `nixos-anywhere` + `disko`, pre-injected host keys | Supersedes ADR-017; amends ADR-018. One install path across AWS + bare metal |
| [023](./ADR-023-host-config-three-file-structure.md) | Per-host file structure | `default.nix` / `disko.nix` / `hardware-configuration.nix` | Each file has a single ownership story; eliminates the mixed-content `hardware.nix` |
| [024](./ADR-024-claude-code-config.md) | Claude Code config | home.file deploy, settings.json mutable | Stable config files sync via Nix; per-host settings.json edit references them |
| [025](./ADR-025-ci-in-flake.md) | Continuous integration | flake-defined `nix flake check` + GitHub Actions matrix | Every check is a flake output; CI is thin YAML; `.githooks/` replaced by `git-hooks.nix` installed by devShell. Realises ADR-023's planned banner-check enforcement |
| [026](./ADR-026-drop-core-tier-prefix.md) | Module path prefix | `core/` removed | Flattens `modules/core/...` → `modules/...` and `home/core/...` → `home/...`. Supersedes ADR-015; further amends ADR-013 (directory-grid sub-claim). `tier-deps` lint and PRD §6 fall out. |
| [027](./ADR-027-foundation-and-bundles.md) | Composition model (replaces roles) | foundation + capability bundles | `roles/` removed; each host imports `foundation.nix` + opt-in bundles. Supersedes ADR-014; amends ADR-013 |
| [028](./ADR-028-stylix-foundation-and-desktop-env.md) | Theming + desktop env | Stylix in foundation; desktop arrives on metis | **Amended by ADR-029** (item 3 retracted; items 1–2 stand and are implemented) **and ADR-036** (§item 1 — Stylix no longer the Linux-desktop source of truth; stands on every other host). Niri + Foot + greetd; Stylix-canonical for TUI / foot / GTK / Qt / niri chrome. |
| [029](./ADR-029-niri-only-desktop.md) | Desktop after DMS retraction | niri-only; per-tool selection model | Retracts ADR-028 §Decision item 3 (DMS) + §Implementation slice 4. Preserves ADR-028 §Decision items 1–2. Per-tool selections (#72–#77) land as `docs/desktop/<tool>.md` per issue; first two living documents (`keybinds.md`, `fonts.md`) landed during #69. **Amended by ADR-036** (a cohesive shell — Noctalia — returns to the Linux desktop; the status-bar/launcher/notification/lock selections are subsumed there). |
| [030](./ADR-030-nixpkgs-channel.md) | nixpkgs channel | `nixos-unstable`, weekly flake-lock | Records the existing choice; weekly bump PR with manual merge after green CI. Aligns with Stylix + niri-flake + home-manager all tracking unstable. Migration triggers named for Darwin onboarding and repeated Stylix breakage. |
| [031](./ADR-031-nix-homebrew-boundary.md) | Darwin cask boundary | nix-homebrew + cask + MAS | When something lands in Homebrew vs nixpkgs vs the Mac App Store; declarative cask list, Sparkle silent-update stance. Per-app mechanism details live in `docs/desktop/`. |
| [032](./ADR-032-proportionate-enforcement-and-rationale.md) | Meta-layer proportionality | proportionate enforcement + single-sourced rationale | Turns the repo's "no premature abstraction" + "single source of truth" principles onto its own linters/CI and rationale prose: lightest mechanism that holds the guarantee; rationale lives in one canonical home with pointers elsewhere. |
| [033](./ADR-033-eval-checks-stances-and-lib-units.md) | Stance + lib eval checks | assert deliberate stances; unit-test `lib/` | Adds eval-only `flake.checks`: per-host assertions that the CLAUDE.md deliberate stances still hold (so a weakened stance fails CI instead of auto-merging), plus `lib.runTests` coverage of `lib/auto-gen-paths.nix`. Property tests ruled out; NixOS VM behavioural tests deferred. |
| [034](./ADR-034-no-host-data-backup.md) | Host-data backup | out of scope — reprovision-from-source | Deliberate non-adoption: no restic/borg/snapshots. Recovery from host loss is reprovision-from-flake plus the homes durable data already has (git, 1Password, cloud, the off-band sops identity). Only metis `/home` + mac-mini home hold non-reproducible data; the residual (uncommitted WIP) is accepted. Migration trigger if irreplaceable local-only data accumulates. |
| [035](./ADR-035-runtime-theme-polarity.md) | Runtime theme/polarity (metis) | ~~tinty delta over the Stylix base~~ | **Superseded by ADR-036.** Proposed tinty as the first runtime/session-state layer selecting theme+polarity over Stylix's build-time base; retired before implementation when Noctalia (ADR-036) was adopted to own the runtime flip on the Linux desktop — the surface this targeted. Design record retained for the declarative/runtime-state reasoning. |
| [036](./ADR-036-noctalia-shell-linux-desktop.md) | Cohesive Wayland shell (Linux desktop) | Noctalia v4 as shell + sole theming authority | Adopts Noctalia (v4 Quickshell line) on the Linux desktop as one cohesive shell (bar/launcher/notifications/lock/OSD/wallpaper/idle) **and** the sole theming authority there: Stylix + curated palette retreat to every other host. Confronts ADR-029's DMS version-skew retraction (single flake-pinned shell + own `noctalia-qs` runtime + compositor-spawn + no `include` injection). Supersedes ADR-035; amends ADR-029 + ADR-028 §item 1. Qt returns to the Linux desktop (conscious walk-back); v5 the Qt-free migration target. |
| [037](./ADR-037-doc-mutability-contracts.md) | Documentation contracts | facts as code, reasons as prose | **Accepted, Implementation pending.** Classifies every doc artifact (incl. CLAUDE.md) by mutability: facts generated/checked, reasons single-sourced prose, decisions in the tracker, only load-bearing why a frozen ADR. Grep-lint rung committed; heavier enforcement on evidence. (Renumbered 036→037 on merge of #385 — the Noctalia ADR holds 036, created first.) |

## Conventions

- **Sequential numbering, padded to three digits.** Easier sorting; reads
  right; gives room to grow.
- **Filename convention**: `ADR-NNN-<topic>.md` where `<topic>` is a
  short kebab-case slug.
- **Status reflects lifecycle.** ADRs move: `Proposed` → `Accepted, Implementation pending` → `Accepted, Implemented`. Terminal states: `Superseded by ADR-XXX`, `Amended by ADR-XXX`, `Withdrawn`. Once an ADR's decision lands in code, the ADR is immutable historical record — don't delete or rewrite; use `Superseded` (contradicting replacement) or `Amended` (extending augmentation) via a new ADR when the decision needs to change. Before implementation, the ADR is plan-state and may be revised freely in response to new information. `Withdrawn` is for ADRs revised so substantially before implementation that preserving the original would mislead — withdraw with a pointer, author fresh.
- **Existing ADRs (001 through 027) carry bare `Accepted`.** Grandfathered as `Accepted, Implemented` unless the ADR's own Implementation section indicates otherwise. New ADRs use the lifecycle states above from the outset.
- **Date** is the date of the original decision, not the date of writing.
  When backfilling ADRs from earlier conversations, use the conversation
  date.

## Adding a new ADR

1. Pick the next number.
2. Copy the format block above.
3. Write the four substantive sections honestly. The Consequences section is
   the test — if you can't articulate negatives or migration triggers, the
   decision probably isn't worth an ADR.
4. Update this index.
5. Cross-reference from `philosophy.md` or `taxonomy.md` if the ADR touches
   either.
6. If the new ADR supersedes an old one, edit the old one's status and add
   the pointer.
