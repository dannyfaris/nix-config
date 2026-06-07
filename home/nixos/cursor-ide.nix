# cursor-ide — Cursor IDE (the AI-coding-focused vscode fork).
#
# Installed as a plain home.packages addition rather than via a
# `programs.X` HM module because there is no upstream HM module for
# Cursor; it ships in nixpkgs as `code-cursor` (binary name `cursor`,
# package name `cursor` per `lib.getName` — distinct from cursor-cli
# which is already on PATH via home/shared/agent-clis.nix).
#
# Wayland-native rendering is handled host-wide by
# modules/nixos/electron-wayland.nix (sets NIXOS_OZONE_WL=1);
# nixpkgs' vscode wrapper auto-detects that variable plus
# WAYLAND_DISPLAY and appends the ozone Wayland flags at startup.
# Verify post-activation via `niri msg windows` — Cursor's window
# should report as a native Wayland client, not XWayland.
#
# License gating: code-cursor is unfree; the package name `cursor` is
# whitelisted in modules/shared/nix-daemon.nix's
# allowUnfreePredicate.
#
# Lives under nixos/ because the launcher integration (xdg-open,
# fuzzel discovery via /etc/profiles/per-user/dbf/share/applications/)
# is Linux-only. macOS hosts install Cursor via the `cursor` Homebrew
# cask (modules/darwin/homebrew.nix; see docs/desktop/cursor.md).
#
# No Stylix integration day 1: Stylix's vscode target gates on
# `programs.vscode.enable` and writes to ~/.config/Code, not
# ~/.config/Cursor. If chrome theming becomes useful later, the lever
# is Cursor's own settings UI; Stylix support for Cursor specifically
# would need an upstream target.
#
# Per #77.
{ pkgs, ... }:
{
  home.packages = [ pkgs.code-cursor ];
}
