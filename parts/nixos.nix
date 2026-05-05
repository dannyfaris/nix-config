# Defines nixosConfigurations via flake-parts.
# Pattern: one file per flake output kind in parts/ (ryan4yin's per-output file shape).
{ inputs, ... }:

{
  flake.nixosConfigurations.nixos-vm = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      inputs.home-manager.nixosModules.home-manager
      inputs.sops-nix.nixosModules.sops
      inputs.niri-flake.nixosModules.niri
      inputs.stylix.nixosModules.stylix
      ../hosts/nixos-vm
      ../modules/system
      ../modules/home
      ../modules/desktop
    ];
  };
}
