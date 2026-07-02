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
# Desktop targets (firefox, foot, niri, gtk) live in
# `home/nixos/stylix-targets-desktop.nix` because their option paths only
# exist on hosts that import the desktop-env home bundle. Splitting them out
# keeps this file evaluable on Darwin (where none of those options exist) —
# required for mac-mini onboarding (#11). The desktop file is imported via
# `home/nixos/bundles/desktop-env.nix` so desktop hosts pick it up
# transitively.
#
# The one terminal-emulator target that *does* run on Darwin — Ghostty
# — is enabled in `home/darwin/ghostty.nix`, colocated with the rest of
# that module rather than listed here. This whitelist stays
# terminal-free by design: foot's target is desktop-env-only (above),
# and Ghostty is a single Darwin-only module that owns its own theming
# toggle (#256).
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
    # fish deliberately omitted (removed 2026-07-02, #499). The target
    # sources base16-fish, which OSC-paints the terminal (bg/fg + 16
    # slots) with the *built* polarity at every shell init — clobbering
    # Ghostty's native dual-theme on neptune, and doing the same to any
    # window SSH'd into a fleet host (the original per-host-identity
    # intent, judged not worth the interference). Fish falls back to its
    # own defaults; dual [light]/[dark] fish theme sections are the
    # follow-up if fish colours are missed.
  };
}
