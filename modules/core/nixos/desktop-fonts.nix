# desktop-fonts — sans-serif + emoji fonts for hosts that render UI text.
#
# Stylix is the single source of truth for fonts. Foundation sets
# monospace (JetBrains Mono Nerd Font) universally — every host uses a
# monospace font. Sans-serif and emoji only matter on hosts that render
# desktop UI, so they live here in a standalone module imported by the
# desktop-env bundle. Headless hosts (mercury, nixos-vm) don't import
# this module and don't carry the closure (~50 MB of font packages).
#
# Per ADR-028.
{ pkgs, ... }:
{
  stylix.fonts = {
    sansSerif = {
      package = pkgs.inter;
      name = "Inter";
    };
    emoji = {
      package = pkgs.noto-fonts-color-emoji;
      name = "Noto Color Emoji";
    };
  };
}
