# stylix-palette — per-host base16 palette + the Stylix engine for
# Darwin. Mirrors modules/nixos/stylix-palette.nix; differs only in
# importing `inputs.stylix.darwinModules.stylix` (the Darwin half of
# upstream Stylix's flake outputs) instead of the NixOS module.
#
# This is the *system half* of the repo's theming wiring on Darwin;
# the home half is the cross-platform `home/shared/stylix-targets.nix`
# (TUI targets — helix/bat/fzf/starship/zellij/yazi/lazygit/fish).
# Darwin hosts don't pick up `home/nixos/stylix-targets-desktop.nix`
# (which is gated by the `home/nixos/bundles/desktop-env.nix` bundle
# they don't import).
#
# Per-host palette comes from lib/host-palettes.nix keyed on
# hostContext.hostName. Missing-host lookups fail loudly at eval.
#
# autoEnable = false is the whitelist stance per CLAUDE.md "Deliberate
# stances" — every Stylix target is enabled deliberately, not auto-
# detected. The HM-side target enables live in stylix-targets.nix.
#
# Known upstream Darwin gaps (Stylix issues #2078, #440 as of 2026-05)
# affect `stylix.cursor` and `stylix.opacity` — neither of which we
# use; our active targets are platform-pure TUI tools. If those land
# fixes upstream, they cost nothing here.
#
# Imported by foundation.nix, so every Darwin host gets a palette.
{
  inputs,
  pkgs,
  hostContext,
  ...
}:
let
  palettes = import ../../lib/host-palettes.nix;
  palette = palettes.${hostContext.hostName};
  # Polarity drives scheme selection — a single host-side toggle flips
  # both the base16 palette and the cross-app dark/light signal,
  # eliminating the lockstep-by-convention coupling the previous
  # interim shape (#123 / #141) carried. Fails loudly with a clear
  # message if a host's polarity is set to a variant it hasn't
  # declared.
  scheme =
    palette.schemes.${palette.polarity}
      or (throw "host-palettes: ${hostContext.hostName} has no `${palette.polarity}` scheme declared");
in
{
  imports = [ inputs.stylix.darwinModules.stylix ];

  stylix = {
    enable = true;
    autoEnable = false;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/${scheme}.yaml";
    inherit (palette) polarity;
  };
}
