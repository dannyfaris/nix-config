# Dual git identity — work default everywhere, personal identity under
# ~/personal/ and ~/nix-config/ via gitdir-includes. Used on hosts where
# the same user works on both employer and personal code. Companion to
# git-identity-work.nix which is the single-work alternative used on
# work-only hosts (Mercury). See ADR-009 §"Dual identity" and ADR-031
# (the directional flip from personal-default to work-default).
{ lib, ... }:
{
  programs.git = {
    # Work-default per ADR-031: closes the higher-severity leak vector
    # (personal email surfacing in employer git history visible to
    # colleagues and durable across employer infra) at the cost of a
    # lower-severity inverse (work email leaking into a personal repo
    # cloned outside ~/personal/ or ~/nix-config/). The pre-flight
    # audit in ADR-031 §Rationale is the operator-side mitigation
    # before activation on each host.
    settings.user = {
      name = "Daniel Faris";
      email = "daniel.faris@gotaxi.co.nz";
    };

    includes = [
      {
        # Conventional sibling of ~/work/ — personal repos live here
        # and inherit the personal identity automatically.
        condition = "gitdir:~/personal/";
        contents.user = {
          name = "dannyfaris";
          email = "daniel@faris.co.nz";
        };
      }
      {
        # Explicit carve-out for this flake's working checkout, which
        # lives at ~/nix-config/ (not under ~/personal/) because that
        # is the canonical NH_FLAKE path — lib/operator.nix's
        # `flakeRepoDirname` and every host's `hostContext.flakePath`
        # default resolve here. Relocating would propagate through
        # every host's _module.args + the NH_FLAKE env var; an explicit
        # gitdir carve-out is the smaller move. Matches `~/nix-config/`
        # exactly — a sibling like `~/nix-config-fork/` would not pick
        # up the carve-out and would get the work identity; clone forks
        # into `~/personal/` instead. See ADR-031 §Decision.
        condition = "gitdir:~/nix-config/";
        contents.user = {
          name = "dannyfaris";
          email = "daniel@faris.co.nz";
        };
      }
    ];
  };

  # Project directory convention: ~/work/ for employer/GitLab work,
  # ~/personal/ for everything else. Both directories are ensured on
  # activation — mkdir -p is idempotent so existing contents are
  # untouched. Removing the convention later leaves the directories on
  # disk (we don't auto-remove user data).
  home.activation.ensureProjectDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$HOME/work" "$HOME/personal"
  '';
}
