# Defines nixosConfigurations via flake-parts.
# Pattern: one file per flake output kind in parts/ (ryan4yin's per-output
# file shape). Per-host wiring is delegated to lib/mk-host.nix; each host
# adopts a role from roles/ and lives in hosts/<hostname>/.
{ inputs, ... }:

let
  mkHost = import ../lib/mk-host.nix { inherit inputs; };
in
{
  flake.nixosConfigurations.nixos-vm = mkHost {
    hostname = "nixos-vm";
    system   = "aarch64-linux";
    role     = "headless";
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
