# Stylix HM-side target enables for the **TUI** stack. Stylix's palette
# propagation comes from each platform's `stylix-palette.nix` (the
# system-side module imported by foundation, which sets stylix.enable
# = true and auto-wires HM via homeManagerIntegration). This module is
# the cross-platform-safe whitelist of which HM-managed TUI tools cede
# their theming to Stylix.
#
# Standalone module, not a bundle — despite the plural filename. It is a
# single coherent capability (the Stylix-TUI-target whitelist) expressed
# as a flat list of `enable` toggles, so it sets options inline and
# lives directly under home/shared/ rather than in bundles/. Bundles are
# pure `imports` aggregations of >= 2 modules (bundle-purity, PRD §8.1
# #4); a whitelist of toggles is not an aggregation. It was mis-filed
# under bundles/ at birth (PR #30, pre-lint) and reclassified here per
# #65 — see ADR-027 §History for the rationale.
#
# Desktop targets (firefox, zen-browser, foot, fuzzel, fnott, waybar,
# gtk, qt) live in `home/nixos/stylix-targets-desktop.nix` because their
# option paths only exist on hosts that import the desktop-env home
# bundle. Splitting them out keeps this file evaluable on Darwin (where
# none of those options exist) — required for mac-mini onboarding
# (#11). The desktop file is imported via `home/nixos/bundles/desktop-env.nix`
# so desktop hosts pick it up transitively.
#
# Foundation sets autoEnable = false at the system layer (whitelist
# stance per CLAUDE.md), and that propagates to HM, so each target
# must opt in here. Matches docs/philosophy.md's "explicit > implicit"
# stance.
#
# If you import this module on a host whose foundation doesn't enable
# Stylix, the option paths below don't exist and eval fails loudly.
#
# btop deliberately omitted — programs.btop isn't enabled anywhere in
# the repo; enabling the Stylix target would generate dead theme
# config + closure bloat. Add when btop earns a place in cli-utils.nix.
#
# eza and lazydocker have no Stylix target upstream. eza uses
# LS_COLORS; lazydocker uses its own colour defaults.
_: {
  stylix.targets = {
    helix.enable = true;
    bat.enable = true;
    fzf.enable = true;
    starship.enable = true;
    zellij.enable = true;
    yazi.enable = true;
    lazygit.enable = true;
    # fish — enables Stylix's HM-side fish target (sets fish_color_*
    # via base16-fish). Fish is the only Stylix target with options on
    # both NixOS and HM layers; foundation deliberately enables
    # neither, so this is the sole switch-on for fish theming.
    fish.enable = true;
  };
}
