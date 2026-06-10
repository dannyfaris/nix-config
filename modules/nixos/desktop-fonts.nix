# desktop-fonts — Stylix font configuration + the two NixOS-surface
# wires for hosts that render UI text.
#
# Stylix is the source of truth for font names and packages but
# reaches NixOS only when the operator wires it through. Two wires
# both live in this module: enabling the fontconfig target writes
# stylix.fonts.*.name into fonts.fontconfig.defaultFonts, and the
# explicit fonts.packages assignment installs the four configured
# packages. Headless hosts (mercury, nixos-vm) don't import this
# module and don't pay the font-package closure cost.
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

    # Desktop chrome + terminal share one point size for cross-surface
    # cohesion: foot (terminal slot), waybar (desktop slot), fuzzel +
    # fnott (popups slot) all render at 11. There is no design basis
    # for the terminal being larger than chrome, and foot's pinned
    # `dpi-aware = no` sizes by the output scale factor — the same
    # factor the chrome apps scale by — so one number reads
    # consistently across all four. `applications` keeps the Stylix
    # default — it sizes Firefox's web body text (and Qt apps, of which
    # there are none); GTK app-UI is reassigned to the mono Nerd Font
    # separately. See docs/desktop/fonts.md §Sizing.
    sizes = {
      terminal = 11;
      desktop = 11;
      popups = 11;
    };
  };

  # Wire 1: enable Stylix's fontconfig target so the font names
  # configured above are written into
  # fonts.fontconfig.defaultFonts.{monospace,serif,sansSerif,emoji}.
  # Without this, fc-match falls through to NixOS defaults and any
  # app reading the fontconfig aliases (Firefox, GTK/Qt chrome) gets
  # DejaVu, not the configured selections.
  stylix.targets.fontconfig.enable = true;

  # Wire 2: install the Stylix-configured font packages. Stylix
  # populates stylix.fonts.packages (mono/serif/sans/emoji) for our
  # consumption but does not push to NixOS's fonts.packages itself.
  # Together with the fontconfig target above, this resolves the
  # DejaVu Sans fallback warning foot raised pre-fix. See
  # docs/desktop/fonts.md §Installation model for the full story.
  fonts.packages = config.stylix.fonts.packages;
}
