# Terminal multiplexer — zellij.
# See docs/decisions/ADR-004-multiplexer.md for rationale.
#
# Default zellij settings already pass OSC52 escape sequences through to
# the terminal emulator (see ADR-011), so no custom clipboard config is
# needed here. Mosh (modules/core/nixos/mosh.nix) handles network-blip
# resilience; zellij handles cross-reboot persistence — they're
# complementary.
_: {
  programs.zellij.enable = true;
}
