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

### Session naming (2026-06-08)

The `za` workspace function names its session `<host>:<repo>` (e.g. `mac-mini:nix-config`), not the bare repo basename. The driver is the OS-level window switcher: zellij sets the outer terminal title via OSC-0 to `<session> | <focused-pane-title>` — session-name-first, with no option to reorder or disable the session prefix (zellij 0.44.3, `make_terminal_title`). Leading the session name with the host is therefore the only lever that puts the host first in the title, which is what disambiguates otherwise-identical workspaces across the fleet when cmd-tabbing in Ghostty.

Two consequences follow, and they are the reason the surrounding code looks the way it does:

- **The bar renders the path, not the session name.** The zjstatus `format_left` would otherwise show the host-prefixed session and double the host already in its `{command_host}` segment. Instead a `{command_path}` widget renders the launch-dir basename (zjstatus runs command widgets in the session's launch dir, the same cwd the git widget relies on) — which is the prompt's `$directory` value, so bar, fish prompt and Claude statusline stay one visual language.
- **`fish_title` is silent inside zellij.** zellij captures the focused pane's OSC-0 title and appends it after the session name. Left active, `fish_title` would make the title `<host>:<repo> | hostname: pwd`; returning early when `$ZELLIJ` is set keeps it the clean `<host>:<repo>`. (A non-fish focused pane such as yazi may still set its own title; the host-led prefix holds regardless.) Outside zellij `fish_title` is unchanged — it still surfaces `hostname: pwd` for plain Ghostty tabs.

The `:` separator is CLI- and filesystem-safe: the session name doubles as a unix socket filename, and zellij 0.44.3 accepts `:` (its `validate_session_name` rejects only empty / `.` / `..` / names containing `/`).

Code: `home/shared/shell.nix` (`za`, `fish_title`) and `home/shared/multiplexer.nix` (the `{command_path}` widget). Renaming the session orphans any pre-existing bare-named session — `zellij delete-session <old>` once after first switch.
