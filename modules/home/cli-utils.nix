# Modern CLI utilities — rg, fd, fzf, bat, eza, zoxide, lazygit, yazi, htop, dust.
# See docs/decisions/ADR-006-cli-utilities.md for the locked, deferred, and
# skipped lists with rationale.
#
# Pattern: use dedicated programs.X modules where home-manager provides
# them (this wires shell integrations cleanly — fzf's Ctrl-R history,
# zoxide's `z` command, etc.). Plain home.packages for the rest.
#
# Do NOT alias originals (ls, cat, find, grep) — keep them callable for
# muscle memory and script compatibility.
{ pkgs, ... }: {
  programs.fzf.enable = true;
  programs.bat.enable = true;
  programs.eza.enable = true;
  programs.zoxide.enable = true;
  programs.lazygit.enable = true;
  programs.yazi.enable = true;

  home.packages = with pkgs; [
    ripgrep
    fd
    htop
    dust
  ];
}
