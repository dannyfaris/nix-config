# Ghostty terminfo entry (xterm-ghostty) — pulled in by
# `bundles/remote-access.nix` for hosts reachable over SSH/mosh from a
# Ghostty terminal client.
#
# Required so ncurses-based tools (htop, less, etc.) work when SSHing
# into this host from a Ghostty terminal on the client side. Without it,
# those tools fail at startup with "cannot initialize terminal type".
# This is the terminfo-only output of pkgs.ghostty — doesn't pull in the
# full terminal app.
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.ghostty.terminfo
  ];
}
