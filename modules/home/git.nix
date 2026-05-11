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
{ lib, pkgs, ... }: {
  programs.git = {
    enable = true;

    # Personal default identity matches the user's GitHub handle
    # (dannyfaris) — GitHub attribution is email-based, not name-based,
    # so the name is purely cosmetic on commit logs. Under ~/work/ the
    # gitdir-include below overrides BOTH name and email to the work
    # identity ("Daniel Faris" / GotaXi email) so commits to the work
    # GitLab show the user's real name (employer convention).
    settings = {
      user = {
        name = "dannyfaris";
        email = "daniel@faris.co.nz";
      };

      init.defaultBranch = "main";
      pull.rebase = true;

      # glab as git credential helper for gitlab.com — wired declaratively
      # here because home-manager has no `programs.glab.gitCredentialHelper`
      # equivalent to `programs.gh`'s. Without this entry `glab auth login`
      # fails at startup trying to write to the read-only nix-managed git
      # config. With it, git already knows about the helper and glab's
      # write becomes a no-op. The two-element list (empty string then
      # command) is git's idiom for "reset any prior helper, then use this".
      credential."https://gitlab.com".helper = [
        ""
        "${lib.getExe pkgs.glab} auth git-credential"
      ];
    };

    includes = [{
      condition = "gitdir:~/work/";
      contents.user = {
        name = "Daniel Faris";
        email = "daniel.faris@gotaxi.co.nz";
      };
    }];
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
  # run (token persisted to ~/.config/glab-cli/, not in nix). The git
  # credential helper for gitlab.com is wired above (declarative).
  home.packages = [ pkgs.glab ];
}
