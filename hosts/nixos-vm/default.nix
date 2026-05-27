# Host-specific configuration for the UTM VM (aarch64-linux).
#
# Composes foundation + capability bundles + standalone modules directly
# (per ADR-027), no longer adopts the `headless` role. Standalones:
# bare-metal-VM platform modules (systemd-boot, NetworkManager) and
# Tailscale.
{ ... }:

{
  imports = [
    ./hardware.nix

    # Foundation — bundle every NixOS host imports by convention.
    ../../modules/core/nixos/foundation.nix

    # Capability bundles.
    ../../modules/core/nixos/bundles/remote-access.nix

    # Standalone system modules.
    ../../modules/core/nixos/boot-systemd.nix
    ../../modules/core/nixos/networking-networkmanager.nix
    ../../modules/core/nixos/tailscale.nix
  ];

  networking.hostName = "nixos-vm";

  # Set once at install; never change, even after upgrading.
  system.stateVersion = "25.11";

  # Per-host values consumed by home-manager modules (editor.nix nixd
  # options, nix-tooling NH_FLAKE). Forwarded into the HM submodule system
  # via extraSpecialArgs in modules/core/nixos/home-manager.nix. See ADR-019.
  #
  # extraHomeModules is now the full HM imports list for this host —
  # capability bundles plus standalone modules, per ADR-027's bundle model.
  # Personal dev box: cli tooling + dual git identity + GitHub CLI + agent
  # CLI extras + login info display + base agent CLIs + outbound SSH.
  _module.args.hostContext = {
    hostName  = "nixos-vm";
    flakePath = "/home/dbf/nix-config";
    extraHomeModules = [
      ../../home/core/nixos/bundles/cli-tooling.nix
      ../../home/core/nixos/bundles/git-personal.nix
      ../../home/core/nixos/ssh.nix
      ../../home/core/nixos/macchina.nix
      ../../home/core/nixos/agent-clis.nix
      ../../home/core/nixos/agent-clis-extras.nix
    ];
  };
}
