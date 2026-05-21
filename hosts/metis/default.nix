# Host-specific configuration for Metis (HP ProDesk Mini 600 G9, x86_64-linux,
# bare metal). Adopts the headless role (via parts/nixos.nix) and adds the
# bare-metal platform modules (systemd-boot, NetworkManager) that the role
# itself doesn't pick.
#
# Personal dev box: dual git identity (personal + work) + full agent-CLI set,
# mirroring nixos-vm.
#
# Bootstrap note: before the first nixos-rebuild switch, Metis's SSH host key
# must be added to .sops.yaml and secrets/secrets.yaml re-encrypted.
# See hardware.nix for the step-by-step bootstrap procedure.
{ ... }:
{
  imports = [
    ./hardware.nix
    ../../modules/core/nixos/boot-systemd.nix
    ../../modules/core/nixos/networking-networkmanager.nix
  ];

  networking.hostName = "metis";

  # Set once at install; never change, even after upgrading.
  system.stateVersion = "25.11";

  # Per-host values consumed by home-manager modules (editor.nix nixd
  # options, nix-tooling NH_FLAKE). Forwarded into the HM submodule system
  # via extraSpecialArgs in modules/core/nixos/home-manager.nix. See ADR-019.
  _module.args.hostContext = {
    hostName  = "metis";
    flakePath = "/home/dbf/nix-config";
    # Personal dev box: dual identity (personal default; work under ~/work/)
    # plus full GitHub CLI + agent-CLI set — mirrors nixos-vm.
    extraHomeModules = [
      ../../home/core/nixos/git-identity-dual.nix
      ../../home/core/nixos/gh.nix
      ../../home/core/nixos/agent-clis-extras.nix
    ];
  };
}
