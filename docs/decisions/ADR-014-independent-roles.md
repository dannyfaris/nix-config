# ADR-014: Role composition — independent (not inherited)

**Date**: 2026-05-14
**Status**: Accepted

## Context

The configuration defines three roles: `headless`, `linux-workstation`, and `macos-workstation`. The `headless` and `linux-workstation` roles overlap substantially — a Linux workstation is, in functional terms, a headless dev environment plus a graphical layer. The `macos-workstation` role overlaps with the Linux roles on the development environment but diverges on platform-specific concerns.

Three composition models were considered for the relationship between roles:

- **Independent roles.** Each role directly imports the modules it needs from `modules/` and `home/`. Roles do not inherit from or extend each other. Overlap between roles is mechanical (both import the same modules), not architectural.
- **Layered roles.** Roles form a hierarchy in which one role extends another. `linux-workstation` would extend `headless`; `macos-workstation` would extend some common base.
- **Profile-based composition.** Roles compose from sub-role "profiles" (e.g., `profile/dev-environment`, `profile/gui-base`) that can be shared across roles without one role inheriting from another.

## Decision

Roles are independent compositions. Each role file directly imports its required modules. Roles do not inherit from each other or share parent abstractions.

Where roles need overlapping module sets, the overlap is expressed by both roles importing the same modules. The single source of truth for shared behaviour is the module itself, not a shared parent role.

## Rationale

Layered roles create an inheritance contract that constrains future changes: any divergence between `linux-workstation` and `headless` has to be expressed as an override or opt-out of the parent, which adds vocabulary and makes the actual content of a role harder to read top-to-bottom.

Profile-based composition is the better of the two abstractions — it avoids inheritance while still factoring shared module sets — but it adds an intermediate concept (profiles) for a configuration with only three roles. Profiles earn their place when the number of roles is large enough that mechanical overlap maintenance becomes a real cost; with three roles, that point has not been reached.

Independent roles trade a small amount of mechanical duplication (the overlap between `headless` and `linux-workstation` is maintained by both files importing the same modules) for a large simplicity gain: each role file reads top-to-bottom as "the modules this kind of machine includes," with no hidden inherited behaviour.

The risk of drift between roles is mitigated by the fact that *modules* — not roles — are the source of truth for behaviour. A role is a thin composition layer; a module is where decisions live. Two roles importing the same module get identical behaviour by construction.

## Consequences

- ✓ No inheritance chains; each role is self-contained and reads top-to-bottom.
- ✓ No coupling between roles: a change to one role cannot inadvertently affect another.
- ✓ The `macos-workstation` role doesn't have to fit awkwardly into a Linux-rooted hierarchy.
- ✓ Roles can deviate freely from each other when the deviation is justified, without breaking an inheritance contract.
- ✗ Overlap between roles must be maintained mechanically. A new module belonging in both `headless` and `linux-workstation` requires updating both role files.
- ✗ The "what's the same across roles" answer requires comparing role files rather than reading a single parent. Minor at three roles.
- ⚠ Migration trigger: if the number of roles grows substantially and overlap patterns become complex, profile-based composition can be reconsidered without changing how individual modules are structured.

## Implementation

Role files live at the top of `roles/`, one per role: `roles/headless.nix`, `roles/linux-workstation.nix`, `roles/macos-workstation.nix`. Each is a pure composition — module imports only, no inline configuration. See PRD §3.2 and §5.3.
