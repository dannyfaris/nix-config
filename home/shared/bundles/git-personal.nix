# git-personal — git with personal+work dual identity and GitHub CLI.
#
# Base git config (HTTPS+token via gh/glab credential helpers, glab
# package + credential-helper wiring) + dual identity (personal as
# default; work under ~/work/ via gitdir-conditional include) + the
# GitHub CLI for personal interactions.
#
# Imported by hosts that do personal development (nixos-vm, metis).
# Work-only hosts (mercury) import the sibling git-work.nix bundle
# instead. Both bundles include the base git.nix module; Nix module
# merging deduplicates if both are ever imported on the same host
# (no host does this today).
{
  imports = [
    ../git.nix
    ../git-identity-dual.nix
    ../gh.nix
  ];
}
