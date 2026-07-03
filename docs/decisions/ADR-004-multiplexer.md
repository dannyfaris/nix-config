# ADR-004: Multiplexer — zellij

**Date**: 2026-05-06
**Status**: Accepted

> **Amendment (2026-06-05):** mosh was removed from the fleet ([#47](https://github.com/dannyfaris/nix-config/issues/47), [ADR-011](./ADR-011-remote-dev-qol.md)). References below to mosh "pairing" with zellij are historical — there is no mosh layer; cross-disconnect persistence is carried by zellij alone (reconnect over plain SSH, then `zellij attach`). The zellij decision itself is unchanged.
>
> **Correction (2026-06-27):** the removal was *not* because mosh had become redundant — it was forced. mosh and zellij fight over the screen (two independent terminal-state models re-emitting escape sequences), producing rendering corruption that made the pairing unusable. Absent that conflict mosh was the *preferred* remote experience: its local-echo "feels-local" responsiveness and IP-roaming are exactly what plain-SSH reconnect does not recover. So what was lost with mosh is the no-reconnect, low-latency *feel* — not persistence, which zellij keeps. This is the live migration pressure behind any future "feels-local over SSH" reassessment (e.g. herdr, whose own remote mode sidesteps the conflict by being the multiplexer rather than wrapping one).

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

zellij provides session persistence across a *disconnect* — network blip, laptop sleep — because the session's server keeps running: reconnect over SSH, then `zellij attach`. (This originally paired with mosh for no-reconnect roaming; mosh was removed in #47 — see ADR-011.) Persistence across a *reboot* (which does kill the server) would require on-disk serialization — deliberately **off** for the agent layout; see "Session serialization disabled" below.

### Session naming (2026-06-08)

The `za` workspace function names its session `<host>:<repo>` (e.g. `mac-mini:nix-config`), not the bare repo basename. The driver is the OS-level window switcher: zellij sets the outer terminal title via OSC-0 to `<session> | <focused-pane-title>` — session-name-first, with no option to reorder or disable the session prefix (zellij 0.44.3, `make_terminal_title`). Leading the session name with the host is therefore the only lever that puts the host first in the title, which is what disambiguates otherwise-identical workspaces across the fleet when cmd-tabbing in Ghostty.

Two consequences follow, and they are the reason the surrounding code looks the way it does:

- **The bar renders the path, not the session name.** The zjstatus `format_left` would otherwise show the host-prefixed session and double the host already in its `{command_host}` segment. Instead a `{command_path}` widget renders the launch-dir basename (zjstatus runs command widgets in the session's launch dir, the same cwd the git widget relies on) — which is the prompt's `$directory` value, so bar, fish prompt and Claude statusline stay one visual language.
- **`fish_title` is silent inside zellij.** zellij captures the focused pane's OSC-0 title and appends it after the session name. Left active, `fish_title` would make the title `<host>:<repo> | hostname: pwd`; returning early when `$ZELLIJ` is set keeps it the clean `<host>:<repo>`. (A non-fish focused pane such as yazi may still set its own title; the host-led prefix holds regardless.) Outside zellij `fish_title` is unchanged — it still surfaces `hostname: pwd` for plain Ghostty tabs.

The `:` separator is CLI- and filesystem-safe: the session name doubles as a unix socket filename, and zellij 0.44.3 accepts `:` (its `validate_session_name` rejects only empty / `.` / `..` / names containing `/`).

Code: `home/shared/shell.nix` (`za`, `fish_title`) and `home/shared/multiplexer.nix` (the `{command_path}` widget). Renaming the session orphans any pre-existing bare-named session — `zellij delete-session <old>` once after first switch.

### Session serialization disabled (2026-06-11)

`session_serialization` and `pane_viewport_serialization` are **off**. They were originally enabled to carry the agent workspace across a server restart, but resurrection actively *degrades* the `agent` layout, so the cost outweighs a benefit that barely applied.

The mechanism (reproduced on metis, zellij 0.44.3): the `agent` and `terminal` panes are bare shell panes — no `command` — while `yazi` carries `command "yazi"`. zellij destroys a shell pane the instant its shell exits, but *holds* a command pane open after its process dies. On reboot every process is signalled at once; the `fish` shells in the two shell panes exit and those panes are removed, leaving `yazi` as the sole content pane, so zellij collapses the vertical split and promotes yazi to sit alone between the two bars. That single-pane wreck — with yazi itself resurrected *suspended* — is what serializes, and `za`'s `attach` faithfully restores it. Because each resurrect re-serializes the degraded state, it never heals on its own: the only escape was to `zellij delete-session` and start over.

The advertised "survive `nh os switch`" benefit was largely illusory — a switch doesn't kill an interactively-launched zellij server (it is an ordinary user process, not a managed service), so the live session is untouched regardless. Disabling serialization makes `za`'s `attach` miss after a server restart, so the `or` arm rebuilds `agent.kdl` fresh every time, which is the wanted behavior. Live detach/reattach (network blip, laptop sleep) is unaffected: the server keeps running and the session stays addressable.

The verified evidence (fresh launch, detach, graceful `kill-session`, server SIGTERM, and isolated shell-pane death — only the last degrades) lives in the PR that landed this. Code: the two `*_serialization` flags in `home/shared/multiplexer.nix`. One-time cleanup after first switch: `zellij delete-session --force <host>:<repo>` once to discard any already-degraded dump.
