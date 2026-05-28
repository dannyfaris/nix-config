# Home-manager NixOS-module wrapper for user dbf.
#
# Owns the NixOS-side wiring (useGlobalPkgs, backup extension, news
# display, stateVersion) and forwards `hostContext` into the home-manager
# submodule system via `extraSpecialArgs`. The actual home-module
# composition is owned by each host: `hostContext.extraHomeModules` is
# the full HM imports list for the host, typically populated with bundle
# paths (cli-tooling, git-personal/git-work) plus standalone modules
# (ssh, macchina, agent-clis, ...). See ADR-027 for the bundle model.
#
# Parametrisation: `hostContext` arrives as a function argument, sourced
# from the typed option layer in ./host-context.nix (which writes
# `_module.args.hostContext = config.hostContext;` to bridge the option
# layer to fn-arg consumption — avoids the imports-evaluation-timing
# trap of reading `config.hostContext` to compute home-manager imports).
# Each host sets the value via `hostContext = { ... };` at the top of its
# default.nix. See ADR-019.
{ hostContext, ... }:
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

    extraSpecialArgs = { inherit hostContext; };

    users.dbf = _: {
      imports = hostContext.extraHomeModules or [ ];

      home = {
        username = "dbf";
        homeDirectory = "/home/dbf";

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
