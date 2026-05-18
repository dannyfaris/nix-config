# ADR-004: Multiplexer — zellij

**Date**: 2026-05-06
**Status**: Accepted

## Context

A terminal multiplexer is non-optional for headless development over SSH. It
provides:

- **Splits and tabs over a single SSH connection** — no client-side window
  management.
- **Detach and reattach** — start a session, disconnect, come back tomorrow,
  reattach, find everything as you left it. Long-running processes survive
  network blips, laptop sleep, even multi-day gaps.

Without one, every SSH disconnect kills running processes; running multiple
things requires multiple SSH sessions; long-running tasks can't be checked
on later.

## Decision

The multiplexer is **zellij**, configured via `programs.zellij` in
home-manager.

## Rationale

The two real candidates were tmux (the 15-year incumbent) and zellij
(modern, ~2021). screen and tmate are not in the running for general
headless dev (screen is tmux's predecessor; tmate is a tmux fork for
collaboration).

**tmux strengths:** ubiquitous on every server; muscle memory transfers;
massive plugin ecosystem; battle-tested. **tmux weakness:** opaque defaults.
The "prefix key" model (Ctrl-b then a letter) requires memorisation; nothing
is shown on screen. Most users invest in customisation.

**zellij strengths:** discoverable status bar that shows available keybinds
contextually; sensible defaults out of the box; declarative KDL config;
built-in layouts (declare a project's pane setup once, reload it
deterministically). **zellij weakness:** smaller community; not on random
servers.

The deciding factor matches the same pattern as fish (ADR-001) and helix
(ADR-005): the user's stated preference is "clean, light, good UX out of
the box". Zellij's discoverable interface answers that directly. Tmux's
"learn 30 keybinds and you're flying" model is the opposite trade.

The "tmux is on every server" portability argument doesn't apply here:
this is a personal headless dev box, not a sysadmin role bouncing between
strangers' servers.

## Consequences

- ✓ Sensible defaults — no investment required to be productive on day one.
- ✓ Status bar contextually shows available keybinds; learning curve is
  gentle.
- ✓ Built-in layouts let projects declare their preferred pane setups.
- ✓ Detach/reattach: SSH disconnect, network change, laptop sleep all
  survive — combined with mosh (ADR-011) the workflow is essentially
  uninterruptible.
- ✗ Smaller plugin ecosystem than tmux. (Most needs are covered by the
  built-ins.)
- ✗ Not pre-installed on most servers. If the user starts SSHing into many
  machines they don't control, tmux's ubiquity matters.
- ⚠ Migration trigger: SSHing regularly into machines we don't control.
- ⚠ Migration trigger: needing a specific tmux plugin (e.g.
  `tmux-resurrect`) — though zellij has its own session-persistence
  mechanism.

## Implementation

Configured in `home/core/nixos/multiplexer.nix`:

```nix
programs.zellij.enable = true;
```

Default zellij settings already pass OSC52 escape sequences through to the
terminal (see ADR-011), so no extra config is needed for clipboard
bridging. Custom layouts are declarative (KDL) — when a project's
repeating workflow justifies one, declare it in `programs.zellij.settings`
or in a project-local KDL file.

Mosh (ADR-011) pairs with zellij; they're complementary, not redundant.
Mosh handles network-blip and sleep cases without reconnect ceremony;
zellij handles cross-reboot persistence (laptop reboot → reconnect via
mosh → `zellij attach`).
