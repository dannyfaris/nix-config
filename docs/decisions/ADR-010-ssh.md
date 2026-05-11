# ADR-010: SSH — defaults only, key generation deferred

**Date**: 2026-05-06
**Status**: Accepted

## Context

The repo's *inbound* SSH (i.e., the `services.openssh` config that lets
the user SSH *into* this box from their Mac) is hardened and unchanged
by this tier — see `modules/system/ssh.nix`.

The question this ADR answers is about *outbound* SSH: should the dev box
have SSH keys generated for talking to other machines, and how should
`programs.ssh` be configured at the home-manager level?

## Decision

`programs.ssh.enable = true` at the home-manager level, with **defaults
only** — no `matchBlocks`, no per-host identity files, no key generation.

SSH key generation is **deferred** until there's a concrete non-git
outbound SSH need.

## Rationale

The original plan had been to generate two SSH keys on the dev box (one
for GitHub personal, one for GitLab work) and configure
`programs.ssh.matchBlocks` to route them per host. That plan changed when
ADR-009 settled on HTTPS+token auth for git.

After that pivot:

- Git access doesn't use SSH at all.
- There's no other current SSH-out workflow on this box: no servers to
  administer, no other dev machines to reach (yet).
- Generating keys "in case" violates philosophy.md's "no premature
  abstraction" rule.

So the cleanest position is: enable `programs.ssh` so the module is
declared and known to home-manager, but configure nothing host-specific
until a concrete need arises.

When the eventual need does arise, the deferred decision becomes:

- Generate fresh ed25519 keys on this box (don't copy from the laptop —
  per-machine identity model).
- For non-git uses, **encrypted with a passphrase + ssh-agent** is the
  recommended default. The agent-CLI friction reasoning that drove
  ADR-009 toward HTTPS-tokens doesn't apply to non-git SSH (which is
  rarely invoked from agent contexts).
- Add `matchBlocks` entries for the specific hosts at that time.

These guidelines are written down here so the future-self picking this up
doesn't have to re-derive them.

## Consequences

- ✓ Minimal config; no keys to manage, rotate, or worry about leaking.
- ✓ Aligned with HTTPS-token git auth (ADR-009).
- ✓ "No premature abstraction" applied — keys generated when needed,
  configured when needed.
- ✗ Slightly more friction the moment a real SSH-out need arises — have to
  generate the key, register the public key with the destination, add a
  matchBlock. Probably ~10 minutes when the moment comes.
- ⚠ Migration trigger: any of the following appearing as a real workflow:
  - SSH from this box to a cloud host or work infrastructure.
  - SSH between this VM and the future x86_64 desktop (Tier 5).
  - File transfer via scp/sftp to/from another machine.
  - GitLab work policy requiring SSH-only access (would also revise ADR-009).
- ⚠ Migration trigger: agent forwarding remains explicitly **off** even
  when keys are eventually generated. Forwarding the laptop's keys into
  this box would expose them to anything running here, which is the
  standard security warning. Each machine has its own keys.

## Implementation

Configured in `modules/home/ssh.nix`:

```nix
{
  programs.ssh = {
    enable = true;
    # Opt out of home-manager's deprecated "default match-block contents"
    # behaviour. Upstream is removing the implicit defaults; explicit
    # opt-out silences the trace warning and makes the stance clear.
    # We don't depend on any of those defaults (no matchBlocks declared;
    # no SSH keys yet).
    enableDefaultConfig = false;
  };
}
```

The comment in the file explains *why* the file is essentially empty —
this is the explicit-over-implicit principle from philosophy.md.

When SSH keys are eventually added:

- Generate on this box: `ssh-keygen -t ed25519 -f ~/.ssh/<purpose>_ed25519`.
- Use a passphrase and rely on ssh-agent for caching.
- Register the public key with the destination service.
- Add a `matchBlocks.<host> = { identityFile = "~/.ssh/<purpose>_ed25519"; };`
  entry to this module.
