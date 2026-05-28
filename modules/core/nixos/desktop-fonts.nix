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

    # foot 1.15.0 changed `dpi-aware` from `auto` to `no`, which
    # Stylix's foot target adopts verbatim. Under that default,
    # `:size=N` (points) is multiplied by the compositor scale rather
    # than the monitor DPI; on a scale-1 output the historical sizing
    # reads smaller than it used to. 11pt approximates the prior
    # visual size; operator may retune in slice 5 once metis is live.
    sizes.terminal = 11;
  };
}
