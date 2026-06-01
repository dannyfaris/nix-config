# remote-access — host is reachable for remote development.
#
# Mirrors modules/nixos/bundles/remote-access.nix: composes inbound
# SSH (key-only, no root, no password), mosh for session resilience
# over UDP, and the Ghostty terminfo entry so ncurses tools render
# correctly when the client end of the SSH/mosh session is a Ghostty
# terminal.
{
  imports = [
    ../sshd.nix
    ../mosh.nix
    ../../shared/ghostty-terminfo.nix
  ];
}
