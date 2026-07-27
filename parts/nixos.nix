# Defines nixosConfigurations via flake-parts.
# Pattern: one file per flake output kind in parts/ (ryan4yin's per-output
# file shape). Per-host wiring is delegated to lib/mk-host.nix; each host
# composes foundation + bundles + standalone modules in its own
# hosts/<hostname>/default.nix (per ADR-027).
{ inputs, ... }:

let
  mkHost = import ../lib/mk-host.nix { inherit inputs; };
in
{
  flake.nixosConfigurations = {
    nixos-vm = mkHost { hostname = "nixos-vm"; };
    mercury = mkHost { hostname = "mercury"; };
    metis = mkHost { hostname = "metis"; };
    # maia — TEMPORARY desktop bring-up (throwaway branch, never merged; see
    # hosts/maia/default.nix). Registered so `nix flake check` EVALUATES it; it
    # is deliberately NOT in parts/checks.nix, so its toplevel is not built in
    # CI (throwaway host — build-verify with a one-off `nix build` at bootstrap).
    maia = mkHost { hostname = "maia"; };
  };
}
