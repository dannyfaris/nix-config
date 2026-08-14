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
# Desktop-only targets live in `home/nixos/stylix-targets-desktop.nix`,
# imported transitively via `home/nixos/bundles/desktop-env.nix`.
# Why the split: see that file's header — architectural co-location,
# not Darwin evaluability.
#
# The one terminal-emulator target that *does* run on Darwin — Ghostty
# — is enabled in `home/darwin/ghostty.nix`, colocated with the rest of
# that module rather than listed here. This whitelist stays terminal-free
# by design: foot has carried no Stylix target since #385 (its palette
# comes from Noctalia's foot template — see `home/nixos/foot.nix`), and
# Ghostty is a single Darwin-only module that owns its own
# theming toggle (#256).
#
# Foundation sets autoEnable = false at the system layer (whitelist
# stance per CLAUDE.md), and that propagates to HM, so each target
# must opt in here. Matches docs/philosophy.md's "explicit > implicit"
# stance.
#
# If you import this module on a host whose foundation doesn't enable
# Stylix, the `stylix.targets` option path doesn't exist and eval
# fails loudly.
_: {
  # The whitelist is deliberately EMPTY (2026-07-02): the TUI surface
  # converted from build-time Stylix hex to terminal-following ANSI
  # config — the terminal palette is the runtime colour bus, so every
  # TUI repaints with a polarity flip and renders in the local palette
  # over SSH. See ADR-041 for the direction (ends ADR-028 item 1's TUI
  # clause; the fish target's OSC clobber of Ghostty's dual theme was
  # the precipitating find, #499). Per-tool config lives with each tool:
  # bat/fzf/yazi/lazygit (cli-utils.nix), helix (editor.nix), zellij
  # (multiplexer.nix), starship (prompt.nix).
  #
  # The module (and its whitelist stance) survives empty: a future tool
  # with no ANSI mode re-enters through an explicit enable here, never
  # via autoEnable. Stylix itself stays enabled fleet-wide as the colour
  # table for the statuslines (#411) and the palette engine for
  # lib/scheme-pair.nix + the Ghostty target (home/darwin/ghostty.nix).
  stylix.targets = { };
}
