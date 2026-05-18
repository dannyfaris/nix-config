# Host-specific configuration for the UTM VM (aarch64-linux). Adopts the
# headless role (via parts/nixos.nix) and adds the VM-specific platform
# modules (systemd-boot, NetworkManager) that the role itself doesn't pick.
{ ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/core/nixos/boot-systemd.nix
    ../../modules/core/nixos/networking-networkmanager.nix
  ];

  networking.hostName = "nixos-vm";

  # Set once at install; never change, even after upgrading.
  system.stateVersion = "25.11";

  # Per-host values consumed by home-manager modules (editor.nix nixd
  # options, nix-tooling NH_FLAKE). Forwarded into the HM submodule system
  # via extraSpecialArgs in modules/core/nixos/home-manager.nix. See ADR-019.
  _module.args.hostContext = {
    hostName  = "nixos-vm";
    flakePath = "/home/dbf/nix-config";
    extraHomeModules = [
      ../../home/core/nixos/git-identity-dual.nix
      ../../home/core/nixos/gh.nix
    ];
  };
}
