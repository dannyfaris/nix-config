# Version control — git (dual identity), gh (HTTPS+token credential helper),
# glab (work side).
# See docs/decisions/ADR-009-git.md for rationale.
# TODO(slice-5c): replace with full programs.git + programs.gh config; add glab.
{ pkgs, ... }: {
  home.packages = [ pkgs.gh ];
}
