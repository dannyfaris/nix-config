# Version control — git (dual identity), gh (HTTPS+token credential helper),
# glab (work side).
# See docs/decisions/ADR-009-git.md for rationale.
#
# Dual identity mechanism: git's `includeIf gitdir:~/work/` directive
# auto-applies the work email under ~/work/, personal email everywhere
# else. No manual switching.
#
# Auth model: HTTPS + token via gh/glab credential helpers. Not SSH —
# explicitly chosen to avoid passphrase friction in agent-CLI workflows
# (see ADR-009 § "Why HTTPS over SSH").
{ pkgs, ... }: {
  programs.git = {
    enable = true;

    userName = "Daniel Faris";
    userEmail = "daniel@faris.co.nz";   # personal default

    includes = [{
      condition = "gitdir:~/work/";
      contents.user.email = "daniel.faris@gotaxi.co.nz";
    }];

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };

  programs.gh = {
    enable = true;
    # Explicit even though it matches the home-manager default — makes the
    # HTTPS-only stance visible in config rather than relying on an
    # upstream default that could shift. See ADR-009 § "Why git_protocol".
    settings.git_protocol = "https";
    # Registers gh as git's HTTPS credential helper for github.com.
    gitCredentialHelper.enable = true;
  };

  # glab — GitLab CLI. Auth via `glab auth login` interactively on first
  # run (token persisted to ~/.config/glab-cli/, not in nix). Same
  # compromise as gh.
  home.packages = [ pkgs.glab ];
}
