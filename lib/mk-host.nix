# Host constructor. Thin wrapper over nixpkgs.lib.nixosSystem that wires in
# the host modules + the common framework modules (home-manager, sops-nix),
# and optionally a role file for hosts that haven't yet migrated to the
# foundation+bundles composition model. Called from parts/nixos.nix.
#
# The `role` argument is transitional: ADR-027 retires the role layer in
# favour of foundation + bundles, and slice 3 of that migration switches
# hosts one at a time. Hosts that have switched omit `role`; hosts that
# haven't pass `role = "headless"` (the only role that exists). Once all
# hosts have switched, slice 4 removes the `role` argument entirely
# alongside the roles/ directory.
#
# Usage (post-migration):
#   (import ./lib/mk-host.nix { inherit inputs; }) {
#     hostname = "nixos-vm";
#     system   = "aarch64-linux";
#   }
#
# Usage (transitional, still on the role):
#   (import ./lib/mk-host.nix { inherit inputs; }) {
#     hostname = "mercury";
#     system   = "x86_64-linux";
#     role     = "headless";
#   }
{ inputs }:
{ hostname, system, role ? null }:

let
  lib = inputs.nixpkgs.lib;
in
# `system` is passed twice: once to nixosSystem (here) and once via
# `nixpkgs.hostPlatform` in the host's hardware-configuration.nix
# (ADR-023). The two must agree. A future refactor could pin them from
# one source, but at the current host count the small duplication is
# cheaper than the indirection.
lib.nixosSystem {
  inherit system;
  specialArgs = { inherit inputs; };
  # Role file (when present) is placed before the host directory in the
  # modules list, preserving the legacy evaluation order so closures of
  # hosts that still pass `role` remain byte-identical across this change.
  modules = [
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
  ] ++ lib.optional (role != null) ../roles/${role}.nix
    ++ [ ../hosts/${hostname} ];
}
