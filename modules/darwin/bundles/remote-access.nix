# remote-access — host is reachable for remote development.
#
# Composes inbound SSH (key-only, no root, no password) and mosh for
# session resilience over UDP. Sibling of
# modules/nixos/bundles/remote-access.nix; the NixOS variant also
# ships pkgs.ghostty.terminfo via modules/nixos/ghostty-terminfo.nix,
# but Ghostty isn't packaged for aarch64-darwin (ships as a native
# .app on macOS), so the Darwin bundle omits it. Ghostty clients
# SSHing into a Darwin host get terminfo via Ghostty's own
# shell-integration ssh-terminfo push on connect, or fall back to
# TERM=xterm-256color.
{
  imports = [
    ../sshd.nix
    ../mosh.nix
  ];
}
