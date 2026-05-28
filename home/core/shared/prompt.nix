# Shell prompt — starship (deliberately minimal).
# See docs/decisions/ADR-002-prompt.md for rationale.
#
# Settings declared inline as a nix attrset (programs.starship.settings)
# rather than in a separate starship.toml file. Fish hook auto-wired by
# programs.starship.enable.
_:
let
  # Nerd Font glyphs decoded from codepoints via fromJSON so the .nix
  # source stays readable (no raw UTF-8 bytes). Pattern matches the
  # macchina recolour at home/core/nixos/macchina.nix:8.
  desktopGlyph = builtins.fromJSON ''""''; # nf-fa-desktop — local
  sshGlyph = builtins.fromJSON ''""''; # nf-mdi-console_network — SSH
  chev = builtins.fromJSON ''"❯"''; # ❯ U+276F — reading-flow separator
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

      # Nix-shell indicator. Leading `❯` (chev) is part of the module's
      # own format so it renders only when in a nix-shell; this is the
      # second `❯` separator on the line (after the host one), matching
      # the statusline's conditional `❯ ❄️` segment.
      nix_shell = {
        format = "${chev} [$symbol]($style) ";
        symbol = "❄️";
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
