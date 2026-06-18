# desktop-fonts — the NixOS-side font wiring for desktop hosts: install the
# faces and define the fontconfig generic→face map. Imported only by desktop
# hosts (via the desktop-env bundle), so headless hosts (mercury, nixos-vm)
# pay no font-package closure.
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
# stylix.fonts is kept — but is no longer the font source of truth — only
# because two surviving Stylix targets read it under E1: the Firefox target
# (per-profile font.name; face-swap-only, so Firefox renders Inter but stays
# pinned, not following the runtime override, until Part B) and the GTK target.
# stylix.fonts.sizes also feeds the type.size tokens. See docs/desktop/fonts.md.
#
# Per #390 (Part A); was Stylix-sourced per ADR-028 / #69.
{ pkgs, ... }:
let
  # Per-surface sizes come from the active display profile (metis: 2×), so they
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

    fontconfig = {
      # The baseline generic→face map — the conductor's defaults. A user
      # ~/.config/fontconfig/conf.d/*.conf overrides these live (fonts.md
      # §Runtime UX). Each name must match an installed face above (Inter via
      # the alias below) or fc-match falls back to DejaVu silently — keep this
      # in lockstep with packages. serif is intentionally absent (→ DejaVu).
      defaultFonts = {
        monospace = [ "MonaspiceAr Nerd Font" ];
        sansSerif = [ "Inter" ];
        emoji = [ "Noto Color Emoji" ];
      };

      # pkgs.inter is variable-only — its fontconfig family is "Inter Variable",
      # not "Inter", and nothing aliases it. Map the friendly "Inter" name onto
      # it so the map above, the Firefox face pin, GTK's Sans, and `set-font
      # sans Inter` all resolve (a bare "Inter" otherwise silently → DejaVu).
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
        <fontconfig>
          <alias binding="same">
            <family>Inter</family>
            <prefer><family>Inter Variable</family></prefer>
          </alias>
        </fontconfig>
      '';
    };
  };

  # Stylix is no longer the font writer — disable its fontconfig target so it
  # doesn't write a competing fonts.fontconfig.defaultFonts.
  stylix.targets.fontconfig.enable = false;

  # Kept only for the surviving E1 Stylix targets (Firefox font.name; GTK
  # size) — not the font source of truth. sansSerif = Inter is the face-swap
  # that makes Firefox's pinned web body render Inter (see header). serif/emoji
  # are unset (Stylix defaults; the surviving targets don't consume them).
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
      terminal = profile.fonts.terminal; # foot (mono)
      desktop = profile.fonts.desktop; # type.size token (chrome)
      popups = profile.fonts.popups; # GTK dialogs (sans)
    };
  };
}
