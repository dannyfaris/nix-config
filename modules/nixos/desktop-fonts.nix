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
let
  # The three surface font sizes come from the active display profile, so they
  # stay coupled to the niri output scale (metis runs 2×). See
  # lib/display-profiles.nix.
  profile = import ../../lib/display-profiles.nix;
in
{
  stylix.fonts = {
    # Mono face — Monaspace Argon (humanist mono), Nerd Font variant for the
    # powerline/devicon/file-type glyphs starship/zellij/lazygit rely on. In the
    # hybrid font model it backs the terminal (foot) + the bar (waybar) +
    # the launcher (fuzzel); the Nerd Font carries waybar's network/tray glyphs
    # directly, so no Symbols fallback is needed. The fontconfig name is the Nerd
    # Font's abbreviation: "MonaspiceAr" = Monaspace Argon.
    monospace = {
      package = pkgs.nerd-fonts.monaspace;
      name = "MonaspiceAr Nerd Font";
    };
    # Sans + web-body face — IBM Plex Sans (coheres with the Carbon spacing scale
    # already adopted). In the hybrid font model it backs notifications (fnott) +
    # GTK dialogs + web/document body, and the sans-serif fontconfig alias.
    sansSerif = {
      package = pkgs.ibm-plex;
      name = "IBM Plex Sans";
    };
    emoji = {
      package = pkgs.noto-fonts-color-emoji;
      name = "Noto Color Emoji";
    };

    # M3 type ramp (role-derived steps; #369), sized by the active display
    # profile so the band stays coupled to the niri scale: waybar (desktop slot,
    # mono) ≈ M3 label-medium; fnott + GTK dialogs (popups slot, sans) ≈ M3 body;
    # foot (terminal slot, mono) sized on its own legibility terms. The on-vocab
    # band (foot 11 / bar 13 / notif + dialog 12) lives on the 1.5× profile and
    # is scaled per profile. `applications` keeps the Stylix default (12) — it
    # sizes Firefox's web body text. The type.size tokens alias these. See
    # docs/desktop/fonts.md §Sizing, theme-tokens.nix, and lib/display-profiles.nix.
    sizes = {
      terminal = profile.fonts.terminal; # foot (mono)
      desktop = profile.fonts.desktop; # waybar (mono)
      popups = profile.fonts.popups; # fnott + GTK dialogs (sans)
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
