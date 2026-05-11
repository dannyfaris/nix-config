# Modern CLI utilities — rg, fd, fzf, bat, eza, zoxide, lazygit, yazi, htop, dust.
# See docs/decisions/ADR-006-cli-utilities.md for the locked, deferred, and
# skipped lists with rationale.
#
# Pattern: use dedicated programs.X modules where home-manager provides
# them (this wires shell integrations cleanly — fzf's Ctrl-R history,
# zoxide's `z` command, etc.). Plain home.packages for the rest.
#
# Note: the programs.X modules wire integrations only into shells that are
# themselves enabled in this user's home-manager config — fish is enabled
# in modules/home/shell.nix, so all integrations bind there.
#
# Do NOT alias originals (ls, cat, find, grep) — keep them callable for
# muscle memory and script compatibility.
{ pkgs, ... }: {
  programs = {
    fzf.enable = true;
    bat.enable = true;
    eza.enable = true;
    zoxide.enable = true;
    lazygit.enable = true;
    yazi.enable = true;
  };

  home.packages = with pkgs; [
    ripgrep
    fd
    htop
    dust
  ];
}
