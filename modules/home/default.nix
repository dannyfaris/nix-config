# Home-manager NixOS-module wrapper for user dbf.
#
# This file is the entry point referenced from parts/nixos.nix. It owns the
# NixOS-side wiring (useGlobalPkgs, backup extension, news display) and
# delegates the user-level config to the thematic home-manager modules under
# this directory. Naming follows the "most-communicative term" rule
# (ADR-012 / docs/taxonomy.md).
_: {
  home-manager = {
    # useGlobalPkgs propagates the system's nixpkgs.config (including the
    # unfree predicate) to home-manager packages — see CLAUDE.md.
    useGlobalPkgs = true;
    useUserPackages = true;

    # Protects pre-existing dotfiles (e.g. ~/.config/gh from a manual
    # `gh auth login`) from blocking activation when home-manager wants to
    # write them.
    backupFileExtension = "hm-bak";

    users.dbf = _: {
      imports = [
        ./shell.nix
        ./prompt.nix
        ./direnv.nix
        ./multiplexer.nix
        ./editor.nix
        ./git.nix
        ./ssh.nix
        ./cli-utils.nix
        ./nix-tooling.nix
        ./agent-clis.nix
      ];

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
