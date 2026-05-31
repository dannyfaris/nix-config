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
# pkgs.nixfmt is the RFC-style formatter (1.2.0+). Don't swap with:
#   - pkgs.nixfmt-classic — separate package, pre-RFC Serokell style.
#   - pkgs.nixfmt-rfc-style — deprecated alias, emits warnings.
#
# Parametrisation: `hostContext.flakePath` comes from each host's
# `_module.args.hostContext` via the HM extraSpecialArgs forwarder in
# modules/nixos/home-manager.nix. See ADR-019.
{ pkgs, hostContext, ... }:
{
  home.packages = with pkgs; [
    nh
    nix-output-monitor
    nixd
    nixfmt
    statix
    deadnix
  ];

  # Tell nh where this user's flake lives, so `nh os switch` (and the home/
  # debug subcommands) work from anywhere — not just from inside the repo
  # with `.` passed explicitly. NH_FLAKE applies to all `nh` subcommands;
  # NH_OS_FLAKE would scope to just `nh os`.
  home.sessionVariables.NH_FLAKE = hostContext.flakePath;
}
