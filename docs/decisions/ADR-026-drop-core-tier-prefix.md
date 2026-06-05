# ADR-026: Drop the `core/` tier prefix (walk back ADR-015)

**Date**: 2026-05-31
**Status**: Accepted, Implemented

> This ADR **supersedes [ADR-015](./ADR-015-tier-as-directory.md)** in full and **further amends [ADR-013](./ADR-013-composition-framework.md)** by retracting its directory-grid sub-claim (the `core/`-vs-`experimental/` axis only — the platform split `shared/`-vs-`nixos/`-vs-`darwin/` survives). The tier-as-directory pattern is retracted; module trees flatten to `modules/<platform>/...` and `home/<platform>/...`. The `tier-deps` lint (PRD §8.1 #2), the promotion/removal procedures (PRD §6.4 with `scripts/promote.sh` and `scripts/remove.sh`), and the entire "Stability tiers" PRD section (§6) become moot and are removed. No other ADR is affected — the platform split, foundation-and-bundles ([ADR-027](./ADR-027-foundation-and-bundles.md)), and host identity ([ADR-016](./ADR-016-host-identity.md)) all stand.

## Context

ADR-015 introduced tier-as-directory: a module's stability tier was to be encoded in its path, with `core/` for stable modules and `experimental/` for ones under evaluation. Its primary load-bearing rationale was *enforceability* — the dependency rule ("core must not import experimental") reduced to a path-based grep, fast and trivial to lint, with no Nix evaluation required. The `tier-deps` invariant (PRD §8.1 #2) is the concrete artefact this enabled.

With the project now mature enough to evaluate the structure, the data is unambiguous. Counts below are recursive (include each platform directory's `bundles/` subdirectory):

- `modules/core/nixos/` — 22 modules.
- `modules/core/shared/` — 3 modules.
- `home/core/nixos/` — 9 modules.
- `home/core/shared/` — 18 modules.
- `modules/experimental/` — does not exist.
- `home/experimental/` — does not exist.

No module has ever been classified experimental. The `core/` directory contrasts with nothing. The `tier-deps` lint has no work to do because no input it could flag has ever been written. Every import path in every host file pays five characters and one cognitive step ("core as opposed to what?") for an answer the repo has never had to give. The other half of the abstraction has neither materialised nor been requested.

This is structurally the same forecast-driven pattern that ADR-027 walked back for the role taxonomy: a categorical split anticipating a sibling that never arrived, paying interest immediately without delivering a payoff. The role layer was caught and corrected; the tier prefix was missed because its per-occurrence cost is small. Cumulative cost across hundreds of import paths and references is real.

## Decision

Flatten the module trees. Remove the `core/` segment from all module paths:

- `modules/core/nixos/` → `modules/nixos/`
- `modules/core/shared/` → `modules/shared/`
- `home/core/nixos/` → `home/nixos/`
- `home/core/shared/` → `home/shared/`

The platform split (`nixos/` vs `shared/`, with `darwin/` reserved for the planned macOS hosts) survives unchanged; it is populated bidirectionally on the realised axis and pays off if a non-NixOS host ever lands. The bundles subdirectory pattern (`modules/<platform>/bundles/`, `home/<platform>/bundles/`) and `foundation.nix` placement convention are preserved unchanged.

The `tier-deps` lint (PRD §8.1 #2), the `promote.sh` / `remove.sh` scripts (PRD §6.4), and the entirety of PRD §6 ("Stability tiers") become moot and are removed. ADR-013's amendment marker is extended to retract the directory-grid sub-claim that named `core/`-vs-`experimental/` as authoritative; the platform-split sub-claim survives.

If an experimental tier ever earns its place, it lands as a flat sibling at that point — `modules/experimental/<platform>/...` — added when it has actual content, not pre-reserved. Until then, the tree has one tier and no tier marker.

## Rationale

**ADR-015's primary argument was enforceability; the lint it enabled has no work to do.** The Rationale of ADR-015 leaned on the dependency rule reducing to a path-based grep — *"fast, deterministic, and trivial to script"*. That argument was correct at the time. But the value of an enforceable rule is proportional to how often it fires, and `tier-deps` has never fired because no experimental modules exist. An enforcement mechanism with no inputs to enforce against is structural overhead with no return. Removing the prefix removes the lint with it; nothing real is lost.

**The empty half of an abstraction is not free.** Every module path in the repo currently includes `core/`. Every host file's `imports` list, every doc cross-reference, every grep, every editor open, every code-review diff pays for an abstraction whose other half doesn't exist. Per-occurrence cost is low; per-repo cost is in the hundreds of occurrences and is paid every time anyone reads or writes the tree.

**This is the same shape as the role layer, caught smaller.** ADR-027 retracted the role taxonomy with the framing *"abstraction-by-forecast … paid interest immediately without delivering a payoff"*. The role layer was a layered abstraction with module-shaped overhead. The tier prefix is a directory-shaped abstraction with path-segment overhead. Both anticipate sibling content that never arrived. Walking back the larger one and not the smaller one is inconsistent.

**The "what if experimental modules arrive someday?" defence is forecast-driven.** Project philosophy explicitly rejects this pattern (`docs/philosophy.md` §"No premature abstraction; YAGNI"): *"Don't introduce a flag, a wrapper, or a layer until there's a concrete need."* `core/` is a layer introduced anticipating a need that hasn't surfaced. If `experimental/` ever earns its place, adding it then is a small change (a new top-level directory); pre-reserving its sibling structure today is the forecast-driven move.

**The "cost is low, so leave it" defence concedes the case.** If the abstraction is too cheap to warrant removing, it is also too cheap to be load-bearing — meaning it's contributing nothing and costing something. Either it earns its place or it doesn't. The honest answer is that it doesn't.

**The platform split survives because it is genuinely bidirectional.** `home/core/shared/` is populated with 18 modules; `home/core/nixos/` with 9; `modules/core/shared/` with 3 (`ghostty-terminfo`, `system-packages`, `editor-defaults`) and `modules/core/nixos/` with 22. Both halves of the platform abstraction do real work *today* on the `shared/` ↔ `nixos/` axis (the `darwin/` cell stays empty pending the planned macOS hosts; this is forecast on the platform axis, but separately defensible because the existing `shared/` contents are written to honour the cross-platform contract and will import unchanged when a Darwin host lands). The applicability claim a `shared/` path makes — *"this module is platform-agnostic; bringing up a non-NixOS host would import it unchanged"* — is testable, and the modules in `shared/` are written to honour it. The platform split is a forecast that earns its place via the genuine portability of its current contents; the tier split is a forecast that doesn't.

## Consequences

- ✓ Every import path shortens by `core/`. Host files, docs, grep output, editor displays all read cleaner.
- ✓ The abstraction the repo carries matches the abstraction the repo actually uses. One tier, no tier marker — honest by construction.
- ✓ The forecast-driven-abstraction principle is applied consistently across the repo. The same critique that retired the role layer retires the tier prefix.
- ✓ The `tier-deps` lint (PRD §8.1 #2) is removed; the lint surface shrinks. `bundle-purity` and `host-purity` retain their substance with updated path references.
- ✓ The PRD §6 "Stability tiers" section, the `promote.sh`/`remove.sh` scripts, and the experimental-promotion vocabulary fall out as a unit. Future tier reintroduction (if it ever earns its place) is a small additive change at the point of need — a new top-level directory, not a re-prefixing — and would be governed by a fresh ADR designed against the concrete need rather than the current forecast.
- ✗ Large mechanical churn: every host's `imports` list, every cross-reference in `docs/`, every reference in `CLAUDE.md`, every memory-file pointer, every header comment in module bodies (22 `.nix` files: 17 home + 5 system, verified by `grep -lr "core/" --include="*.nix"`), plus one adjacent script (`home/core/shared/claude-statusline.sh`) carry the rename. The diff is wide even though each change is trivial.
- ✗ CI infrastructure changes atomically with the flatten: `parts/checks.nix` (the `^(modules|home)/core/shared/.*\.nix$` regex used by `shared-purity`), `scripts/lint-shared-purity.sh`, and the deleted `tier-deps` invariant must move in the same commit as the rename or CI breaks mid-PR.
- ✗ In-flight branches and unmerged PRs touching files under `modules/core/...` will require rebase across the rename. Coordination is mostly mechanical (`git mv` + import-path updates) but not free.
- ✗ `git log` and `git blame` discontinuity at the rename boundary: file history reads cleanly only with `--follow` (CLI) or the "View blame prior to this change" link (GitHub web UI). Reviewers using the default UI will see a fresh history at the rename without realising they need to traverse.
- ✗ Outside cross-references (external docs, notes the operator keeps elsewhere, third-party links into `/blob/main/modules/core/...` paths) break and need manual updating. SHA-pinned permalinks survive.
- ✗ One historical reading of the repo (`core/` means "stable, mature, foundation-grade") is lost as a structural signal. Compensation: `philosophy.md` and the `docs/decisions/` index already encode the actual stability commitments of the repo, which is the more honest place for them.
- ⚠ Migration trigger to reconsider this decision: if `experimental/` plus a third tier (e.g. `deprecated/`, `staging/`) both arrive within ~12 months of this ADR landing, the flat-sibling pattern itself is suspect and a tier-prefix scheme could be revisited as a deliberate decision against the new concrete need. If the trigger never fires — or only `experimental/` arrives alone, which is additive evolution and not a migration — the removal was correct.

## Implementation

Multi-slice migration, mirroring ADR-027's slicing precedent. Each slice is independently peer-reviewable and lands in its own commit (and possibly its own PR). Descriptive documentation that *describes the codebase state* — `taxonomy.md`, `nix-config-prd.md`, module header comments — moves alongside or after the code, never ahead of it, to keep doc and code in lockstep.

1. **Slice 1a (this commit) — ADR-shaped meta only.** ADR-026 lands at status `Accepted, Implementation pending`. ADR-015's status updates to `Superseded by ADR-026` with a supersession marker at the top. ADR-013 receives a second amendment marker retracting the directory-grid sub-claim that named `core/`-vs-`experimental/` as authoritative; the platform-split sub-claim survives. `docs/decisions/README.md` index updates: ADR-015 row gains a `**Superseded by ADR-026**` marker; new row for ADR-026. *No descriptive docs (taxonomy.md, PRD) or code change in this slice.*

2. **Slice 1b — descriptive docs.** `docs/nix-config-prd.md` rewrite: §5.1 directory tree rewritten without `core/`/`experimental/`; §5.2 `core/`-vs-`experimental/` paragraph deleted; §5.3–§5.4 path references updated; §5.6 promote/remove script references deleted; §5.7 ADR list updated; §6 "Stability tiers" entire section deleted (sections renumber or §6 is left as a placeholder pointing to ADR-026 — decision deferred to slice-1b commit time, based on least churn); §7 path references updated; §8.1 `tier-deps` invariant (#2) removed and the remaining rows renumbered; `bundle-purity` (#4) and `host-purity` (#5) path references updated. `docs/taxonomy.md` updated to drop `core/` from all example paths and amend the historical-migration note to reference ADR-026. **Sliced after 1a but before 2 only if it makes review easier; the safer order is to fold 1b into slice 2 so descriptive docs and code change together** — final ordering decided at slice-2 implementation time based on diff size and reviewability.

3. **Slice 2 — flatten the tree (code change).** `git mv modules/core/nixos modules/nixos` (and the three siblings). The rename touches, in one atomic commit:
   - Every host's `imports` list (`hosts/*/default.nix`) including `hostContext.extraHomeModules` entries.
   - `lib/mk-host.nix` and `lib/host-palettes.nix` (header comments and any path references).
   - `parts/checks.nix` (the `shared-purity` lint regex `^(modules|home)/core/shared/...` and the deleted `tier-deps` rule).
   - `parts/formatter.nix`, `parts/dev-shells.nix`, `parts/nixos.nix` (header comments and path references).
   - `scripts/lint-shared-purity.sh` (regex + error messages). `scripts/promote.sh` and `scripts/remove.sh` are deleted (they implement the retired tier-promotion procedure from PRD §6.4).
   - `.github/workflows/ci.yaml` (comments referencing `core/` paths).
   - `CLAUDE.md` (cross-references to `modules/core/...` paths in the §Structure and §Conventions sections).
   - `docs/desktop/*.md` (all per-tool selection docs that reference module paths: README.md, foot.md, fonts.md, keybinds.md, niri.md, gnome-keyring.md, fuzzel.md, fnott.md, waybar.md, firefox.md).
   - `docs/runbooks/headless-bootstrap.md`.
   - Module body header comments that cross-reference sibling modules by path (17 home modules + 5 system modules carry such comments; verified by `grep -lr "core/" --include="*.nix"`), plus one adjacent script (`home/core/shared/claude-statusline.sh` line 15) that carries a path comment of the same shape.
   - The operator's `~/.claude/projects/-home-dbf-nix-config/memory/` files that reference `core/` paths.
   - `TODO.md` references (notably the `modules/core/darwin/` forecast entry).
   - If slice 1b was deferred: the `taxonomy.md` and PRD rewrites land here too, so descriptive docs match the post-flatten code in the same commit.

4. **Verification.** `nix store diff-closures` is empty per host across the move. `nix flake check` passes (including the renamed `shared-purity` lint matching at the new paths and the absence of `tier-deps` no longer producing a `flake check` failure). Peer-review-staged-diffs convention fires on each slice's staged diff before commit. Once slice 2 lands, ADR-026's status moves from `Accepted, Implementation pending` to `Accepted, Implemented`.

Coordination with open issue [#117](https://github.com/dannyfaris/nix-config/issues/117) (home-side baseline duplication): the two changes touch overlapping paths but don't conflict semantically. If #117 lands first, its artefacts get moved by commit 2 of this ADR. If this ADR's implementation lands first, #117 produces its artefacts at the flattened paths. No ordering constraint either way; the implementing session of whichever lands second performs the trivial path adjustment.

Filesystem layout after commit 2:

```
modules/
  nixos/
    foundation.nix
    bundles/
      remote-access.nix
      desktop-env.nix
    boot-systemd.nix
    btrfs-scrub.nix
    docker.nix
    firewall.nix
    ...
  shared/
    editor-defaults.nix
    ghostty-terminfo.nix
    system-packages.nix

home/
  nixos/
    bundles/
      desktop-env.nix
    macchina.nix
    niri.nix
    ...
  shared/
    bundles/
      cli-tooling.nix
      git-multi-identity.nix
      git-work.nix
    agent-clis.nix
    editor.nix
    shell.nix
    ...
```
