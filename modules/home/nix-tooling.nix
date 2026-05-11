# Nix tooling layer — nh, nom, nixd, nixfmt, statix, deadnix.
# See docs/decisions/ADR-007-nix-tooling.md for rationale.
#
# These are home-manager packages (per-user dev tools), not system
# services. nixd is the LSP helix invokes via PATH (see ADR-005); nixfmt
# is the formatter helix invokes by absolute path. nh wraps
# nixos-rebuild / home-manager with better output; nom (nix-output-monitor)
# converts wall-of-text builds into a tree view. statix and deadnix lint
# nix code (run interactively or via editor integration).
#
# pkgs.nixfmt is the RFC-style formatter (1.2.0+); pkgs.nixfmt-rfc-style
# is now a deprecated alias for the same package.
{ pkgs, ... }: {
  home.packages = with pkgs; [
    nh
    nix-output-monitor
    nixd
    nixfmt
    statix
    deadnix
  ];
}
