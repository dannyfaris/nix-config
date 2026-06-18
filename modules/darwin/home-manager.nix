# Home-manager nix-darwin-module wrapper for the operator (per
# lib/operator.nix). Mirrors modules/nixos/home-manager.nix.
#
# Owns the Darwin-side wiring (useGlobalPkgs, backup extension, news
# display, stateVersion) and forwards `hostContext` into the
# home-manager submodule system via `extraSpecialArgs`. The actual
# home-module composition is owned by each host:
# `hostContext.extraHomeModules` is the full HM imports list for the
# host, typically populated with bundle paths (cli-tooling,
# git-multi-identity) plus standalone modules (ssh, macchina pair,
# agent-clis, ...). See ADR-027.
#
# Parametrisation: `hostContext` arrives as a function argument, sourced
# from the typed option layer in ./host-context.nix (which writes
# `_module.args.hostContext = config.hostContext;` to bridge the option
# layer to fn-arg consumption — avoids the imports-evaluation-timing
# trap of reading `config.hostContext` to compute home-manager imports).
# Each host sets the value via `hostContext = { ... };` at the top of
# its default.nix. See ADR-019. Operator identity (HM attr-name +
# homeDirectory) comes from lib/operator.nix per #49.
#
# The nix-darwin home-manager module is wired into the system module
# set by lib/mk-darwin-host.nix (parallel to mk-host.nix's wiring of
# the NixOS variant); this file configures it.
{ hostContext, inputs, ... }:
let
  operator = import ../../lib/operator.nix;
in
{
  home-manager = {
    # useGlobalPkgs propagates the system's nixpkgs.config (including
    # the unfree predicate from modules/shared/nix-daemon.nix) to
    # home-manager packages — see CLAUDE.md.
    useGlobalPkgs = true;
    useUserPackages = true;

    # Protects pre-existing dotfiles (e.g. ~/.bashrc, ~/.zshrc that
    # macOS ships by default) from blocking activation when
    # home-manager wants to write them.
    backupFileExtension = "hm-bak";

    # `inputs` is forwarded so HM modules can import flake-provided HM
    # modules internally. Repo-local HM modules that don't need
    # flake-input access can ignore the arg.
    #
    # `zellijCacheDir` is the platform-specific dir where zellij reads/
    # writes permissions.kdl; passed in so home/shared/multiplexer.nix can
    # pre-grant the zjstatus plugin without a platform conditional in
    # shared/ (which the shared-purity lint forbids). macOS: Caches bundle.
    #
    # `flakeConfigAttr` names this platform's flake configurations set so
    # home/shared/editor.nix's nixd option-eval exprs resolve here without a
    # platform conditional in shared/ (#335). Darwin: `darwinConfigurations`.
    extraSpecialArgs = {
      inherit hostContext inputs;
      zellijCacheDir = "${operator.darwinHome}/Library/Caches/org.Zellij-Contributors.Zellij";
      flakeConfigAttr = "darwinConfigurations";
    };

    users.${operator.name} = _: {
      imports = hostContext.extraHomeModules or [ ];

      home = {
        username = operator.name;
        homeDirectory = operator.darwinHome;

        # HM's stateVersion is platform-independent (year.month
        # string). Aligned with the NixOS hosts at 25.11 — set once,
        # never change.
        stateVersion = "25.11";
      };

      # Suppress home-manager news output on every rebuild.
      news.display = "silent";

      # Let home-manager manage itself within the nix-darwin module
      # integration.
      programs.home-manager.enable = true;
    };
  };
}
