# desktop-fonts — Stylix font configuration + installation for hosts
# that render UI text.
#
# Stylix is the source of truth for font names (advertised via
# fonts.fontconfig.defaultFonts) but does not install packages — its
# `stylix.fonts.packages` list is populated for downstream consumption
# without a built-in install wiring. This module both selects the
# font faces and wires the install for desktop hosts. Headless hosts
# (mercury, nixos-vm) don't import this module and don't pay the
# font-package closure cost.
#
# Full rationale, sharp edges, and cadence: docs/desktop/fonts.md.
#
# Per ADR-028; this slice landed under #69.
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

    # foot 1.15.0 changed `dpi-aware` from `auto` to `no`, which
    # Stylix's foot target adopts verbatim. Under that default,
    # `:size=N` (points) is multiplied by the compositor scale rather
    # than the monitor DPI; on a scale-1 output the historical sizing
    # reads smaller than it used to. 11pt approximates the prior
    # visual size; operator may retune as monitor / scale changes
    # accumulate. Original landing: PR #63.
    sizes.terminal = 11;
  };

  # Install the Stylix-configured font packages. Stylix populates
  # stylix.fonts.packages (mono/serif/sans/emoji) for our consumption
  # but does not push to NixOS's fonts.packages itself; this wiring
  # is the missing link. Resolves the DejaVu Sans fallback warning
  # that foot raised pre-fix. See docs/desktop/fonts.md §Installation
  # model for the full story.
  fonts.packages = config.stylix.fonts.packages;
}
