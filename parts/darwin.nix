# Defines darwinConfigurations via flake-parts. Per-output file shape —
# mirrors parts/nixos.nix. Per-host wiring is delegated to
# lib/mk-darwin-host.nix; each host composes foundation + bundles +
# standalone modules in its own hosts/<hostname>/default.nix (per ADR-027).
{ inputs, ... }:

let
  mkDarwinHost = import ../lib/mk-darwin-host.nix { inherit inputs; };
in
{
  flake.darwinConfigurations = {
    neptune = mkDarwinHost { hostname = "neptune"; };
    saturn = mkDarwinHost { hostname = "saturn"; };
  };
}
