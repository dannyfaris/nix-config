# desktop-fonts — the NixOS-side font wiring for desktop hosts: install the
# faces and define the fontconfig generic→face map. Imported only by desktop
# hosts (via the desktop-env bundle), so headless hosts (electra) pay no
# font-package closure.
#
# Fonts are conducted by fontconfig, not Stylix (ADR-036 Amendment; #390):
# surfaces ask for a generic (monospace / sans-serif), this map resolves it,
# and a user file in ~/.config/fontconfig/conf.d overrides it at runtime with
# no rebuild. Three jobs, all explicit here:
#   - fonts.packages                — install only the consumed faces.
#   - fonts.fontconfig.defaultFonts — the baseline generic→face map.
#   - stylix.targets.fontconfig.enable = false — so Stylix writes no competing
#     map.
#
# stylix.fonts is kept for its one surviving consumer (the GTK target's
# `sizes.popups`); the fields the dropped Firefox target read are inert
# residue (ADR-048, #825). See docs/desktop/fonts.md.
#
# Per #390 (Part A); was Stylix-sourced per ADR-028 / #69.
{ pkgs, ... }:
let
  # Per-surface sizes come from the display calibration, so they
  # stay coupled to the niri output scale. See lib/display-profiles.nix.
  profile = import ../../lib/display-profiles.nix;
in
{
  fonts = {
    # Install only what something consumes (whitelist > blanket): mono for the
    # terminal/TUIs, Inter for GTK/web, Noto for emoji. Serif is uncurated — it
    # resolves to the DejaVu that fonts.enableDefaultPackages already ships.
    packages = [
      pkgs.nerd-fonts.monaspace
      pkgs.inter
      pkgs.noto-fonts-color-emoji
    ];

    # The baseline generic→face map — the conductor's defaults. A user
    # ~/.config/fontconfig/conf.d/*.conf overrides these live (fonts.md
    # §Runtime UX). Each name must match an installed face in packages above or
    # fc-match falls back to DejaVu silently — keep in lockstep. pkgs.inter
    # ships a real static "Inter" family (in Inter.ttc) alongside "Inter
    # Variable" (InterVariable.ttf), so the bare name resolves directly — no
    # alias needed. serif is intentionally absent (→ the base DejaVu).
    fontconfig.defaultFonts = {
      monospace = [ "MonaspiceAr Nerd Font" ];
      sansSerif = [ "Inter" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  # Stylix is no longer the font writer — disable its fontconfig target so it
  # doesn't write a competing fonts.fontconfig.defaultFonts.
  stylix.targets.fontconfig.enable = false;

  # Kept only for the surviving GTK Stylix target's `sizes.popups` (dialog
  # font size) — not the font source of truth. monospace / sansSerif /
  # sizes.terminal have no live consumer post-Firefox-drop (see header); left
  # set rather than pruned (#825 — break nothing in the font pipeline).
  stylix.fonts = {
    monospace = {
      package = pkgs.nerd-fonts.monaspace;
      name = "MonaspiceAr Nerd Font";
    };
    sansSerif = {
      package = pkgs.inter;
      name = "Inter";
    };
    sizes = {
      terminal = profile.fonts.terminal; # vestigial — was Firefox mono size; foot reads the profile directly
      popups = profile.fonts.popups; # GTK dialogs (sans) — the live consumer
    };
  };
}
