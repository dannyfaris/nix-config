# ghostty — fast, native, GPU-accelerated Wayland terminal emulator.
#
# Slice 3 enables ghostty with its defaults; theming will track Stylix's
# terminal target. Lives under nixos/ rather than shared/ because the
# desktop bundle is Linux-only — ghostty itself is cross-platform and
# could move to shared/ when Darwin onboarding lands.
#
# The terminfo entry (xterm-ghostty) is already installed system-wide on
# every host via modules/core/shared/ghostty-terminfo.nix
# (imported by the remote-access bundle); this module installs the
# ghostty binary and HM-managed config.
#
# Per ADR-028.
_: {
  programs.ghostty.enable = true;
}
