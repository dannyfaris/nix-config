# theme-tokens — the design tokens with each colour role's hex resolved
# against the active Stylix palette.
#
# The dynamic half of the design-token module: it imports
# `lib/static-tokens.nix` (geometry, layout, spacing, motion, and the
# colour roles' `.slot`/`.ansi` aliases — everything that needs no
# `config`) and adds the one field a live palette is required for,
# `color.role.<name>.hex`. Consumers that want a hex import this file;
# consumers that want only the static surface import static-tokens.nix
# directly. See that file's header for why the boundary is structural.
#
# Darwin-only in practice since #885 took Stylix off the NixOS side: the
# sole consumer repo-wide is modules/darwin/jankyborders.nix (border
# colours). That makes this file what lib/scheme-pair.nix already is
# post-ADR-048 — a shared-lib file whose only live consumers are Darwin —
# and it stays under lib/ for the same reason: nothing in it is
# platform-conditional, only its current consumer set is.
#
# Imported per-consumer as `import ../../lib/theme-tokens.nix { inherit config; }`
# — the lib/ import convention (theme-families/static-tokens/operator are
# plain attrsets, stances takes { lib }; this one takes config).
{ config }:
let
  static = import ./static-tokens.nix;
  c = config.lib.stylix.colors;
  hexOf = slot: c."${slot}-hex"; # base16 slot -> "RRGGBB" (the one accessor site)
in
static
// {
  color = static.color // {
    # Resolve every declared role rather than a hand-listed subset, so a
    # role added to static-tokens.nix gains its `.hex` with no edit here.
    role = builtins.mapAttrs (_: r: r // { hex = hexOf r.slot; }) static.color.role;
  };
}
