# Single personal git identity — used on personal-only hosts where no
# employer code is expected. Companion to git-identity-dual.nix (both
# identities, work under ~/grey-st/ via gitdir-include).
#
# No gitdir-include: every repository on this host gets the personal
# identity by default. ~/grey-st/ is intentionally not created — work and
# personal are not mixed on this host (ADR-020). See ADR-009.
{ lib, ... }:
let
  inherit (import ../../lib/operator.nix) identities;
in
{
  # Personal identity single-sourced from lib/operator.nix (#339). The
  # name is the GitHub handle (dannyfaris) — GitHub attribution is
  # email-based, so the name is cosmetic on commit logs.
  programs.git.settings.user = {
    inherit (identities.personal) name email;
  };

  # ~/dev/ ensured for personal repos — named for its contents, not
  # contrasted against a work sibling (there is none on this host).
  # Idempotent mkdir; existing contents untouched. See ADR-009 / identities.md.
  home.activation.ensureProjectDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/dev"
  '';
}
