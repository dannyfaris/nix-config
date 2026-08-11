# Pointer & icon theme — Colloid icons + phinger cursor (#110).
# Selection, field measurements, and the polarity/render-list sharp edges:
# docs/desktop/pointer-icons.md.
{ pkgs, ... }:
{
  # Stylix resolves light/dark by build-time polarity into gtk.iconTheme;
  # runtime polarity flips don't swap it — see the doc's sharp edges.
  stylix.icons = {
    enable = true;
    package = pkgs.colloid-icon-theme;
    light = "Colloid";
    dark = "Colloid-Dark";
  };

  # Static light variant across both polarities — see the doc's cursor call.
  stylix.cursor = {
    package = pkgs.phinger-cursors;
    name = "phinger-cursors-light";
    size = 24;
  };
  # The compositor layer reads these same values rather than restating them, so
  # the niri cursor and the toolkit cursor cannot drift — home/nixos/niri.nix
  # threads stylix.cursor into niri's cursor block.
}
