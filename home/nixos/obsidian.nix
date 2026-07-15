# obsidian — the Obsidian PKM / notes GUI (the operator's existing vault
# tool; see docs/desktop/obsidian.md).
#
# Installed as a plain home.packages addition, deliberately NOT via the
# upstream `programs.obsidian` HM module — its mechanism conflicts with the
# planned git-carried `.obsidian/` and the recorded update stance; the full
# reasoning (module source read in full) is in docs/design/wiki.md
# §"Authority partition" and its De-risk evidence. Package name is
# `obsidian` per `lib.getName`.
#
# License gating: obsidian is unfree; the name `obsidian` is whitelisted in
# modules/shared/nix-daemon.nix's allowUnfreePredicate.
#
# Wayland: NIXOS_OZONE_WL=1 is set host-wide by
# modules/nixos/electron-wayland.nix and Obsidian is an Electron app, so it
# should render natively under niri. This is an open runtime probe, not a
# guarantee (docs/design/wiki.md De-risk §"pkgs.obsidian on metis under
# niri") — verify post-activation via `niri msg windows`; if it reports as
# XWayland, the lever is an explicit `--ozone-platform-hint=auto` wrapper.
#
# Lives under nixos/ because the launcher integration (xdg-open, app-menu
# discovery of the `.desktop` file via
# /etc/profiles/per-user/dbf/share/applications/) is Linux-only. macOS hosts
# install Obsidian via the `obsidian` Homebrew cask
# (modules/darwin/homebrew.nix; see docs/desktop/obsidian.md §Selection).
#
# This is the GUI only. The git-synced `~/wiki` vault + `services.git-sync`
# service is separate infrastructure (home/shared/wiki.nix, not yet built).
# Per docs/design/wiki.md (#506).
{ pkgs, ... }:
{
  home.packages = [ pkgs.obsidian ];
}
