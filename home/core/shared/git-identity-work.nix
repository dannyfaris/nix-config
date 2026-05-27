# Single work git identity — used on work-only hosts (e.g. Mercury) where
# no personal code is expected. Companion to git-identity-dual.nix.
#
# No gitdir-include: every repository on this host gets the work identity
# by default. ~/personal/ is intentionally not created (and not honoured
# even if manually mkdir'd) — if a personal project ends up here, it
# would get the work identity, which is wrong. Don't mix work and
# personal on the same host. See ADR-020 and ADR-009.
{ lib, ... }: {
  programs.git.settings.user = {
    name = "Daniel Faris";
    email = "daniel.faris@gotaxi.co.nz";
  };

  # Only ~/work/ is ensured. Symmetric idempotent mkdir as in
  # git-identity-dual.nix; existing contents untouched.
  home.activation.ensureProjectDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/work"
  '';
}
