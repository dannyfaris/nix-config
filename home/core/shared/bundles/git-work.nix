# git-work — git with a single work identity, no GitHub CLI.
#
# Base git config (HTTPS+token via gh/glab credential helpers, glab
# package + credential-helper wiring) + the single work identity.
# Deliberately omits gh.nix per the mercury_push_boundary rule
# (work-only hosts must not be in a position to push to personal
# repos via gh's credential helper).
#
# Imported by work-only hosts (mercury). Personal hosts import the
# sibling git-personal.nix bundle instead.
{
  imports = [
    ../git.nix
    ../git-identity-work.nix
  ];
}
