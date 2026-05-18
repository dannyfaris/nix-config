# Home-manager NixOS-module wrapper for user dbf.
#
# Imported by every host role that ships dbf's user environment. Owns the
# NixOS-side wiring (useGlobalPkgs, backup extension, news display) and
# delegates the user-level config to the thematic home-manager modules under
# home/core/nixos/.
#
# Parametrisation: `hostContext` arrives as a function argument set by each
# host's `_module.args.hostContext` (see ADR-019). It is consumed here as a
# function arg — not read via config._module.args, which is a write-only sink
# at the option layer — and forwarded into the home-manager submodule system
# via `extraSpecialArgs` so individual home modules (editor.nix nixd options,
# nix-tooling NH_FLAKE) can read it the same way.
#
# `hostContext.extraHomeModules` lets each host contribute additional HM
# modules without editing this file (e.g. work-only hosts add
# git-identity-work.nix; the VM adds git-identity-dual.nix + gh.nix).
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
      imports = [
        ../../../home/core/nixos/shell.nix
        ../../../home/core/nixos/prompt.nix
        ../../../home/core/nixos/direnv.nix
        ../../../home/core/nixos/multiplexer.nix
        ../../../home/core/nixos/editor.nix
        ../../../home/core/nixos/git.nix
        ../../../home/core/nixos/ssh.nix
        ../../../home/core/nixos/cli-utils.nix
        ../../../home/core/nixos/nix-tooling.nix
        ../../../home/core/nixos/agent-clis.nix
      ] ++ (hostContext.extraHomeModules or [ ]);

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
