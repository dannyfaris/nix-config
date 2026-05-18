# ADR-020: Work-vs-personal divergences expressed via import splits

**Date**: 2026-05-18
**Status**: Accepted

## Context

Mercury (ADR-017) is a work-only host. The UTM VM is a mixed personal/work host. The home-manager layer contains several modules whose contents differ along this axis: `git.nix` carries a dual personal/work identity on the VM but should carry a single work identity on Mercury, and `programs.gh` (the GitHub CLI) makes sense on the VM but not on Mercury (no GitHub workflow).

Two implementation patterns were considered. First: host-keyed `mkIf` flags inside a single module — `mkIf (hostContext.isWorkOnly) { … }` branches that gate the personal-side configuration. Second: split each affected module into pieces and let each host import the pieces it wants — `git.nix` (base, both hosts) + `git-identity-dual.nix` (VM only) + `git-identity-work.nix` (Mercury only) + `gh.nix` (VM only).

This is precisely the question PRD §3.2 already answers in the abstract for roles: "Where a role needs to choose between alternative tools, the choice is expressed as a choice of which module to import, not as a `mkDefault` setting an option." This ADR records that the same principle applies at the host level for work-vs-personal divergences, and the mechanism (`hostContext.extraHomeModules` from ADR-019) makes it ergonomic.

## Decision

Work-vs-personal divergences in shared modules are expressed by splitting the module into pieces and having each host import the pieces it wants, via `hostContext.extraHomeModules` (ADR-019). Host-keyed `mkIf` inside a single module is rejected.

Concretely for the current scope:

- `home/core/nixos/git.nix` is the base — `programs.git.enable`, `init.defaultBranch`, `pull.rebase`, the gitlab.com credential helper, glab as a package. Imported by every host via the standard imports list.
- `home/core/nixos/git-identity-dual.nix` is the personal-default + work-include identity, plus the `~/work` + `~/personal` activation script. The VM imports this via its `extraHomeModules`.
- `home/core/nixos/git-identity-work.nix` is the single-work identity plus the `~/work`-only activation script. Mercury imports this via its `extraHomeModules`.
- `home/core/nixos/gh.nix` is `programs.gh` and its HTTPS credential helper. The VM imports this; Mercury does not.

## Rationale

The `mkIf` alternative looked tempting because it would have kept the original `git.nix` as one file. But it doesn't actually keep things in one file once the divergence is real — the conditional branches and the option set they gate are the divergence, just expressed inline. The reader of a `mkIf`-laden module has to mentally project two different module evaluations (one for each branch) to know what either host actually runs. With the split, the reader of `git-identity-work.nix` sees exactly what Mercury runs, with nothing else competing for attention.

The split pattern also composes cleanly with PRD §3.2's existing role-level rule. Roles already pick which alternative module to import (e.g. a future `linux-workstation` role picking Niri vs Sway by importing one or the other). Extending the same shape to hosts within a role keeps the mental model consistent — "divergence = choice of import" — at both layers.

The cost of the split is more files. The PRD anticipated this (§5.1's directory tree shows pluralised module families), and at the current scale four files for git instead of one is a small price for the unambiguous-by-construction reading. If the split count grew to where individual files were each two or three lines, that would be over-decomposition and the right move would be to consolidate; that's not where we are.

`mkIf` is not banned in general — it has legitimate uses (toggling optional features within a single host's choice, conditional on an availability check). The rule applies specifically to host-keyed work-vs-personal axes.

## Consequences

- ✓ Reading `git-identity-work.nix` answers "what runs on Mercury" without having to know what the negated branches in a conditional would do. Each file declares one configuration, not two.
- ✓ Adding a new host with a different identity profile is "create a new identity file and import it via `extraHomeModules`", not "add a third branch to the existing mkIf cascade".
- ✓ Removing the personal-side configuration from Mercury is "don't import the gh module", not "set a flag that gates the import". The absent thing is unambiguously absent.
- ✗ Module count grows. For the git split this is 1 → 4 files. The names are explicit enough that the count is searchable rather than confusing, but the diff is noisy when reading the repo for the first time.
- ✗ The pattern requires `hostContext.extraHomeModules` (ADR-019) to exist. If that mechanism were removed, the splits would have to move into role-level imports instead.
- ⚠ Migration trigger: if the host-level extension surface (`extraHomeModules`) accumulates a dozen or more entries per host, that's a signal that the host file is doing too much composition and a host-specific role variant (e.g. `roles/headless-work.nix`) would be the cleaner shape. Not currently anticipated.

## Implementation

The split lives at `home/core/nixos/git.nix` + `git-identity-dual.nix` + `git-identity-work.nix` + `gh.nix`. Each host's `hosts/<host>/default.nix` declares its choices via `_module.args.hostContext.extraHomeModules`:

- nixos-vm: `[ ../../home/core/nixos/git-identity-dual.nix ../../home/core/nixos/gh.nix ]`
- mercury:  `[ ../../home/core/nixos/git-identity-work.nix ]`

The wiring file (`modules/core/nixos/home-manager.nix`) appends `extraHomeModules` to the standard imports list. The mechanism is the one documented in ADR-019; this ADR records the convention that it is the right tool for work-vs-personal divergences specifically, in preference to host-keyed conditionals.
