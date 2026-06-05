# ADR-004: Multiplexer — zellij

**Date**: 2026-05-06
**Status**: Accepted

> **Amendment (2026-06-05):** mosh was removed from the fleet ([#47](https://github.com/dannyfaris/nix-config/issues/47), [ADR-011](./ADR-011-remote-dev-qol.md)). References below to mosh "pairing" with zellij are historical — zellij now carries cross-disconnect persistence on its own (reconnect over plain SSH, then `zellij attach`); there is no mosh layer. The zellij decision itself is unchanged.

> **Revision (2026-06-05):** stale module paths in this ADR were swept to the
> current flat layout (`home/core/…` → `home/…`, `modules/core/…` → `modules/…`)
> per [ADR-026](./ADR-026-drop-core-tier-prefix.md), which dropped the `core/`
> tier prefix. Navigability fix only — the decision recorded here is unchanged.

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
- ✓ Detach/reattach: SSH disconnect, network change, or laptop sleep don't lose your work — reconnect over SSH and `zellij attach`. (This originally paired with mosh for a no-reconnect experience; mosh was removed in #47, so the reconnect step is back.)
- ✗ Smaller plugin ecosystem than tmux. (Most needs are covered by the
  built-ins.)
- ✗ Not pre-installed on most servers. If the user starts SSHing into many
  machines they don't control, tmux's ubiquity matters.
- ⚠ Migration trigger: SSHing regularly into machines we don't control.
- ⚠ Migration trigger: needing a specific tmux plugin (e.g.
  `tmux-resurrect`) — though zellij has its own session-persistence
  mechanism.

## Implementation

Configured in `home/shared/multiplexer.nix`:

```nix
programs.zellij.enable = true;
```

Default zellij settings already pass OSC52 escape sequences through to the
terminal (see ADR-011), so no extra config is needed for clipboard
bridging. Custom layouts are declarative (KDL) — when a project's
repeating workflow justifies one, declare it in `programs.zellij.settings`
or in a project-local KDL file.

zellij provides session persistence across any disconnect — network blip, laptop sleep, or reboot: reconnect over SSH, then `zellij attach`. (This originally paired with mosh for no-reconnect roaming; mosh was removed in #47 — see ADR-011.)
