# SSH — outbound config (client-side) only.
# See docs/decisions/ADR-010-ssh.md for the broader rationale.
#
# What this module generates on the filesystem:
#
#   ~/.ssh/config            nix-store symlink, rendered from this module.
#                            Regenerated on every `nh darwin switch` /
#                            `nh os switch` — direct edits get clobbered.
#                            Currently contains just one line:
#                            `Include ~/.ssh/config.local`.
#
#   ~/.ssh/config.local      operator-maintained plain file, NEVER touched
#                            by nix. Home for one-off Host blocks
#                            (bootstrap targets, temporary access, hosts
#                            that haven't earned a place in this module
#                            yet). Sourced into ~/.ssh/config via the
#                            Include declared below.
#
# Inbound key authorisation is owned entirely by the system layer:
#
#   - NixOS hosts: `users.users.dbf.openssh.authorizedKeys.keys` in
#     modules/nixos/users.nix writes /etc/ssh/authorized_keys.d/dbf, which
#     sshd consumes via its NixOS-default AuthorizedKeysFile. The single
#     source of truth is lib/operator.nix.
#
#   - Darwin (mac-mini): nix-darwin's services.openssh.enable installs
#     /etc/ssh/sshd_config.d/101-authorized-keys.conf with an
#     AuthorizedKeysCommand that cats /etc/ssh/nix_authorized_keys.d/dbf,
#     populated from `users.users.dbf.openssh.authorizedKeys.keys` in
#     modules/darwin/users.nix. Same source of truth (lib/operator.nix).
#
# This module previously also wrote ~/.ssh/authorized_keys as a
# home-managed file for cross-platform parity, but that path was a
# /nix/store symlink, which sshd's StrictModes check rejects (because
# /nix/store is mode 1775, considered world-writable). On NixOS that
# produced three "Authentication refused: bad ownership or modes for
# directory /nix/store" warnings before every successful login; on
# Darwin the file wasn't read at all. Dropping it removes the chronic
# warning and shrinks the inbound-keys surface to a single per-platform
# system-side path. See #234.
#
# No matchBlocks declared here, no identity files, no key generation. Git
# auth uses HTTPS + token via gh/glab (see ADR-009), so SSH keys aren't
# needed for git. The Include directive below lets the operator maintain
# one-off matchBlocks (e.g. for bootstrap-only access to a new cloud host
# via nixos-anywhere) at ~/.ssh/config.local without having them clobbered
# on every nh os switch — home-manager owns the generated ~/.ssh/config
# but the Include'd file is untouched.
#
# When SSH keys become a permanent fixture (e.g. for a future x86_64
# desktop or cloud servers used routinely), generate fresh ed25519 keys
# on this box, use a passphrase + ssh-agent, and add matchBlocks here
# directly. Agent forwarding from the Mac stays explicitly OFF (standard
# security best practice).
_: {
  programs.ssh = {
    enable = true;
    # Opt out of home-manager's deprecated "default match-block contents"
    # behaviour. Upstream is removing the implicit defaults; this silences
    # the trace warning and makes the stance explicit. We don't depend on
    # any of those defaults (no matchBlocks declared; no SSH keys yet).
    enableDefaultConfig = false;
    # Pull in ~/.ssh/config.local at file scope. Standard pattern for
    # mixing nix-managed SSH config with operator-maintained one-offs
    # (e.g. a temporary matchBlock for a host being bootstrapped via
    # nixos-anywhere). Missing-file is silently ignored by ssh, so this
    # is safe to enable unconditionally.
    #
    # programs.ssh.includes emits the Include at file scope (before any
    # Host blocks), which is the upstream-blessed mechanism and avoids
    # the scoping subtleties of putting Include inside a Host * block.
    includes = [ "~/.ssh/config.local" ];
  };
}
