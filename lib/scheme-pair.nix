# scheme-pair — resolved base16 scheme attrsets (base16.nix mkSchemeAttrs,
# with slot overrides applied) for runtime theme switching: the host's
# boot-default couplet as `dark` / `light`, and the whole declared
# catalogue as `menu` (familyName -> { dark; light }).
#
# Stylix itself derives colours only for the *active* polarity
# (config.lib.stylix.colors). Runtime switching needs every selectable
# variant pre-baked at build time (docs/design/macos-live-theme-switching.md
# §Design; docs/design/colour-conductor.md §Design item 2), so this helper
# runs the same machinery — selection semantics from lib/palette-for.nix
# (#541), the same base16.nix mkSchemeAttrs + override merge the
# stylix-palette twins feed — once per variant. Single-sourced here because
# every consumer needs the identical derivation: Ghostty dual themes and
# the JankyBorders hook pair read the default couplet today; the
# per-entry artefact sets of #605 stage 2 and #609 build on `menu`.
{
  inputs,
  pkgs,
  lib,
  hostContext,
}:
let
  paletteFor = import ./palette-for.nix hostContext.hostName;
  base16 = inputs.stylix.inputs.base16.lib { inherit pkgs lib; };
  mkVariant =
    sel:
    (base16.mkSchemeAttrs "${pkgs.base16-schemes}/share/themes/${sel.scheme}.yaml").override sel.override;
in
{
  # The boot-default family name, alongside its resolved couplet below —
  # menu consumers need to know which entry is the fallback.
  inherit (paletteFor) family;

  dark = mkVariant (paletteFor.select "dark");
  light = mkVariant (paletteFor.select "light");
  menu = builtins.mapAttrs (_: couplet: {
    dark = mkVariant couplet.dark;
    light = mkVariant couplet.light;
  }) paletteFor.menu;
}
