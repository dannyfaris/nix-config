# Single source of truth for the operator identity. Imported via Nix
# `let`-binding (not NixOS option) — the option-layer pattern is reserved
# for `hostContext` where imports-evaluation-timing demands it; the
# operator record is plain data that any module needs at any phase.
#
# Consumed by (today):
#   - modules/nixos/users.nix         — user declaration + SSH keys
#   - modules/nixos/networking-networkmanager.nix
#                                     — networkmanager group membership
#   - modules/nixos/home-manager.nix  — HM attr-name + homeDirectory
#   - modules/nixos/host-context.nix  — flakePath default
#   - modules/darwin/users.nix        — user declaration (subset
#                                       managed by nix-darwin) + SSH keys
#   - modules/darwin/home-manager.nix — HM attr-name + homeDirectory
#   - modules/darwin/host-context.nix — flakePath default
#   - home/shared/ssh.nix             — fleet matchBlock User (#517)
#
# The sibling `modules/darwin/users.nix` (listed above) consumes the
# same record with the `darwinHome` field. The deliberate split between
# `linuxHome` and `darwinHome` records the platform-rooted home location
# once; consumers pick the right one for their layer.
#
# Why a plain attrset and not a NixOS option: an option layer would
# require an `imports` evaluation timing dance for any module that wants
# to use it during its own imports — see `host-context.nix`'s comment
# block for the trap. An identity record is plain data; treating it as
# such avoids the trap by construction.
#
# Per #49.
{
  name = "dbf";
  description = "Daniel";

  # Platform-rooted home paths. Consumers pick the right one for the
  # layer they're in; the home-manager NixOS-module path uses linuxHome,
  # the Darwin equivalent (modules/darwin/home-manager.nix) uses darwinHome.
  linuxHome = "/home/dbf";
  darwinHome = "/Users/dbf"; # consumed by the Darwin users + home-manager modules

  # Flake checkout directory name, joined with the per-platform home to
  # produce the full filesystem path (e.g. /home/dbf/nix-config on Linux,
  # /Users/dbf/nix-config on Darwin). Drives the NH_FLAKE default in
  # `hostContext.flakePath`.
  flakeRepoDirname = "nix-config";

  # SSH public keys authorised for inbound SSH on every host. Consumed
  # by the system layer on each platform:
  #   - NixOS: modules/nixos/users.nix → users.users.dbf.openssh
  #     .authorizedKeys.keys (renders /etc/ssh/authorized_keys.d/dbf).
  #   - Darwin: modules/darwin/users.nix → users.users.dbf.openssh
  #     .authorizedKeys.keys (renders /etc/ssh/nix_authorized_keys.d/dbf,
  #     consumed by nix-darwin's AuthorizedKeysCommand drop-in).
  # Today the Mac is the sole operator key; a backup key (e.g. on a
  # YubiKey) would append here rather than being introduced as parallel
  # state.
  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPNUroaa0Z3VyMJVnnQWTtuaosFL30E6xDsSUEAuS8MI dbf@mac"
  ];
}
