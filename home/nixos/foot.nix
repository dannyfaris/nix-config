# foot — fast, lightweight, Wayland-native terminal emulator.
#
# Slice 3 enables foot with its defaults. Stylix theming is wired
# centrally via `stylix.targets.foot.enable = true` in
# home/nixos/stylix-targets-desktop.nix; Stylix writes
# `programs.foot.settings.main.{font,dpi-aware,initial-color-theme}`
# plus per-polarity colour palette. If we ever set our own
# `programs.foot.settings` here, watch for option conflicts — Stylix
# hardcodes `dpi-aware = "no"`, which honours pt-based font sizing but
# disables per-monitor DPI scaling. On HiDPI external displays the
# operator may want to revisit; the lever is Stylix's font surface,
# not `programs.foot.settings.main` (which would conflict).
#
# Lives under nixos/ because foot is Wayland-only and doesn't compile
# off Linux — there is no cross-platform variant to share. macOS hosts
# get Ghostty instead (via a future home/darwin/ module, per the
# mac-mini onboarding epic #11); the server-side terminfo for
# Ghostty (xterm-ghostty) lives at modules/nixos/ghostty-terminfo.nix
# and ships on every NixOS host so SSH'ing into any NixOS host from a
# Ghostty-on-Mac terminal renders cleanly. (NixOS-only because
# `pkgs.ghostty` doesn't ship on aarch64-darwin; Darwin SSH targets
# rely on Ghostty's shell-integration ssh-terminfo push instead.)
#
# Per ADR-028 (Implementation amendment — terminal swapped from Ghostty
# to Foot, 2026-05-28).
_: {
  programs.foot.enable = true;
}
