# git-multi-identity — git with multiple identities (personal default
# + work override under ~/grey-st/) and the GitHub CLI.
#
# Base git config (HTTPS+token via gh/glab credential helpers, glab
# package + credential-helper wiring) + dual identity (personal as
# default; work under ~/grey-st/ via gitdir-conditional include) + the
# GitHub CLI for personal interactions.
#
# Named for contents per the taxonomy.md naming rule ("bundle names
# describe what is in the bundle, not what kind of host imports it").
# The previous name `git-personal.nix` conflated host-flavor with
# contents — a host importing this bundle has *both* identities
# available regardless of whether its operator thinks of it as
# "personal," and the name read as single-identity to anyone who
# hadn't opened the file. Renamed in #246; see git history for the
# pre-rename name if chasing old references.
#
# Imported by hosts that do both personal and work development
# (nixos-vm, metis, neptune). Work-only hosts (mercury) import the
# sibling git-work.nix bundle instead. Both bundles include the base
# git.nix module; Nix module merging deduplicates if both are ever
# imported on the same host (no host does this today).
{
  imports = [
    ../git.nix
    ../git-identity-dual.nix
    ../gh.nix
    # gh-dash rides on programs.gh (it registers as a gh extension), so it
    # belongs next to gh.nix; ADR-006 §"gh-dash" has the host-gate rationale.
    ../gh-dash.nix
  ];
}
