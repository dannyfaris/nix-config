# Home-manager NixOS-module wrapper for the operator (per lib/operator.nix).
#
# Owns the NixOS-side wiring (useGlobalPkgs, backup extension, news
# display, stateVersion) and forwards `hostContext` into the home-manager
# submodule system via `extraSpecialArgs`. The actual home-module
# composition is owned by each host: `hostContext.extraHomeModules` is
# the full HM imports list for the host, typically populated with bundle
# paths (cli-tooling, git-multi-identity/git-work) plus standalone modules
# (ssh, macchina, agent-clis, ...). See ADR-027 for the bundle model.
#
# Parametrisation: `hostContext` arrives as a function argument, sourced
# from the typed option layer in ./host-context.nix (which writes
# `_module.args.hostContext = config.hostContext;` to bridge the option
# layer to fn-arg consumption — avoids the imports-evaluation-timing
# trap of reading `config.hostContext` to compute home-manager imports).
# Each host sets the value via `hostContext = { ... };` at the top of its
# default.nix. See ADR-019. Operator identity (HM attr-name + homeDirectory)
# comes from lib/operator.nix per #49 so the same record feeds the
# Darwin equivalent (modules/darwin/home-manager.nix).
{ hostContext, inputs, ... }:
let
  operator = import ../../lib/operator.nix;
in
{
  home-manager = {
    # useGlobalPkgs propagates the system's nixpkgs.config (including the
    # unfree predicate) to home-manager packages — see CLAUDE.md.
    useGlobalPkgs = true;
    useUserPackages = true;

    # Protects pre-existing dotfiles (e.g. ~/.config/gh from a manual
    # `gh auth login`) from blocking activation when home-manager wants to
    # write them.
    backupFileExtension = "hm-bak";

    # `inputs` is forwarded so HM modules can import flake-provided HM
    # modules internally (an `inputs.<flake>.homeModules.default` import
    # inside a home/ module). No HM module consumes it today — the
    # zen-browser module that did was retired (#127) — but it is kept as
    # the extension point for future flake-input HM modules. Repo-local
    # HM modules that don't need flake-input access ignore the arg.
    #
    # `zellijCacheDir` is the platform-specific dir where zellij reads/
    # writes permissions.kdl; passed in so home/shared/multiplexer.nix can
    # pre-grant the zjstatus plugin without a platform conditional in
    # shared/ (which the shared-purity lint forbids). Linux: XDG cache.
    #
    # `flakeConfigAttr` names this platform's flake configurations set so
    # home/shared/editor.nix's nixd option-eval exprs resolve here without a
    # platform conditional in shared/ (#335). NixOS: `nixosConfigurations`.
    extraSpecialArgs = {
      inherit hostContext inputs;
      zellijCacheDir = "${operator.linuxHome}/.cache/zellij";
      flakeConfigAttr = "nixosConfigurations";
    };

    users.${operator.name} = _: {
      imports = hostContext.extraHomeModules or [ ];

      home = {
        username = operator.name;
        homeDirectory = operator.linuxHome;

        # Match the NixOS stateVersion — set once, never change.
        stateVersion = "25.11";
      };

      # Suppress home-manager news output on every rebuild.
      news.display = "silent";

      # Let home-manager manage itself within the NixOS module integration.
      programs.home-manager.enable = true;
    };
  };
}
