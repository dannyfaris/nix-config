# scheme-pair — both polarity variants of a host's declared base16
# scheme couplet, as scheme attrsets (base16.nix mkSchemeAttrs), with
# the host's per-polarity slot overrides applied.
#
# Stylix itself derives colours only for the *active* polarity
# (config.lib.stylix.colors). Runtime polarity switching needs both
# halves pre-baked at build time (docs/design/macos-live-theme-switching.md
# §Design), so this helper runs the same machinery — selection semantics
# from lib/palette-for.nix (#541), the same base16.nix mkSchemeAttrs +
# override merge the stylix-palette twins feed — once per declared
# polarity. Single-sourced here because two consumers need the identical
# derivation (Ghostty dual themes, JankyBorders hook pair).
{
  inputs,
  pkgs,
  lib,
  hostContext,
}:
let
  paletteFor = import ./palette-for.nix hostContext.hostName;
  base16 = inputs.stylix.inputs.base16.lib { inherit pkgs lib; };
  mkPolarity =
    polarity:
    let
      sel = paletteFor.select polarity;
    in
    (base16.mkSchemeAttrs "${pkgs.base16-schemes}/share/themes/${sel.scheme}.yaml").override sel.override;
in
{
  dark = mkPolarity "dark";
  light = mkPolarity "light";
}
