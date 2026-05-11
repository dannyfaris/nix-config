# Per-project environment activation — direnv + nix-direnv.
# See docs/decisions/ADR-003-direnv.md for rationale.
#
# Fish hook auto-wired by programs.direnv.enable. Per-project pattern:
# each project gets a flake.nix declaring its devShells.default plus a
# one-line .envrc containing `use flake`. First entry: `direnv allow`.
_: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
