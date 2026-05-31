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
      # rationale for the two-line shape.
      function __enable_transience_once --on-event fish_prompt
        functions -q enable_transience; and enable_transience
        functions --erase __enable_transience_once
      end

      # Transient prompt format — starship's transient prompt is shell-
      # side only (it has no `transient_prompt` config key; setting one
      # produces a `[WARN] - (starship::config) ... 'transient_prompt':
      # Unknown key` on every new fish). Defining this function makes
      # starship's fish init invoke it (with `--status` etc.) instead of
      # the hardcoded green-chevron fallback. Forwarding `$argv` to
      # `starship module character` preserves the status code so the
      # chevron stays green (base0B) on success and goes red (base08) on
      # error — via Stylix's injected starship palette. `starship module
      # character` already emits a trailing space, matching the spacing
      # of the active prompt's `$character ` segment — no extra padding.
      function starship_transient_prompt_func
        starship module character $argv
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
      # Open the 3-pane agentic workspace (agent.kdl) in the current dir.
      # See home/shared/multiplexer.nix and GH #5.
      za = "zellij --layout agent";
    };
  };
}
