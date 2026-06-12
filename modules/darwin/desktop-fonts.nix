# desktop-fonts (Darwin) — install the Stylix-configured font faces
# system-wide on macOS. The Darwin parallel of
# modules/nixos/desktop-fonts.nix.
#
# Same selections, fewer wires. Two things the NixOS module does that
# don't apply here:
#
#   - No fontconfig target. macOS resolves fonts through Core Text,
#     which reads /Library/Fonts directly; fontconfig isn't the
#     resolver, so stylix.targets.fontconfig.enable would write a
#     defaultFonts map nothing on this platform consults. Omitted.
#   - No font sizes. The NixOS module unifies the desktop surfaces
#     (foot/waybar/fuzzel/fnott) on one point size for cohesion; on
#     Darwin Ghostty owns its own font sizing, so there's nothing to
#     mirror. See docs/desktop/fonts.md §Sizing.
#
# What this module *does*: install config.stylix.fonts.packages into
# nix-darwin's fonts.packages, which symlinks the faces into
# /Library/Fonts (the system-wide font directory). After activation
# the faces are selectable by name in any Mac app via Core Text /
# Font Book. Consumers are thinner than on NixOS — there's no
# fontconfig alias layer — but Stylix's ghostty target sets Ghostty's
# font-family from the monospace slot (home/darwin/ghostty.nix), so the
# terminal face tracks this module: the #369 swap to Monaspace Argon
# re-renders Ghostty (the operator's own font-size pin stays).
#
# (config.stylix.fonts.packages carries the full Stylix set, so the
# serif default — DejaVu Serif — rides along with the three named
# families below. Same closure shape as the NixOS module.)
#
# An alternative to the explicit fonts.packages assignment below is
# Stylix's own `font-packages` target
# (stylix.targets.font-packages.enable), which performs the identical
# assignment. The explicit form is used here to mirror the NixOS
# module verbatim; both read the same under autoEnable = false.
#
# Full rationale and the NixOS-side story: docs/desktop/fonts.md.
#
# Imported by foundation.nix — every Darwin host is GUI, so unlike the
# NixOS side (gated behind the desktop-env bundle for headless hosts)
# there's no desktop gate to respect.
#
# Per #209.
{ config, pkgs, ... }:
{
  stylix.fonts = {
    # Terminal face — Monaspace Argon Nerd Font (matches foot on NixOS).
    # Stylix's ghostty target renders Ghostty from this slot (see header).
    monospace = {
      package = pkgs.nerd-fonts.monaspace;
      name = "MonaspiceAr Nerd Font";
    };
    # UI/web sans — IBM Plex Sans, installed for parity. macOS chrome uses
    # the system font; this backs the sans-serif alias for any
    # fontconfig-aware app, not native UI.
    sansSerif = {
      package = pkgs.ibm-plex;
      name = "IBM Plex Sans";
    };
    emoji = {
      package = pkgs.noto-fonts-color-emoji;
      name = "Noto Color Emoji";
    };
  };

  # The sole install wire (see header for why there's no second one):
  # nix-darwin's fonts.packages symlinks each face into /Library/Fonts.
  fonts.packages = config.stylix.fonts.packages;
}
