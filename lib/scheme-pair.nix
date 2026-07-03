# scheme-pair — both polarity variants of a host's declared base16
# scheme couplet, as scheme attrsets (base16.nix mkSchemeAttrs), with
# the host's per-polarity slot overrides applied.
#
# Stylix itself derives colours only for the *active* polarity
# (config.lib.stylix.colors). Runtime polarity switching needs both
# halves pre-baked at build time (docs/design/macos-live-theme-switching.md
# §Design), so this helper runs the same machinery — the same scheme
# YAMLs and override merge as modules/*/stylix-palette.nix — once per
# declared polarity. Single-sourced here because two consumers need the
# identical derivation (Ghostty dual themes, JankyBorders hook pair).
{
  inputs,
  pkgs,
  lib,
  hostContext,
}:
let
  palettes = import ./host-palettes.nix;
  palette = palettes.${hostContext.hostName};
  base16 = inputs.stylix.inputs.base16.lib { inherit pkgs lib; };
  mkPolarity =
    polarity:
    (base16.mkSchemeAttrs "${pkgs.base16-schemes}/share/themes/${palette.schemes.${polarity}}.yaml")
    .override
      (palette.overrides.${polarity} or { });
in
{
  dark = mkPolarity "dark";
  light = mkPolarity "light";
}
