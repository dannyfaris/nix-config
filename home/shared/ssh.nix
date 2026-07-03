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
#   - Darwin (neptune): nix-darwin's services.openssh.enable installs
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
# Fleet matchBlocks are declared here (#517): every host knows how to
# reach every other after a switch, nothing hand-maintained. Entries use
# bare MagicDNS names — the tailscale search domain expands them on
# every host, and the bare form keeps the tailnet identifier out of this
# public repo. Host *identity* is the system layer's job: the committed
# host keys in modules/shared/ssh-known-hosts.nix mean these connections
# never TOFU-prompt.
#
# Tailscale outage: these names die with MagicDNS; recovery is the
# host-specific break-glass table in CLAUDE.md §Break-glass, plus the
# operator-maintained fallback blocks (LAN IP, EC2 DNS) in
# ~/.ssh/config.local — deliberately NOT promoted here (dynamic EC2
# name; operator chose not to commit fleet IPs).
#
# Git auth uses HTTPS + token via gh/glab (see ADR-009), so SSH keys
# aren't needed for git. The Include directive below lets the operator
# maintain one-off matchBlocks (bootstrap targets, temporary access,
# break-glass fallbacks) at ~/.ssh/config.local without having them
# clobbered on every nh os switch — home-manager owns the generated
# ~/.ssh/config but the Include'd file is untouched.
_:
let
  operator = import ../../lib/operator.nix;
  # One block shape for every fleet destination; a host's own entry is
  # harmless (self-SSH is rare but valid). nixos-vm deliberately absent
  # (excluded as a destination, #517).
  fleetHost = {
    User = operator.name;
  };
in
{
  programs.ssh = {
    enable = true;
    # Opt out of home-manager's deprecated "default match-block contents"
    # behaviour. Upstream is removing the implicit defaults; this silences
    # the trace warning and makes the stance explicit.
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
    #
    # Include renders BEFORE the blocks below and ssh takes the first
    # value per option — so a config.local block naming a fleet host
    # would shadow the declared one. The operator keeps config.local to
    # break-glass-only entries (metis-lan, mercury-aws) for exactly this
    # reason.
    includes = [ "~/.ssh/config.local" ];

    # `settings`, not the deprecated `matchBlocks` (HM renders "*" last
    # regardless of sort; upstream ssh_config directive names).
    settings = {
      neptune = fleetHost;
      mercury = fleetHost;
      metis = fleetHost;

      # Baseline stance for every destination, declared rather than
      # inherited from defaults (explicit > implicit). No option overlap
      # with the fleet blocks above (they set only User), so first-match
      # semantics can't shadow anything here.
      "*" = {
        # A compromised remote must not be able to borrow this host's
        # keys — no hop-through topology needs forwarding (each fleet
        # host is directly reachable). ADR-010's stance, now declared.
        ForwardAgent = false;
        # No silent key caching in the agent. Moot while keys are
        # passphrase-free; the day passphrases arrive, prompting is the
        # deliberate default and caching the opt-in.
        AddKeysToAgent = "no";
        # Text-heavy interactive traffic compresses well over the WAN
        # path (mercury); negligible CPU.
        Compression = true;
        # Explicit default-restatement: connection multiplexing off — a
        # control socket grants connection hijacking to anything running
        # as this user, for milliseconds of saving over the tailnet.
        ControlMaster = "no";
        # HashKnownHosts deliberately NOT set: this repo publishes the
        # fleet's names and host keys (ssh-known-hosts.nix), so hashing
        # the local file would obscure nothing coherent — and it costs
        # known_hosts debuggability. Declared-trust over hidden-trust.
      };
    };
  };
}
