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
    metis = mkHost { hostname = "metis"; };
    alcyone = mkHost { hostname = "alcyone"; };
    alnair = mkHost { hostname = "alnair"; };
    electra = mkHost { hostname = "electra"; };
  };
}
