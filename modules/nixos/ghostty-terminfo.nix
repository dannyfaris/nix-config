# Ghostty terminfo entry (xterm-ghostty) — pulled in by
# modules/nixos/bundles/remote-access.nix for NixOS hosts reached over
# SSH/mosh from a Ghostty terminal client.
#
# Required so ncurses-based tools (htop, less, helix, etc.) work when
# SSHing into this host from a Ghostty terminal on the client side.
# Without it, those tools fail at startup with "cannot initialize
# terminal type". This is the terminfo-only output of pkgs.ghostty —
# doesn't pull in the full terminal app.
#
# Lives under modules/nixos/ rather than modules/shared/ because
# pkgs.ghostty.meta.platforms is Linux-only (Ghostty distributes as a
# native .app on macOS, not via nixpkgs). Darwin's remote-access
# bundle omits this; Ghostty clients SSHing into a Darwin host either
# rely on Ghostty's shell-integration ssh-terminfo push (the client
# copies terminfo over on connect), fall back to TERM=xterm-256color
# with reduced rendering fidelity, or wait for a nix-homebrew Ghostty
# cask (#13) to ship terminfo system-wide.
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.ghostty.terminfo
  ];
}
