# The fleet-wide gate for persist-whitelist declarations.
#
# Modules carry their own environment.persistence fragments
# (module-owns-its-state, docs/design/ephemeral-root.md §Design), but a
# non-empty declaration set makes impermanence assert a neededForBoot
# /persist mount — which only adopting hosts have. Each declaring module
# therefore wraps its fragment in `lib.mkIf config.persist.enable`; an
# adopting host flips this alongside its /persist mount, and every other
# host evaluates the declarations away. Gating on the mount itself
# (`fileSystems ? "/persist"`) is not an option: impermanence's own
# machinery evaluates against config.fileSystems (assertions, mount
# derivation), so deciding the declarations FROM fileSystems couples the
# two inside the module fixed-point — fragile at best, recursive at worst.
# An independent option derives from nothing. Wired fleet-wide in
# lib/mk-host.nix beside the impermanence module it gates.
{ lib, ... }:
{
  options.persist.enable = lib.mkEnableOption "the fleet's persist-whitelist declarations (requires a neededForBoot /persist mount)";
}
