# Ghostty terminfo entry (xterm-ghostty) — extracted from system-packages
# so it can sit in the remote-access bundle alongside sshd + mosh, which
# is what makes it relevant.
#
# Required so ncurses-based tools (htop, less, etc.) work when SSHing
# into this host from a Ghostty terminal on the client side. Without it,
# those tools fail at startup with "cannot initialize terminal type".
# This is the terminfo-only output of pkgs.ghostty — doesn't pull in the
# full terminal app.
#
# During slice 2 of the role-removal migration this entry is duplicated
# in modules/core/nixos/system-packages.nix; Nix module merging
# deduplicates so closures stay byte-identical. The duplicate line in
# system-packages.nix is removed in slice 4 once no host imports
# system-packages directly via the role.
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.ghostty.terminfo
  ];
}
