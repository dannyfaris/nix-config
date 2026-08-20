# Pointer & icon theme — Colloid icons + phinger cursor (#110).
# Selection, field measurements, and the polarity/render-list sharp edges:
# docs/desktop/pointer-icons.md.
#
# Icon and cursor theme *selection* was never a colour role, so it survived
# the ADR-048 delegation as a named residue and then outlived the engine
# that carried it: #885 took Stylix off the NixOS side, and these are
# home-manager's own options, set directly here.
#
# The icon theme lives here rather than with the rest of the GTK surface
# (home/nixos/gtk.nix) so it cannot drift from the cursor theme it is
# selected alongside (#110).
{ pkgs, ... }:
let
  # One definition for the cursor, read by both the toolkit layer
  # (home.pointerCursor, which writes the GTK/X11/icon-dir wiring) and the
  # compositor layer (niri) below — so the two cannot drift.
  cursor = {
    package = pkgs.phinger-cursors;
    # Static light variant across both polarities — see the doc's cursor call.
    name = "phinger-cursors-light";
    size = 24;
  };
in
{
  # `enable` and `x11.enable` are both stated: the first because leaving it
  # implicit is deprecated upstream, the second because it is what writes the
  # Xcursor entries in ~/.Xresources that XWayland clients read — dropping it
  # is a silent regression, not an eval error.
  home.pointerCursor = cursor // {
    enable = true;
    x11.enable = true;
    gtk.enable = true;
  };

  # Single literal, not a light/dark pair: every host runs a dark theme today
  # (Noctalia's runtime pick on Linux; celaeno's declared polarity on Darwin)
  # and home-manager's `gtk.iconTheme.name` takes one name. The pair the
  # previous wiring carried (Colloid / Colloid-Dark) is consciously collapsed
  # — see ADR-028 §History. A light-polarity host re-opens it.
  gtk.iconTheme = {
    package = pkgs.colloid-icon-theme;
    name = "Colloid-Dark";
  };

  # Compositor layer reads the same let-binding as the toolkit layer above.
  programs.niri.settings.cursor = {
    theme = cursor.name;
    inherit (cursor) size;
  };
}
