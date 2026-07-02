# stylix-palette — per-host base16 palette + the Stylix engine for
# Darwin. Mirrors modules/nixos/stylix-palette.nix; differs only in
# importing `inputs.stylix.darwinModules.stylix` (the Darwin half of
# upstream Stylix's flake outputs) instead of the NixOS module.
#
# This is the *system half* of the repo's theming wiring on Darwin.
# Since ADR-041 the TUI surface follows the terminal palette (the
# target whitelist in `home/shared/stylix-targets.nix` is empty);
# this engine remains as the colour table the statuslines read and
# the palette source for lib/scheme-pair.nix + the Ghostty target
# (home/darwin/ghostty.nix).
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
# use; the one active target (Ghostty) needs neither. If those land
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
    # Per-host slot corrections for ports that violate base16 slot
    # intents, merged over the scheme by base16.nix. Empty for
    # conformant hosts. See ADR-028 §History (2026-06-10, #331).
    override = palette.overrides.${palette.polarity} or { };

    # Carve-out: silence Stylix's release-check warning on Darwin until
    # LnL7/nix-darwin master bumps its version.json from "26.05" to
    # "26.11". The same flake.lock commit that introduced this line
    # bumped Stylix from release 26.05 → 26.11 to match the nixpkgs
    # 26.11 codename that #189 landed; the NixOS-side warning
    # (Stylix-vs-Home-Manager) is genuinely resolved by that bump, but
    # nix-darwin upstream still declares 26.05 and Stylix's release
    # check then warns Stylix-vs-nix-darwin. The drv hash is unchanged
    # — this is a warning, not an error — but suppression is cleaner
    # than leaving a known-knock-on warning printing on every Darwin
    # activation. Remove this line in a one-line PR when
    # https://github.com/LnL7/nix-darwin/blob/master/version.json
    # flips to "26.11".
    enableReleaseChecks = false;
  };
}
