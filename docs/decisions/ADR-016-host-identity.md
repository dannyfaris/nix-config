# ADR-016: Host identity — stable per physical machine

**Date**: 2026-05-14
**Status**: Accepted

## Context

The configuration describes a collection of host instances. Each host has a directory under `hosts/<name>/` whose name is referenced from rebuild commands, lock-file entries, generation histories, and any tooling that resolves a configuration by host name.

A naming rule is needed because some host attributes are durable (this physical machine, this fully-allocated cloud instance) and some are not (its current role, its current owner, its form factor in the case of laptops that get upgraded). A naming convention that mixes the two will eventually produce a misnomer — for example, `mba` would survive a MacBook-Air-to-MacBook-Pro upgrade but become inaccurate, and a host named `dev-vps` would survive a re-purposing to "production demo" but become misleading.

## Decision

Host identity is **stable per physical machine** (or per fully-allocated long-lived cloud instance). The host directory's name refers to a specific machine, not to its current role or purpose. Names are durable across changes in role or purpose.

**Hardware-platform changes are treated as a different host.** Replacing a MacBook Air with a MacBook Pro, replacing a desktop motherboard, or provisioning new cloud infrastructure produces a new `hosts/<name>/` directory with a fresh name. Existing host directories are not renamed to follow hardware.

Initial host names — `mothership`, `mba`, `mac-mini` — are accepted under this rule: each refers unambiguously to the current physical machine. When the underlying hardware is replaced, the replacement gets its own host directory with a fresh name (chosen from a stable naming theme), and the prior host directory may be retired.

## Rationale

The benefit being captured: a host directory's history — its rebuild log, its `hardware-configuration.nix` evolution, its generation history — is bound to a single physical machine. Renaming the host on a hardware change would either (a) break that binding and lose history, or (b) silently associate the old machine's history with the new machine, which is misleading.

Treating hardware replacement as a new host preserves both. The old machine's directory remains an honest record; the new machine starts fresh. The cost is some redundancy when the configuration is largely re-used across the two (often the new host's `default.nix` is a copy of the old one with hardware bits regenerated), but the redundancy is small and the audit trail is clearer.

A host's name is therefore a property of the machine itself, not of its current job. A renamed-on-purpose-change host would be the same kind of confusion in the other direction.

The rule is not enforced by lint — it's a naming convention, judgment-based. Lint can't tell whether `mba` refers to the original Air or a replacement Pro.

## Consequences

- ✓ Host directory history is bound to a single physical machine and never has to be reconciled across hardware changes.
- ✓ No mid-life rename ever needed: a host's name is set once when its directory is created.
- ✓ The cognitive overhead of "is this still the right name?" is removed — names don't have to keep up with software changes.
- ✗ Hardware replacements require choosing a new name. For a small fleet this is a minor task.
- ✗ The initial names are ad-hoc (a mix of descriptive — `mac-mini` — and themed — `mothership`). Accepted as honest: names are not load-bearing beyond identifying the physical machine, and forcing a unifying convention for the sake of consistency wouldn't pay off at this scale.
- ⚠ Migration trigger: if the configuration grows to a fleet large enough that ad-hoc names become hard to remember, adopting a structured theme (with the current hosts re-keyed at the same time) is reasonable. None currently anticipated.

## Implementation

Host directories live under `hosts/<name>/`; see PRD §5.4 for the directory contents and §5.5 for the naming convention. New host directories are created when new physical machines are added; existing directories are never renamed in place.
