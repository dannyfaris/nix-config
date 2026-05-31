# Dual git identity — personal default everywhere, work identity under
# ~/work/ via gitdir-include. Used on hosts where the same user works on
# both personal and employer code (the UTM VM today). Companion to
# git-identity-work.nix which is the single-work alternative used on
# work-only hosts (Mercury). See ADR-009 § "Dual identity" and ADR-020.
{ lib, ... }:
{
  programs.git = {
    # Personal default identity matches the user's GitHub handle
    # (dannyfaris) — GitHub attribution is email-based, not name-based,
    # so the name is purely cosmetic on commit logs. Under ~/work/ the
    # gitdir-include below overrides BOTH name and email to the work
    # identity ("Daniel Faris" / GotaXi email) so commits to the work
    # GitLab show the user's real name (employer convention).
    settings.user = {
      name = "dannyfaris";
      email = "daniel@faris.co.nz";
    };

    includes = [
      {
        condition = "gitdir:~/work/";
        contents.user = {
          name = "Daniel Faris";
          email = "daniel.faris@gotaxi.co.nz";
        };
      }
    ];
  };

  # Project directory convention: ~/work/ for employer/GitLab work,
  # ~/personal/ for everything else. The gitdir-include above keys off
  # ~/work/; ~/personal/ is the conventional sibling for personal repos.
  # Both directories are ensured on activation — mkdir -p is idempotent
  # so existing contents are untouched. Removing the convention later
  # leaves the directories on disk (we don't auto-remove user data).
  home.activation.ensureProjectDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/work" "$HOME/personal"
  '';
}
