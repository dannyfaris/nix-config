# typora — the Typora markdown editor (the operator's daily-driver
# long-form markdown editor; see docs/desktop/typora.md).
#
# Installed as a plain home.packages addition. Package name is `typora`
# per `lib.getName`.
#
# License gating: typora is unfree; the name `typora` is whitelisted in
# modules/shared/nix-daemon.nix's allowUnfreePredicate.
#
# Wayland: the Linux package is Electron-based, and its wrapper appends
# the ozone Wayland flags itself, gated on NIXOS_OZONE_WL + WAYLAND_DISPLAY
# (nixpkgs pkgs/by-name/ty/typora/package.nix). NIXOS_OZONE_WL=1 is set
# host-wide by modules/nixos/electron-wayland.nix, so it renders native
# Wayland under niri without extra wiring.
#
# Default markdown handler: the two MIME types typora.desktop declares in
# its MimeType line (text/markdown, text/x-markdown) are routed to Typora
# via xdg.mimeApps.defaultApplications. `xdg.mimeApps.enable` is not set
# here: firefox.nix already enables it and both modules are imported
# together by the desktop-env bundle, so defaultApplications merges by key
# (no overlap with firefox's URL-scheme handlers).
#
# Lives under nixos/ because the launcher integration (xdg-open, app-menu
# discovery of the `.desktop` file, the xdg.mimeApps registration) is
# Linux-only. macOS hosts install Typora via the `typora` Homebrew cask
# (modules/darwin/homebrew.nix; see docs/desktop/typora.md §Darwin).
{ pkgs, ... }:
{
  home.packages = [ pkgs.typora ];

  xdg.mimeApps.defaultApplications = {
    "text/markdown" = "typora.desktop";
    "text/x-markdown" = "typora.desktop";
  };
}
