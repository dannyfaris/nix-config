# ADR-001: Shell — fish

**Date**: 2026-05-06
**Status**: Accepted

## Context

The user is configuring a NixOS system for headless development and self-describes
as a "basic shell user" — unlikely to push the shell to scripting or
power-user limits. The interactive shell is the program they'll spend the most
time typing into; choosing it shapes daily friction. The starting baseline is
bash (the system default).

## Decision

The interactive shell is **fish**, configured via `programs.fish` at both the
NixOS level (system completions, `/etc/shells` registration) and the
home-manager level (user rc, plugins, abbreviations).

## Rationale

The candidates considered were bash, zsh, and fish.

- **bash** has the weakest interactive experience by default. Adding modern
  features (autosuggestions, syntax highlighting, smart completions) requires
  layered plugins; even with them, the experience never quite matches fish or
  zsh out of the box. Bash remains essential as the script shebang target,
  but for an interactive shell on a config we control, it's not in the
  running.
- **zsh** is the safe, productive middle ground: POSIX-compatible (any bash
  snippet from a tool's docs works), excellent plugin ecosystem, first-class
  home-manager support. The interactive experience is close to fish's once a
  small set of plugins are wired up.
- **fish** has the best out-of-the-box interactive UX of any shell:
  autosuggestions, syntax highlighting, smart completions, sane scripting
  language — all built in, zero plugins. Configuration is cleaner. The
  honest tradeoff is that fish is **not POSIX-compatible**: tool docs that
  say `eval "$(some-tool init bash)"` need translation; `export FOO=bar`
  doesn't work (fish uses `set -x FOO bar`).

The user's preference for "clean, light, out-of-the-box experience with good
UX" maps directly onto fish's design philosophy. The POSIX-incompatibility
friction is real but small in practice on a NixOS box: home-manager wires
shell hooks for tools (direnv, fzf, starship) automatically, so users rarely
encounter raw `eval "$(...)"` snippets. When they do — for one-off env vars
in a session — knowing `set -x FOO bar` is a near-zero learning cost.

zsh would also have been a defensible choice. Fish wins on the criterion the
user prioritised: the gap between a fresh install and a productive shell.

## Consequences

- ✓ Autosuggestions, syntax highlighting, smart completions — all built in,
  zero plugin maintenance.
- ✓ Configuration in nix is small (most users need <20 lines).
- ✓ Default fish prompts and behaviour are good enough that minimal config
  produces a polished experience.
- ✗ Not POSIX-compatible. Tool docs that assume bash/zsh need translation;
  copy-paste `export FOO=bar` snippets fail.
- ✗ Smaller ecosystem of community plugins than zsh (though most fish
  features are built-in, so plugins are rarely needed).
- ⚠ Migration trigger: if the user starts SSHing into many machines they
  don't control where fish isn't available, the muscle-memory portability of
  zsh would matter. Currently they have one server controlled by them; this
  doesn't apply.
- ⚠ Migration trigger: if the user begins shell-scripting heavily (cron jobs,
  automation, complex pipelines), fish's non-POSIX scripting language might
  push them back to bash for scripts. Interactive shell vs. script shell is
  separate, so this would manifest as wrapping fish-side glue around POSIX
  scripts, not switching the interactive shell.

## Implementation

Configured in:

- `modules/system/users.nix` — sets `users.users.dbf.shell = pkgs.fish` and
  `programs.fish.enable = true`. The system-side enable is **load-bearing**:
  it registers fish in `/etc/shells`, which is the gate for being a valid
  login shell. Without it, switching the user's shell to a home-manager-only
  fish locks the user out at next login. This is documented in a `# why`
  comment at that line.
- `modules/home/shell.nix` — `programs.fish.enable = true` at the home-manager
  level for user rc (plugins, abbreviations, environment).

When advising on env-var changes in fish sessions, remember the syntax is
`set -x FOO bar`, not `export FOO=bar`. Inside config, prefer
`home.sessionVariables`.

Bash and zsh remain available for scripts (`#!/bin/bash` shebangs unaffected).
`nix develop` still drops into bash by default.
