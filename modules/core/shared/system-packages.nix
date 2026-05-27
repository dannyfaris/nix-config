# System packages — administration tools available to all users regardless
# of home-manager state. Per-user dev tooling lives in home/core/shared/
# (Linux-only fragments in home/core/nixos/).
#
# Note: ghostty.terminfo is NOT here. It lives in
# `modules/core/shared/ghostty-terminfo.nix` and is pulled in via
# `modules/core/nixos/bundles/remote-access.nix` for hosts that need it
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
