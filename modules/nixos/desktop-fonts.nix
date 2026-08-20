# desktop-fonts — the NixOS-side font wiring for desktop hosts: install the
# faces and define the fontconfig generic→face map. Imported only by desktop
# hosts (via the desktop-env bundle), so headless hosts (electra) pay no
# font-package closure.
#
# Fonts are conducted by fontconfig (ADR-036 Amendment; #390): surfaces ask
# for a generic (monospace / sans-serif), this map resolves it, and a user
# file in ~/.config/fontconfig/conf.d overrides it at runtime with no
# rebuild. Two jobs, both explicit here:
#   - fonts.packages                — install only the consumed faces.
#   - fonts.fontconfig.defaultFonts — the baseline generic→face map.
#
# Per-surface *sizes* are not here — each surface reads
# lib/display-profiles.nix directly, so size stays coupled to the niri
# output scale rather than to the face selection. See docs/desktop/fonts.md.
#
# Per #390 (Part A); was Stylix-sourced per ADR-028 / #69, until #885 took
# the engine off the NixOS side entirely (ADR-028 §History).
{ pkgs, ... }:
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
}
