# Interactive shell — fish.
# See docs/decisions/ADR-001-shell.md for rationale.
#
# System-side fish enable + login-shell change live in
# modules/core/nixos/users.nix (load-bearing — the system-side enable is the
# /etc/shells gate). This file owns the user-side rc, abbreviations, etc.
_: {
  programs.fish = {
    enable = true;
    interactiveShellInit = "set -g fish_greeting";

    # Sparse abbreviation set. Fish abbreviations expand inline so the
    # actual command is visible in history — preferred over aliases.
    shellAbbrs = {
      g = "git";
      nrs = "sudo nixos-rebuild switch --flake .";
    };
  };
}
