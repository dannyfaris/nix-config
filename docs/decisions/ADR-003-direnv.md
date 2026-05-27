# ADR-003: Per-project environments — direnv + nix-direnv

**Date**: 2026-05-06
**Status**: Accepted

## Context

A nix dev box benefits enormously from per-project tool isolation: each
project declares its own toolchain (rust, node, python, system libs,
formatters, LSPs) in its `flake.nix`, and that toolchain is available
*only* in that project. The mechanism for activating those per-project
toolchains automatically is direnv, with the nix-direnv extension that
adds a `use flake` directive.

Without this, the alternatives are: install everything globally (version
conflicts, polluted environment) or manually source environment scripts on
every directory entry (forgettable, prone to leakage).

## Decision

**direnv + nix-direnv** are both enabled via `programs.direnv` and
`programs.direnv.nix-direnv` in home-manager. Per-project workflow: each
project gets a `flake.nix` declaring its `devShells.default`, plus a
one-line `.envrc` containing `use flake`.

## Rationale

This is effectively the standard nix-on-linux dev workflow; there's no
serious alternative. The decision is about whether to adopt the standard,
not which option to pick.

The alternatives were: manual `nix develop` invocations on entry (high
friction, easy to forget), global toolchains (version conflict pain, leaks
between projects), or per-project shell scripts that source environments
(reinvents direnv badly).

direnv with nix-direnv solves the activation problem invisibly. Combined
with starship's nix-shell indicator (ADR-002), it gives the user a
keyboard-driven, visible, transparent per-project workflow: `cd` into a
project, environment activates, prompt updates, tools become available; `cd`
out, environment deactivates, prompt updates, tools disappear.

nix-direnv specifically (vs. plain direnv) is the magic: the `use flake`
directive activates a `nix develop` shell, with caching that makes
subsequent re-entries instant.

## Consequences

- ✓ Per-project toolchains, isolated and reproducible.
- ✓ Home-manager package list stays minimal — only tools wanted *everywhere*
  belong there. Per-project tools live in each project's flake.
- ✓ Multiple projects with conflicting tool versions coexist without manual
  juggling.
- ✓ Machines become disposable: clone a project, `direnv allow`, you have
  the exact toolchain.
- ✓ Editor LSPs invoked from inside the project pick up the project's
  toolchain automatically (PATH inheritance).
- ✗ First entry into a new directory requires an explicit `direnv allow` (a
  security gate against running arbitrary `.envrc` from random directories).
  This is correct behaviour, not a problem, but worth knowing.
- ⚠ No anticipated migration trigger. This is the standard nix dev workflow;
  there's no realistic alternative without a different language ecosystem.

## Implementation

Configured in `home/core/shared/direnv.nix`:

```nix
programs.direnv = {
  enable = true;
  nix-direnv.enable = true;
};
```

Fish hook is auto-wired — do not manually add `direnv hook fish`.

Per-project pattern (in any project's repo):

- `flake.nix` declares `devShells.default` with the project's toolchain.
- `.envrc` contains `use flake`.
- First `cd` in: `direnv allow` once.
- Subsequent: instant activation.

Home-manager package list at `home/core/shared/cli-utils.nix` and
`home/core/shared/nix-tooling.nix` should stay minimal: only tools wanted
*everywhere* (git, ripgrep, the editor, etc.). Per-project tools belong in
that project's `flake.nix`, not in home-manager.

nix-direnv caches the built environment; flake changes rebuild on next
entry. If a cache feels stale, `direnv reload` forces a re-evaluation.
