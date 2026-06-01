# Defines darwinConfigurations via flake-parts.
# Pattern: one file per flake output kind in parts/ (mirrors parts/nixos.nix).
# Per-host wiring will use lib/mk-darwin-host.nix once hosts arrive:
#
#   { inputs, ... }:
#   let mkDarwinHost = import ../lib/mk-darwin-host.nix { inherit inputs; };
#   in {
#     flake.darwinConfigurations = {
#       mac-mini = mkDarwinHost { hostname = "mac-mini"; };
#     };
#   }
#
# Empty placeholder at the PR landing the flake plumbing; the first
# Darwin host (mac-mini) arrives in the host-bring-up PR of the same
# epic (#11). The constructor at lib/mk-darwin-host.nix exists today;
# it's just not invoked until then.
_: {
  flake.darwinConfigurations = { };
}
