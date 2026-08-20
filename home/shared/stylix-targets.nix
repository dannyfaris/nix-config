# Stylix HM-side target enables for the **TUI** stack — the whitelist of
# which HM-managed TUI tools cede their theming to Stylix. Stylix's palette
# propagation comes from `modules/darwin/stylix-palette.nix` (the
# system-side module imported by the Darwin foundation, which sets
# stylix.enable = true and auto-wires HM via homeManagerIntegration).
#
# **Placement.** Darwin-only in practice since #885 took Stylix off the
# NixOS side: celaeno is the sole importer, and any NixOS host importing
# this file would fail eval loudly (no `stylix.targets` option path). It
# nonetheless stays under home/shared/ rather than moving to home/darwin/,
# for the reason lib/scheme-pair.nix and lib/theme-tokens.nix stay under
# lib/: nothing in the file is platform-conditional — only its current
# consumer set is. The shared-purity lint has no opinion here (it flags
# `stdenv.is*`-shaped forks, of which this has none), so this is a
# convention call, recorded rather than enforced. Move it the day a
# platform fork appears in the body.
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
# The one terminal-emulator target that *does* run on Darwin — Ghostty
# — is enabled in `home/darwin/ghostty.nix`, colocated with the rest of
# that module rather than listed here. This whitelist stays terminal-free
# by design: Ghostty is a single Darwin-only module that owns its own
# theming toggle (#256).
#
# The Darwin foundation sets autoEnable = false at the system layer
# (whitelist stance per CLAUDE.md), and that propagates to HM, so each
# target must opt in here. Matches docs/philosophy.md's "explicit >
# implicit" stance.
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
  # via autoEnable. Stylix itself stays enabled on Darwin as the palette
  # engine for lib/scheme-pair.nix + the Ghostty target
  # (home/darwin/ghostty.nix).
  stylix.targets = { };
}
