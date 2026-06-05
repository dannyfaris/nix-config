# remote-access — host is reachable for remote development.
#
# Composes inbound SSH (key-only, no root, no password) and the Ghostty
# terminfo entry so ncurses tools render correctly when the client end of
# the SSH session is a Ghostty terminal. (mosh was removed in #47 — its
# terminal emulator can't carry the per-host palette over the wire; see
# ADR-011.)
{
  imports = [
    ../sshd.nix
    ../ghostty-terminfo.nix
  ];
}
