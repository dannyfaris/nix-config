# Modern CLI utilities — rg, fd, fzf, bat, eza, zoxide, lazygit, lazydocker, yazi, htop, dust, jq.
# See docs/decisions/ADR-006-cli-utilities.md for the locked, deferred, and
# skipped lists with rationale.
#
# Pattern: use dedicated programs.X modules where home-manager provides
# them (this wires shell integrations cleanly — fzf's Ctrl-R history,
# zoxide's `z` command, etc.). Plain home.packages for the rest.
#
# Note: the programs.X modules wire integrations only into shells that are
# themselves enabled in this user's home-manager config — fish is enabled
# in home/core/shared/shell.nix, so all integrations bind there.
#
# Aliasing carve-out: programs.eza's default fish integration aliases
# `ls`, `ll`, `la`, `lla`, and `lt` to eza variants. This is accepted —
# eza is a strict-superset interactive replacement for ls (colour, git
# status, modern formatting; defaults still alphabetical / one-per-line).
# Scripts continue to use coreutils' ls because shell aliases don't apply
# to script execution. Other tools (bat, fd, rg, dust, etc.) are NOT
# aliased to cat/find/grep/du/ps because they have meaningful behavioural
# differences that would surprise script logic if aliased into.
#
# Tool-vs-runtime split (see lazydocker in ADR-006): TUI clients live in
# home-manager and are available everywhere; the actual runtime tools they
# talk to live per-project in flake.nix devShells (e.g. the docker CLI
# itself), or per-host as a system service (e.g. the docker daemon — when
# we have a first project that needs one).
{ pkgs, ... }:
{
  programs = {
    fzf = {
      enable = true;
      # Respect .gitignore + faster than find. fd is in home.packages below.
      defaultCommand = "fd --type f --hidden --exclude .git";
      fileWidgetCommand = "fd --type f --hidden --exclude .git"; # Ctrl-T
      changeDirWidgetCommand = "fd --type d --hidden --exclude .git"; # Alt-C
    };
    bat.enable = true;
    eza.enable = true;
    zoxide.enable = true;
    lazygit.enable = true;
    lazydocker.enable = true;
    yazi = {
      enable = true;
      # Adopt the new default (was "yy" pre-stateVersion-26.05). The
      # wrapper spawns yazi and cd's the parent shell to whatever
      # directory yazi finished in on exit.
      shellWrapperName = "y";
    };
  };

  home.packages = with pkgs; [
    ripgrep
    fd
    htop
    dust
    jq
  ];

  # Render man pages through bat with syntax highlighting. `col -bx` strips
  # overstrike backspaces (man uses overstrike for bold/underline); `-l man`
  # picks bat's man-page syntax; `-p` drops decorations. MANROFFOPT=-c
  # disables groff's SGR colour output so it falls back to overstrike
  # encoding, which `col -bx` can then strip cleanly before bat re-renders.
  # See ADR-006 §Implementation for the why.
  home.sessionVariables = {
    MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    MANROFFOPT = "-c";
  };
}
