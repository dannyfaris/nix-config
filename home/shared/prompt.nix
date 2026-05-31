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
  chev = builtins.fromJSON ''"❯"''; # ❯ — reading-flow separator
in
{
  programs.starship = {
    enable = true;

    settings = {
      # Leading host segment via two mutually-exclusive custom modules
      # (one fires based on $SSH_CONNECTION). See ADR-002 history block
      # and GH issue #17.
      #
      # `$nix_shell` slots between `$directory` and `$git_branch` so the
      # `(❄️)` renders as path-metadata (matches the statusline). See
      # ADR-002's `(…)`-as-metadata convention.
      format = "\${custom.host_local}\${custom.host_ssh}$directory$nix_shell$git_branch$git_status$character";
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
        symbol = "❄️";
        style = "blue"; # nix blue (base0D via Stylix palette)
      };

      # Host segments — glyph + hostname styled by SSH state. Chevron
      # separator stays outside the style markup (default foreground)
      # to keep visual delineation between the host chip and `$directory`.
      # Counterpart in the statusline lives in claude-statusline.sh's
      # HOST_COLOUR derivation.
      custom.host_local = {
        description = "Hostname marker — local (no SSH connection)";
        when = ''[ -z "$SSH_CONNECTION" ]'';
        command = "hostname -s";
        format = "[${desktopGlyph}  $output]($style) ${chev} ";
        style = "green";
      };
      custom.host_ssh = {
        description = "Hostname marker — over SSH";
        when = ''[ -n "$SSH_CONNECTION" ]'';
        command = "hostname -s";
        format = "[${sshGlyph}  $output]($style) ${chev} ";
        style = "purple";
      };
    };
  };
}
