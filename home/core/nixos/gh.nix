# GitHub CLI — programs.gh + its HTTPS credential helper. Imported only
# on hosts that touch GitHub (the UTM VM). Work-only hosts (Mercury)
# skip this; they have no GitHub workflow. See ADR-009 § "Why
# git_protocol" and ADR-020 (work-vs-personal divergences via import
# splits, not host-keyed flags).
_: {
  programs.gh = {
    enable = true;
    # Explicit even though it matches the home-manager default — makes the
    # HTTPS-only stance visible in config rather than relying on an
    # upstream default that could shift.
    settings.git_protocol = "https";
    # Registers gh as git's HTTPS credential helper for github.com.
    gitCredentialHelper.enable = true;
  };
}
