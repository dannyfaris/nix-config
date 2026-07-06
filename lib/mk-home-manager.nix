# Constructor for the home-manager wrapper module — both platform twins
# (modules/{nixos,darwin}/home-manager.nix) are built from this one body
# with explicit per-platform args, so the HM wiring policy (useGlobalPkgs,
# backup extension, stateVersion, news display) cannot fork between
# platforms (#541 — the values-only twin criterion, CLAUDE.md
# §Conventions).
#
# Owns the wiring and forwards `hostContext` into the home-manager
# submodule system via `extraSpecialArgs`. The actual home-module
# composition is owned by each host: `hostContext.extraHomeModules` is the
# full HM imports list for the host, typically bundle paths (cli-tooling,
# git-multi-identity/git-work) plus standalone modules (ssh, macchina,
# agent-clis, ...). See ADR-027 for the bundle model.
#
# Parametrisation: `hostContext` arrives as a function argument, sourced
# from the typed option layer built by lib/mk-host-context.nix (whose
# `_module.args` write bridges option → fn-arg — see its header for the
# imports-evaluation-timing trap that shape sidesteps). Each host sets the
# value via `hostContext = { ... };` in its default.nix (ADR-019).
# Operator identity (HM attr-name + the homeDirectory root) comes from
# lib/operator.nix per #49.
#
# Args — the three platform constants:
#   homeDirectory   — the operator's home dir on this platform.
#   zellijCacheDir  — where zellij reads/writes permissions.kdl; injected
#                     so home/shared/multiplexer.nix can pre-grant the
#                     zjstatus plugin without a platform conditional in
#                     shared/ (which the shared-purity lint forbids).
#   flakeConfigAttr — this platform's flake configurations set, so
#                     home/shared/editor.nix's nixd option-eval exprs
#                     resolve without a platform conditional (#335).
{
  homeDirectory,
  zellijCacheDir,
  flakeConfigAttr,
}:
{ hostContext, inputs, ... }:
let
  operator = import ./operator.nix;
in
{
  home-manager = {
    # useGlobalPkgs propagates the system's nixpkgs.config (including the
    # unfree predicate) to home-manager packages — see CLAUDE.md.
    useGlobalPkgs = true;
    useUserPackages = true;

    # Protects pre-existing dotfiles (e.g. ~/.config/gh from a manual
    # `gh auth login`, or the ~/.zshrc macOS ships) from blocking
    # activation when home-manager wants to write them.
    backupFileExtension = "hm-bak";

    # `inputs` is forwarded so HM modules can import flake-provided HM
    # modules internally (an `inputs.<flake>.homeModules.default` import
    # inside a home/ module). No HM module consumes it today — the
    # zen-browser module that did was retired (#127) — but it is kept as
    # the extension point for future flake-input HM modules.
    extraSpecialArgs = {
      inherit
        hostContext
        inputs
        zellijCacheDir
        flakeConfigAttr
        ;
    };

    users.${operator.name} = _: {
      imports = hostContext.extraHomeModules;

      home = {
        username = operator.name;
        inherit homeDirectory;

        # HM's stateVersion is platform-independent (year.month string).
        # Aligned fleet-wide at 25.11 — set once, never change.
        stateVersion = "25.11";
      };

      # Suppress home-manager news output on every rebuild.
      news.display = "silent";

      # Let home-manager manage itself within the module integration.
      programs.home-manager.enable = true;
    };
  };
}
