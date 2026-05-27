# Defines nixosConfigurations via flake-parts.
# Pattern: one file per flake output kind in parts/ (ryan4yin's per-output
# file shape). Per-host wiring is delegated to lib/mk-host.nix; each host
# composes foundation + bundles + standalone modules in its own
# hosts/<hostname>/default.nix (per ADR-027).
#
# Migration note: during the role-removal migration (slice 3), hosts switch
# off the `role` argument one at a time. Hosts that have switched compose
# foundation + bundles themselves; hosts that haven't still pass
# `role = "headless"`. Slice 4 removes the role argument entirely.
{ inputs, ... }:

let
  mkHost = import ../lib/mk-host.nix { inherit inputs; };
in
{
  flake.nixosConfigurations.nixos-vm = mkHost {
    hostname = "nixos-vm";
    system   = "aarch64-linux";
  };

  flake.nixosConfigurations.mercury = mkHost {
    hostname = "mercury";
    system   = "x86_64-linux";
    role     = "headless";
  };

  flake.nixosConfigurations.metis = mkHost {
    hostname = "metis";
    system   = "x86_64-linux";
    role     = "headless";
  };
}
