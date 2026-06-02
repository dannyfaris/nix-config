# Shell prompt — starship (deliberately minimal).
# See docs/decisions/ADR-002-prompt.md for rationale.
#
# Settings declared inline as a nix attrset (programs.starship.settings)
# rather than in a separate starship.toml file. Fish hook auto-wired by
# programs.starship.enable.
_:
let
  # Glyphs decoded from codepoints via fromJSON `"\uXXXX"` escapes —
  # ASCII-safe in source (some editors strip raw PUA UTF-8 bytes) and
  # eval-time-decoded to literal UTF-8 in the rendered config. Pattern
  # matches the macchina recolour at home/nixos/macchina.nix:8.
  desktopGlyph = builtins.fromJSON ''"\uf108"''; # nf-fa-desktop — local
  sshGlyph = builtins.fromJSON ''"\uf489"''; # nf-mdi-console_network — SSH
  snowGlyph = builtins.fromJSON ''"\uf2dc"''; # nf-fa-snowflake — nix-shell
  chev = builtins.fromJSON ''"❯"''; # ❯ — reading-flow separator

  # SSH detection that survives sudo -i / su -. Both strip $SSH_CONNECTION
  # from the elevated environment; who -m's origin-host-in-parens field is
  # the fallback. Mirrors is_ssh() in claude-statusline.sh (pure.zsh trick).
  # Negating it for host_local keeps the two modules exact complements. The
  # snippet uses `$(…)` and `case …;;` — POSIX sh, not fish — so the custom
  # modules below set `shell = ["sh"]` to force evaluation under sh rather
  # than the active interactive shell. Without that, fish rejects `$(…)` in
  # command position ("command substitutions not allowed in command
  # position") and both `when` clauses exit 127, silently dropping the
  # host segment from the prompt. See GH #45.
  sshDetect = ''[ -n "$SSH_CONNECTION" ] || case "$(who -m 2>/dev/null)" in (*\(*\)*) true ;; (*) false ;; esac'';
in
{
  programs.starship = {
    enable = true;

    settings = {
      # Leading host segment via two mutually-exclusive custom modules
      # (one fires based on SSH state — see `sshDetect` above, which
      # survives sudo -i / su -). See ADR-002 history block, GH #17, #45.
      #
      # `$nix_shell` slots between `$directory` and `$git_branch` so the
      # `(❄️)` renders as path-metadata (matches the statusline). See
      # ADR-002's `(…)`-as-metadata convention.
      #
      # `$line_break` before `$character` puts metadata on line 1 and
      # the prompt chevron on its own line 2 — Pure-style two-line shape.
      # Trades one vertical line per active prompt for an unbounded
      # typing area, and pairs with the transient prompt (defined in
      # shell.nix as `starship_transient_prompt_func`) so executed
      # prompts collapse to a bare chevron in scrollback (net negative
      # vertical chrome vs the previous single-line layout).
      format = "\${custom.host_local}\${custom.host_ssh}$directory$nix_shell$git_branch$git_status$line_break$character";
      # `add_newline` controls the blank line *between* commands, not
      # within a prompt. Compact spacing stays.
      add_newline = false;

      # Per-module styles — match the role-based palette mapping in the
      # Claude statusline. Stylix exposes both base16-slot names (base0D
      # etc.) AND friendly aliases (blue, cyan, green, yellow, purple,
      # red) in the active palette. We use the friendly aliases because
      # starship silently rejects `base0X`-style names (treats them as
      # something other than palette lookups), causing every style to
      # fall through to default foreground.
      #
      # blue = base0D / cyan = base0C / green = base0B / yellow = base0A
      # / purple = base0E / red = base08 — all wired by Stylix.
      directory.style = "blue";
      git_branch.style = "cyan";

      # Git status substatuses self-style; outer format drops the default
      # brackets + shared style. `~` for modified mirrors the statusline
      # (starship default is `!`); each substatus carries its own colour.
      # `$ahead_behind` is intentionally omitted from the format — the
      # statusline doesn't surface ahead/behind, and we're prioritising
      # parity between the two surfaces. Add back here (and in the
      # statusline) if the upstream-divergence signal earns its place.
      #
      # Untracked uses `orange` (base09) rather than the base16-canonical
      # `purple` (base0E) so the SSH host marker (which uses purple) is
      # the only purple element on the line. See agent-clis.nix and
      # claude-statusline.sh for the matching statusline change.
      git_status = {
        conflicted = " [!\${count}](red)";
        staged = " [+\${count}](green)";
        modified = " [~\${count}](yellow)";
        untracked = " [?\${count}](orange)";
        format = "$all_status";
        style = "";
      };

      # Nix-shell indicator — renders as `(❄️)` path-metadata immediately
      # after `$directory` (see format string above). Parens are escaped
      # (`\(` / `\)`) because starship treats unescaped `(...)` as a
      # "render-if-non-empty" conditional group, not literal parens. Only
      # the snowflake picks up `$style`; the parens stay default
      # foreground. Matches the statusline's conditional `(❄️)` segment.
      # See ADR-002's `(…)`-as-metadata convention.
      nix_shell = {
        format = "\\([$symbol]($style)\\) ";
        # U+F2DC nf-fa-snowflake. Previously U+2744 + VS16, which forces
        # emoji presentation (width 2) while Zellij's grid reads U+2744 as
        # width 1 -- producing the phantom `( )` gap. The PUA codepoint
        # has a stable width-1 cell. Matches the statusline's NIX_GLYPH.
        symbol = snowGlyph;
        style = "blue"; # nix blue (base0D via Stylix palette)
      };

      # Host segments — glyph + hostname styled by SSH state. Chevron
      # separator stays outside the style markup (default foreground)
      # to keep visual delineation between the host chip and `$directory`.
      # Counterpart in the statusline lives in claude-statusline.sh's
      # HOST_COLOUR derivation.
      custom.host_local = {
        description = "Hostname marker — local (no SSH connection)";
        when = "! { ${sshDetect}; }";
        command = "hostname -s";
        shell = [ "sh" ]; # see sshDetect comment in let block — fish chokes on `$(…)` in `when`
        format = "[${desktopGlyph}  $output]($style) ${chev} ";
        style = "green";
      };
      custom.host_ssh = {
        description = "Hostname marker — over SSH";
        when = sshDetect;
        command = "hostname -s";
        shell = [ "sh" ]; # see sshDetect comment in let block — fish chokes on `$(…)` in `when`
        format = "[${sshGlyph}  $output]($style) ${chev} ";
        style = "purple";
      };
    };
  };
}
