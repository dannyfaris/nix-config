# Shell prompt — starship (deliberately minimal).
# See docs/decisions/ADR-002-prompt.md for rationale.
#
# Settings declared inline as a nix attrset (programs.starship.settings)
# rather than in a separate starship.toml file. Fish hook auto-wired by
# programs.starship.enable.
{ ... }: {
  programs.starship = {
    enable = true;

    settings = {
      format = "$directory$git_branch$git_status$nix_shell$character";
      add_newline = false;

      nix_shell = {
        format = "[$symbol$name]($style) ";
        symbol = "❄️ ";
      };
    };
  };
}
