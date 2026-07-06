# Single work git identity — used on work-only hosts (e.g. Mercury) where
# no personal code is expected. Companion to git-identity-dual.nix.
#
# No gitdir-include: every repository on this host gets the work identity
# by default. ~/personal/ is intentionally not created (and not honoured
# even if manually mkdir'd) — if a personal project ends up here, it
# would get the work identity, which is wrong. Don't mix work and
# personal on the same host. See ADR-020 and ADR-009.
{ lib, ... }:
let
  inherit (import ../../lib/operator.nix) identities;
in
{
  # Work identity single-sourced from lib/operator.nix (#339).
  programs.git.settings.user = {
    inherit (identities.work) name email;
  };

  # Only ~/grey-st/ is ensured (named for the employer, Grey St). On this
  # work-only host the dir is convention, not a routing trigger — the work
  # identity applies everywhere here — so the rename is cosmetic, kept in
  # step with git-identity-dual.nix for a uniform convention across hosts.
  # Symmetric idempotent mkdir; existing contents untouched.
  home.activation.ensureProjectDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/grey-st"
  '';
}
