# Interactive shell — fish.
# See docs/decisions/ADR-001-shell.md for rationale.
#
# System-side fish enable + login-shell change live in
# modules/nixos/users.nix (load-bearing — the system-side enable is the
# /etc/shells gate). This file owns the user-side rc, abbreviations, etc.
_: {
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting

      # Activate starship's transient-prompt collapse — executed prompts
      # redraw as a bare `$character` so scrollback chrome stays minimal.
      # `enable_transience` is defined by starship's own fish init, which
      # home-manager places *after* this block in the generated config.
      # We hook the first `fish_prompt` event (fires once all init has
      # settled), call it, and self-erase. See prompt.nix for the
      # transient format and the rationale for the two-line shape.
      function __enable_transience_once --on-event fish_prompt
        functions -q enable_transience; and enable_transience
        functions --erase __enable_transience_once
      end
    '';

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
