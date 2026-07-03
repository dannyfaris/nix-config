# Shell prompt — starship (deliberately minimal).
# See docs/decisions/ADR-002-prompt.md for rationale.
#
# Settings declared inline as a nix attrset (programs.starship.settings)
# rather than in a separate starship.toml file. Fish hook auto-wired by
# programs.starship.enable.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Role→ANSI projection from the design tokens; only the static `.ansi`
  # field is read (the config-forcing `.hex` is never touched).
  tokens = import ../../lib/theme-tokens.nix { inherit config; };

  # Glyphs decoded from codepoints via fromJSON `"\uXXXX"` escapes —
  # ASCII-safe in source (some editors strip raw PUA UTF-8 bytes) and
  # eval-time-decoded to literal UTF-8 in the rendered config. Pattern
  # matches the macchina recolour at home/nixos/macchina.nix:8.
  desktopGlyph = builtins.fromJSON ''"\uf108"''; # nf-fa-desktop — local
  sshGlyph = builtins.fromJSON ''"\uf489"''; # nf-mdi-console_network — SSH
  snowGlyph = builtins.fromJSON ''"\uf2dc"''; # nf-fa-snowflake — nix-shell
  chev = builtins.fromJSON ''"❯"''; # ❯ — reading-flow separator

  # Host-marker connection detection (local vs SSH) — delegates to the
  # shared `session-type` command (home/shared/session-type.nix). Inside
  # zellij it reads the live *client's* connection instead of the pane's
  # frozen $SSH_CONNECTION, so the glyph is correct after a detach/reattach
  # across contexts (#270); outside zellij it's the prior $SSH_CONNECTION +
  # who -m check (survives sudo -i / su -). The two custom modules below are
  # mutually exclusive on its `ssh`/`local` output — host_local fires on
  # anything that isn't `ssh`, so an unexpected/empty result still renders
  # the safe local glyph rather than dropping the segment. Referenced by
  # absolute store path (lib.getExe) so a missing PATH entry can't silently
  # drop the host segment. The `when` snippet uses `$(…)` and `[ … ]` —
  # POSIX sh, not fish — so the modules set `shell = ["sh"]`; without it
  # fish rejects `$(…)` in command position and both clauses exit 127,
  # dropping the host segment. See GH #45.
  sessionType = pkgs.callPackage ./session-type.nix { };
  sessionTypeExe = lib.getExe sessionType;
in
{
  programs.starship = {
    enable = true;

    settings = {
      # Leading host segment via two mutually-exclusive custom modules
      # (one fires on the shared session-type output — see the sessionType
      # comment above; SSH state survives sudo -i / su -). See ADR-002
      # history block, GH #17, #45.
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

      # Per-module styles — starship's *native* ANSI colour names (blue,
      # cyan, green, yellow, purple, red), which resolve through the
      # terminal's 16-colour palette. Terminal-following by construction:
      # the prompt repaints with the terminal on a polarity flip, and an
      # SSH session renders in the local terminal's palette (the Stylix
      # starship target that used to inject these as baked-hex palette
      # aliases is dropped — see stylix-targets.nix).
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
      # Untracked carries the *attention* role (base09/orange in the
      # statuslines) rather than the base16-canonical purple, so the SSH
      # host marker (purple) stays the only purple element on the line.
      # Styled via the tokens' ANSI projection — the 16-colour bus has no
      # orange slot, so this renders the nearest on-bus colour
      # (bright-yellow; warm gold in gruvbox). See lib/theme-tokens.nix.
      git_status = {
        conflicted = " [!\${count}](red)";
        staged = " [+\${count}](green)";
        modified = " [~\${count}](yellow)";
        untracked = " [?\${count}](${tokens.color.role.attention.ansi})";
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
        style = "blue"; # nix blue (ANSI blue — base0D on the terminal bus)
      };

      # Host segments — glyph + hostname styled by SSH state. Chevron
      # separator stays outside the style markup (default foreground)
      # to keep visual delineation between the host chip and `$directory`.
      # Counterpart in the statusline lives in claude-statusline.sh's
      # HOST_COLOUR derivation.
      custom.host_local = {
        description = "Hostname marker — local (no SSH connection)";
        when = ''[ "$(${sessionTypeExe})" != ssh ]'';
        command = "hostname -s";
        shell = [ "sh" ]; # see sessionType comment in let block — fish chokes on `$(…)` in `when`
        format = "[${desktopGlyph}  $output]($style) ${chev} ";
        style = "green";
      };
      custom.host_ssh = {
        description = "Hostname marker — over SSH";
        when = ''[ "$(${sessionTypeExe})" = ssh ]'';
        command = "hostname -s";
        shell = [ "sh" ]; # see sessionType comment in let block — fish chokes on `$(…)` in `when`
        format = "[${sshGlyph}  $output]($style) ${chev} ";
        style = "purple";
      };
    };
  };
}
