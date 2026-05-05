# Defines nixosConfigurations via flake-parts.
# Pattern: one file per flake output kind in parts/ (ryan4yin's per-output file shape).
{ inputs, ... }:

{
  flake.nixosConfigurations.nixos-vm = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      # Placeholder: host and shared modules will be added during decomposition.
    ];
  };
}
