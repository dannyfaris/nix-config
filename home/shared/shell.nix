# Interactive shell — fish.
# See docs/decisions/ADR-001-shell.md for rationale.
#
# System-side fish enable + login-shell change live in
# modules/nixos/users.nix (load-bearing — the system-side enable is the
# /etc/shells gate). This file owns the user-side rc, abbreviations, etc.
_: {
  programs.fish = {
    enable = true;
    interactiveShellInit = "set -g fish_greeting";

    # Terminal title — surfaces SSH context in the emulator's tab/window
    # chrome (Ghostty etc.). Lives above the shell layer; complements the
    # starship host segment (always-on, glyph-swap) and the per-host
    # Stylix palette. See GH #6.
    functions.fish_title = ''echo (hostname -s)": "(prompt_pwd)'';

    # Sparse abbreviation set. Fish abbreviations expand inline so the
    # actual command is visible in history — preferred over aliases.
    shellAbbrs = {
      g = "git";
      nos = "nh os switch";
    };
  };
}
