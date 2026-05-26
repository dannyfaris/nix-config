# ADR-013: Composition framework — flake-parts with role-explicit imports

> **Amended by [ADR-027](./ADR-027-foundation-and-bundles.md) on 2026-05-27** for the role-layer sub-claim only. ADR-027 walks back the *role* abstraction (which this ADR introduced as the load-bearing composition unit) and replaces it with a foundation + capability-bundles model. The broader claims of this ADR — flake-parts as the organisational framework, **explicit imports over auto-discovery**, **whitelist over blanket**, **no premature abstraction**, and the directory grid (`core/`-vs-`experimental/` × `shared/`-vs-`nixos/`-vs-`darwin/`) — are unchanged and remain authoritative. References below to "roles" should be read in light of ADR-027: the composition mechanism is the same; the named structural unit has shifted from "role" to "foundation + bundles." Specifically, the "Single source of truth" framing in the Rationale ("the role file is the single answer to 'what does this kind of machine include'") shifts under ADR-027: the answer now lives in each host's import list (`foundation.nix` + opt-in bundles), not in a role file.

**Date**: 2026-05-14
**Status**: Accepted (with amendment per ADR-027)

## Context

The configuration manages multiple hosts across two platforms (NixOS and macOS), with overlapping but non-identical module sets per host. The prior flake configuration used explicit per-host import lists, which become bookkeeping overhead as the number of hosts grows.

The configuration needs a composition mechanism that:

- Lets a module's contents be reused across multiple hosts without duplication.
- Makes "what does this kind of machine include" answerable from the repository, not from human memory.
- Stays simple at the small-fleet scale this configuration is designed for (three roles, hosts in the low single digits per role).

Three composition approaches were considered:

- **Per-host explicit imports.** Each host file lists every module it includes. Simple but produces long, duplicate host files when hosts of the same kind share most modules.
- **Role-explicit imports.** Each *role* file lists its modules. Hosts adopt a role; the role's import list becomes the host's. Overlap between roles is mechanical (both role files import the same modules).
- **Dendritic auto-discovery.** A framework discovers every module file under `modules/` and imports them into every host; modules opt themselves in to specific hosts via `mkIf` on host attributes (typically role or hostname). Several reference Nix configurations (notably `mightyiam/infra`) use this pattern.

## Decision

Use `flake-parts` for flake organisation, with **role-explicit module composition**. Each role file (`roles/<role>.nix`) explicitly lists the modules that role includes; hosts adopt a role and optionally add further modules via the host's `imports` attribute. No auto-discovery; no per-module `mkIf` on host attributes as the load-bearing applicability mechanism.

Modules are organised into a project-level directory grid (`modules/core/`-vs-`modules/experimental/` × `shared/`-vs-`nixos/`-vs-`darwin/`, mirrored for `home/`) — see ADR-015 and PRD §5. The grid is a readability and lint-enforcement convention; it has no special meaning to flake-parts.

## Rationale

Dendritic auto-discovery is well-suited to configurations where there are many modules with many fine-grained applicability rules — the kind of configuration where each module deciding its own applicability is cheaper than maintaining lists. This configuration is the opposite: a small number of coarse-grained roles, with module overlap that's substantial within a role family but easy to enumerate.

Role-explicit imports also align better with the operating principles of this repository (`philosophy.md`):

- **Explicit over implicit.** A role file is a top-to-bottom manifest of what that role includes. Auto-discovery hides applicability inside module bodies.
- **Whitelist over blanket.** A role explicitly lists what it has; auto-discovery loads everything and lets modules opt themselves out via `mkIf false`.
- **No premature abstraction.** Auto-discovery earns its keep at a scale this configuration doesn't have.
- **Single source of truth.** The role file is the single answer to "what does this kind of machine include."

The cost of role-explicit composition is that a module which should apply to all three roles requires three role-file edits. At three roles, this is acceptable. If the number of roles grows substantially, profile-based composition (see ADR-014) becomes the natural refactor.

A note on terminology: this ADR supersedes an earlier draft titled "dendritic pattern." That title was inherited from reference configurations and was misleading — the mechanism actually adopted here is plain flake-parts with manual role-driven composition, not the dendritic pattern as such. The directory grid retained from the earlier draft is a project-level organisational convention, not a dendritic feature.

## Consequences

- ✓ Role files read top-to-bottom as "the modules this kind of machine includes."
- ✓ Module bodies are pure configuration — no `mkIf` guards on host attributes needed for role-level applicability.
- ✓ Adding a host of an existing role is small: a thin host file adopting the role.
- ✓ Debugging composition is straightforward — trace the import chain; no framework auto-discovery to reason about.
- ✓ Aligns with the repository's `philosophy.md` principles (explicit, whitelist, no premature abstraction).
- ✗ A module that applies to all three roles requires editing three role files. Minor at this scale.
- ✗ Overlap between `headless` and `linux-workstation` (significant per ADR-014) is maintained mechanically by both files importing the same modules.
- ⚠ Migration trigger: if the number of roles grows substantially and overlap maintenance becomes a real cost, profile-based composition (`roles/headless.nix` and `roles/linux-workstation.nix` both import from a `profiles/dev-environment.nix`) is the next step. Currently not anticipated.
- ⚠ Migration trigger: if the configuration ever adopts a much larger number of modules with much finer-grained applicability rules, the dendritic auto-discovery pattern becomes worth reconsidering. Currently not anticipated.

## Implementation

The flake uses `flake-parts` with explicit module composition. Role files live at the top of `roles/`; each is an attribute set whose `imports` list names the modules that role includes. The host-construction helper at `lib/mk-host.nix` reads the host's declared role, imports the role's module list, then layers the host's own `imports` and `experimental` opt-ins. See PRD §5 for the directory structure and §3 for the role-host model.

Optional tooling: a small tree-walking helper that populates a `flake.modules.<class>.<name>` namespace (allowing role files to write `imports = [ flake.modules.nixos.fish ]` instead of `imports = [ ../modules/core/nixos/fish.nix ]`) is available as sugar if reference-checking and autocomplete become useful. This is an implementation detail, not part of the architectural choice recorded here.
