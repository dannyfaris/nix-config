# Host constructor. Thin wrapper over nixpkgs.lib.nixosSystem that wires in
# the role and host modules + the common framework modules (home-manager,
# sops-nix). Called from parts/nixos.nix.
#
# Usage:
#   (import ./lib/mk-host.nix { inherit inputs; }) {
#     hostname = "nixos-vm";
#     system   = "aarch64-linux";
#     role     = "headless";
#   }
{ inputs }:
{ hostname, system, role }:

# `system` is passed twice: once to nixosSystem (here) and once via
# `nixpkgs.hostPlatform` in the host's hardware.nix. The two must agree.
# A future refactor could pin them from one source, but at the current
# host count the small duplication is cheaper than the indirection.
inputs.nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = { inherit inputs; };
  modules = [
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    ../roles/${role}.nix
    ../hosts/${hostname}
  ];
}
