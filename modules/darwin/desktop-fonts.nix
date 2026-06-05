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
#   - No sizes.terminal. That value is a foot DPI accommodation (see
#     the NixOS module); on Darwin Ghostty owns its own font sizing.
#
# What this module *does*: install config.stylix.fonts.packages into
# nix-darwin's fonts.packages, which symlinks the faces into
# /Library/Fonts (the system-wide font directory). After activation
# the faces are selectable by name in any Mac app via Core Text /
# Font Book. Consumers are thinner than on NixOS — there's no
# fontconfig alias layer and Ghostty bundles its own JetBrainsMono —
# so the practical effect is availability + parity, not an automatic
# re-render anywhere.
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
    monospace = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
    };
    sansSerif = {
      package = pkgs.inter;
      name = "Inter";
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
