# SSH — outbound config (client-side) + inbound authorized_keys.
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
#   ~/.ssh/authorized_keys   nix-store symlink, rendered from
#                            lib/operator.nix's authorizedKeys list.
#                            Regenerated on every nh switch.
#
# On NixOS hosts, the system-side foundation (modules/nixos/users.nix)
# also writes the same keys to /etc/ssh/authorized_keys.d/<user> via
# users.users.dbf.openssh.authorizedKeys.keys — sshd reads both
# locations, so the home-managed file is redundant-but-harmless on
# NixOS. On Darwin (mac-mini), sshd is configured by nix-darwin to read
# keys via /etc/ssh/sshd_config.d/101-authorized-keys.conf's
# `AuthorizedKeysCommand` (which cats /etc/ssh/nix_authorized_keys.d/<user>,
# populated from users.users.<name>.openssh.authorizedKeys.keys in
# modules/darwin/users.nix). The home-managed ~/.ssh/authorized_keys is
# a /nix/store symlink and is NOT consulted by Darwin sshd — it's
# cosmetic-only on Darwin, kept for cross-platform parity at this layer.
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
{ lib, ... }:
let
  operator = import ../../lib/operator.nix;
in
{
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

  # Inbound authorization. Single source of truth: lib/operator.nix.
  # Trailing newline because some sshd versions are fussy about EOF
  # without one. The backup-extension on conflict is "hm-bak" (set
  # in modules/{nixos,darwin}/home-manager.nix), so first activation
  # on a host with an existing ~/.ssh/authorized_keys cleanly preserves
  # the old file as ~/.ssh/authorized_keys.hm-bak.
  home.file.".ssh/authorized_keys".text = lib.concatStringsSep "\n" operator.authorizedKeys + "\n";
}
