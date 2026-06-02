# remote-access — host is reachable for remote development.
#
# Composes inbound SSH (key-only, no root, no password), mosh for
# session resilience over UDP, and the Ghostty terminfo entry so
# ncurses tools render correctly when the client end of the SSH/mosh
# session is a Ghostty terminal.
{
  imports = [
    ../sshd.nix
    ../mosh.nix
    ../ghostty-terminfo.nix
  ];
}
