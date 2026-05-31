# ADR-015: Stability tier — encoded as directory structure

> **Superseded by [ADR-026](./ADR-026-drop-core-tier-prefix.md) on 2026-05-31.** The tier-as-directory pattern is retracted. With the project mature enough to evaluate, no module had ever been classified experimental, and the enforceability rationale (a `tier-deps` lint that reduces to a path-based grep) was structural overhead with no inputs to enforce against. Module trees flatten to `modules/<platform>/...` and `home/<platform>/...`; the `tier-deps` lint, the promotion/removal procedures, and the experimental-vocabulary all fall out as a unit. The platform split (`shared/`-vs-`nixos/`-vs-`darwin/`) and the `philosophy.md` stability commitments survive. See ADR-026 for the full rationale and migration trigger.

**Date**: 2026-05-14
**Status**: Superseded by ADR-026

## Context

The configuration distinguishes between **core** modules (stable, proven, applied to all relevant role instances) and **experimental** modules (under evaluation, applied selectively, may be removed at any time). Core modules must not depend on experimental modules; experimental modules may depend on core. This constraint needs to be enforceable.

Two ways of encoding the tier were considered:

- **Tier as metadata.** Each module declares its tier as an attribute (e.g., `flake.modules.<system>.<name>.tier = "core"`). Tier is queryable from Nix but invisible from the file system.
- **Tier as directory.** Modules live under `modules/core/` or `modules/experimental/` (and similarly for `home/`). Tier is visible from the path.

The configuration is being built with structural enforcement as a load-bearing priority, including support for AI-driven development sessions in which conventions must be checkable deterministically without depending on session memory.

## Decision

Stability tier is encoded as directory structure. Core modules live under `modules/core/` and `home/core/`; experimental modules live under `modules/experimental/` and `home/experimental/`.

Promotion of an experimental module to core is performed by moving the file from `experimental/` to `core/` and updating references. Removal of a failed experiment is performed by deleting the file.

## Rationale

Tier-as-metadata makes the tier queryable from Nix but leaves it invisible from any view of the tree. A reader has to open a file to know its tier; a lint check enforcing the dependency rule ("core must not import experimental") would need to evaluate Nix expressions. The check is doable but slow and indirect.

Tier-as-directory makes the same information visible everywhere a path is visible — in diffs, in `ls`, in tree panes, in commit messages. The dependency rule reduces to a path-based grep: "no file under `modules/core/` imports a path under `modules/experimental/`." This is fast, deterministic, and trivial to script.

Promotion and removal also benefit. A file move shows up in a diff as a structural change, not a metadata edit. A deletion is unambiguous. The history of a module's tier transitions lives in `git log --follow`, not in a metadata field that has to be searched separately.

The cost is a slightly more elaborate directory shape (two parallel trees), which is a small price for the affordance.

## Consequences

- ✓ Tier is visible at a glance from any view of the file tree.
- ✓ The rule "core modules must not import experimental modules" maps directly to a path-based grep — no Nix evaluation required.
- ✓ Promotion is a deliberate, visible action with a clear git diff. The file move is itself a record of the decision.
- ✓ Failed experiments are removed cleanly by file deletion, leaving no residual metadata.
- ✓ AI agents working on the configuration can determine a module's tier from its path alone.
- ✗ Promotion requires updating any role file or host `imports` that references the module's old experimental path. With role-explicit composition (ADR-013), the touched files are visible from the import chain.
- ✗ Two parallel tree shapes (`core/` and `experimental/` mirroring each other) is slightly more directory structure than a single flat tree.
- ⚠ Migration trigger: a `deprecated/` tier could be added later if the need arises to phase out modules gradually rather than deleting them outright. Not currently planned.

## Implementation

The grid is implemented as plain directories under `modules/` and `home/`; see PRD §5.1 for the full tree. The `tier-deps` invariant (PRD §8.1) enforces the dependency rule. The promotion and removal procedures are defined in PRD §6.4, and scripted at `scripts/promote.sh` and `scripts/remove.sh`.
