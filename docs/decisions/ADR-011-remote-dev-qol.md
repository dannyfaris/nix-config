# ADR-011: Remote-dev quality of life — mosh + OSC52

**Date**: 2026-05-06
**Status**: Accepted

## Context

This is a headless dev box. The user works at it exclusively over SSH
from their Mac. Two friction points dominate that workflow:

1. **Connection brittleness.** SSH dies on every network hiccup, laptop
   sleep/wake, or IP change. Each disconnect kills running processes
   tied to the session. With zellij (ADR-004), processes survive but
   the user still has to reconnect and reattach.
2. **Cross-machine clipboard.** Yanking text in helix on the dev box
   leaves it in helix's internal register — invisible to the Mac's
   clipboard. Pasting into Slack, browser, or any Mac app means
   mouse-selecting the terminal output, which breaks the keyboard-driven
   workflow entirely.

Both have well-established solutions. Both are easy wins.

## Decision

Two complementary mechanisms are enabled for this tier:

1. **mosh** at the system level (`programs.mosh.enable`), which installs
   the binary and opens UDP ports 60000–61000 in the firewall.
2. **OSC52 clipboard bridging**, configured at three layers:
   - Helix: `editor.clipboard-provider = "termcode"`.
   - Zellij: pass-through of OSC52 sequences (default behaviour in modern
     zellij).
   - Terminal emulator on the Mac: must support OSC52 (Ghostty does by
     default; iTerm2 needs an explicit toggle; kitty / alacritty / wezterm
     all support it).

SSH agent forwarding from the Mac is **off** (the standard security
default — never expose the client's keys to the server).

## Rationale

### mosh

mosh replaces the SSH transport for terminal sessions with a
session-resumption protocol over UDP. The headline features are:

- Survives network changes (wifi → ethernet, tethering, IP swaps) without
  reconnect.
- Survives laptop sleep/wake without reconnect ceremony.
- Local echo for high-latency connections (typing appears immediately).

mosh and zellij are complementary, not redundant. Mosh handles
network-blip and sleep cases (no reconnect needed); zellij handles
cross-reboot persistence (laptop reboot → must SSH in fresh, then
`zellij attach`).

The first connection still uses SSH for the handshake; mosh upgrades the
session afterwards. Auth is unchanged from regular SSH (uses the same
keys / authorized_keys file).

mosh is terminal-only: it does not forward ports, agents, or X11. For
those rare cases, plain SSH still works. The two coexist; no conflict.

### OSC52 clipboard bridging

OSC52 is an ANSI escape sequence that lets terminal applications send
text to the *terminal emulator's* clipboard. The flow:

1. Helix prints the OSC52 sequence to its terminal output stream
   (just bytes, like printing characters).
2. The bytes flow over SSH/mosh to the Mac terminal emulator.
3. The Mac terminal emulator recognises OSC52 and writes the text to the
   Mac's system clipboard.
4. `Cmd-V` in any Mac app pastes it.

It's purely terminal-output-based, so it works through SSH, mosh, zellij —
anything that passes the terminal output stream. No special socket, no
networking.

The reverse direction (Mac → dev box) doesn't need OSC52: terminal
emulators handle paste natively as keystrokes inserted into the input
stream.

### Why agent forwarding stays off

`ForwardAgent yes` would make the Mac's SSH agent (and its keys) usable
*from* the dev box. The standard security argument applies: any process
on the dev box (including a compromised one) could then use those keys.
This is the universally-recommended default, and there's no current need
that would justify deviating. ADR-009 also makes it unnecessary — the
git auth path doesn't use SSH.

## Consequences

- ✓ "Disconnect/reconnect ceremony" essentially disappears for normal
  network and sleep cases.
- ✓ Yank-and-paste works keyboard-only across the SSH boundary.
- ✓ Both mechanisms are compatible with the rest of the stack (zellij,
  helix, fish, ssh).
- ✗ mosh client must be installed on the Mac separately (not in scope of
  this nix config). User runs `brew install mosh` once.
- ✗ OSC52 in iTerm2 needs an explicit toggle ("Allow programs to access
  clipboard"). **Ghostty has a similar gate**: `clipboard-write` defaults
  to `ask`, which prompts on every paste from a terminal app. Set
  `clipboard-write = allow` in Ghostty's config to make OSC52 silently
  work. Surfaced during Tier 3 verification — paste-from-helix didn't
  populate the Mac clipboard, but the nix-config side was correct
  (helix `clipboard-provider = "termcode"`, zellij default pass-through,
  mosh OSC52-aware). Resolution deferred — see `TODO.md` "Carryover
  when new hosts land" (will be exercised end-to-end once
  `linux-workstation` lands with foot).
- ⚠ Migration trigger: a Mac terminal emulator without OSC52 support
  would break the clipboard bridge. Modern alternatives all support it;
  unlikely to be an issue.

## Implementation

mosh configured at the system level in `modules/core/nixos/mosh.nix`:

```nix
{
  programs.mosh.enable = true;
}
```

This installs the binary AND opens UDP 60000–61000 in the firewall
automatically — both are required, and the module handles them together.

OSC52 is configured at three places:

- **Helix** (`home/core/shared/editor.nix`): in
  `programs.helix.settings.editor`, set `clipboard-provider = "termcode"`.
- **Zellij** (`home/core/shared/multiplexer.nix`): default settings already
  pass OSC52 through. No extra config needed in the typical case; if the
  bridge ever stops working, check zellij's clipboard config first.
- **Terminal emulator on the Mac**: outside this repo's scope. Use
  Ghostty, iTerm2 (with the OSC52 toggle on), kitty, alacritty, or
  wezterm. Verify via Slice 6's clipboard smoke test.

Daily use:

- `mosh dbf@nixos-vm` from the Mac (after `brew install mosh`) instead of
  `ssh dbf@nixos-vm`. Same key auth.
- Inside helix, `y` (yank) deposits text in the Mac clipboard. `Cmd-V` to
  paste anywhere.
- For tunnels, port-forwarding, or anything mosh doesn't support, fall
  back to plain `ssh`. They coexist.
