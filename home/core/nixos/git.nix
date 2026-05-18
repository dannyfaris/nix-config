# Version control — base configuration shared by every host: git itself,
# glab as both a package and a gitlab.com credential helper. Per-host
# identity (single vs dual) and gh enablement live in companion files
# (git-identity-dual.nix, git-identity-work.nix, gh.nix) imported via
# hostContext.extraHomeModules. See ADR-009 for the auth-model rationale
# and ADR-020 for the import-split convention.
#
# Auth model: HTTPS + token via gh/glab credential helpers. Not SSH —
# explicitly chosen to avoid passphrase friction in agent-CLI workflows
# (ADR-009 § "Why HTTPS over SSH").
{ lib, pkgs, ... }: {
  programs.git = {
    enable = true;

    settings = {
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
  };

  # glab — GitLab CLI. Auth via `glab auth login` interactively on first
  # run (token persisted to ~/.config/glab-cli/, not in nix). The git
  # credential helper for gitlab.com is wired above (declarative).
  home.packages = [ pkgs.glab ];
}
