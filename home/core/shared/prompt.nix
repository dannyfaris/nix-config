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
  # matches the macchina recolour at home/core/nixos/macchina.nix:8.
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
      format = "\${custom.host_local}\${custom.host_ssh}$directory$git_branch$git_status$nix_shell$character";
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
      git_status = {
        conflicted = " [!\${count}](red)";
        staged = " [+\${count}](green)";
        modified = " [~\${count}](yellow)";
        untracked = " [?\${count}](purple)";
        format = "$all_status";
        style = "";
      };

      # Nix-shell indicator. Leading `❯` (chev) is part of the module's
      # own format so it renders only when in a nix-shell; this is the
      # second `❯` separator on the line (after the host one), matching
      # the statusline's conditional `❯ ❄️` segment.
      nix_shell = {
        format = "${chev} [$symbol]($style) ";
        symbol = "❄️";
        style = "blue"; # nix blue (base0D via Stylix palette)
      };

      # Host segments render in default foreground (no `style` field) for
      # visual parity with the un-styled claude-statusline.
      custom.host_local = {
        description = "Hostname marker — local (no SSH connection)";
        when = ''[ -z "$SSH_CONNECTION" ]'';
        command = "hostname -s";
        format = "${desktopGlyph}  $output ${chev} ";
      };
      custom.host_ssh = {
        description = "Hostname marker — over SSH";
        when = ''[ -n "$SSH_CONNECTION" ]'';
        command = "hostname -s";
        format = "${sshGlyph}  $output ${chev} ";
      };
    };
  };
}
