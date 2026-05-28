# Host constructor. Thin wrapper over nixpkgs.lib.nixosSystem that wires
# in the host's directory + the common framework modules (home-manager,
# sops-nix). Called from parts/nixos.nix.
#
# Usage:
#   (import ./lib/mk-host.nix { inherit inputs; }) { hostname = "nixos-vm"; }
#
# Platform: the host's `hardware-configuration.nix` (or `hardware.nix` on
# nixos-vm) sets `nixpkgs.hostPlatform` per ADR-023 — that is the single
# source of truth. nixosSystem accepts being called without `system` and
# derives it from the module-set's hostPlatform.
{ inputs }:
{ hostname }:

inputs.nixpkgs.lib.nixosSystem {
  specialArgs = { inherit inputs; };
  modules = [
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    ../hosts/${hostname}
  ];
}
