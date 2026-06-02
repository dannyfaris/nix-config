# System packages — administration tools available to all users regardless
# of home-manager state. Per-user dev tooling lives in home/shared/
# (Linux-only fragments in home/nixos/).
#
# Note: ghostty.terminfo is NOT here. It lives in
# `modules/nixos/ghostty-terminfo.nix` and is pulled in via
# `modules/nixos/bundles/remote-access.nix` for NixOS hosts reached
# remotely from a Ghostty terminal. (Linux-only because
# `pkgs.ghostty.meta.platforms` is Linux-only.) See ADR-027 for the
# bundle model.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
  ];
}
