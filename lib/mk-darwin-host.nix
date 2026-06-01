# Host constructor for Darwin hosts. Thin wrapper over nix-darwin's
# darwinSystem. Sibling of lib/mk-host.nix.
#
# Called from parts/darwin.nix once Darwin hosts exist (mac-mini lands
# in epic #11 PR 6).
#
# Usage:
#   (import ./lib/mk-darwin-host.nix { inherit inputs; }) { hostname = "mac-mini"; }
#
# Unlike nixpkgs.lib.nixosSystem, nix-darwin's darwinSystem does NOT
# derive `system` from the module-set's hostPlatform — it must be passed
# explicitly. Today all our Darwin targets are Apple Silicon, so the
# constructor defaults to "aarch64-darwin". An Intel Mac would override:
#
#   mkDarwinHost { hostname = "some-intel-mac"; system = "x86_64-darwin"; }
#
# The home-manager and sops-nix integrations come from each project's
# `darwinModules.<name>` flake outputs (parallel to their `nixosModules`).
{ inputs }:
{
  hostname,
  system ? "aarch64-darwin",
}:

inputs.nix-darwin.lib.darwinSystem {
  inherit system;
  specialArgs = { inherit inputs; };
  modules = [
    inputs.home-manager.darwinModules.home-manager
    inputs.sops-nix.darwinModules.sops
    ../hosts/${hostname}
  ];
}
