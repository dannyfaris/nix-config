# System packages — administration tools available to all users regardless
# of home-manager state. Per-user dev tooling lives in home/shared/
# (Linux-only fragments in home/nixos/).
#
# Note: ghostty.terminfo is NOT here. It lives in
# `modules/shared/ghostty-terminfo.nix` and is pulled in via
# `modules/nixos/bundles/remote-access.nix` for hosts that need it
# (any host reached remotely from a Ghostty terminal). See ADR-027 for
# the bundle model.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
  ];
}
