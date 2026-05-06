# Home-manager NixOS-module wrapper for user dbf.
#
# This file is the entry point referenced from parts/nixos.nix. It owns the
# NixOS-side wiring (useGlobalPkgs, backup extension, news display) and
# delegates the user-level config to the thematic home-manager modules under
# this directory. Naming follows the "most-communicative term" rule
# (ADR-012 / docs/taxonomy.md).
{ ... }: {
  # useGlobalPkgs propagates the system's nixpkgs.config (including the unfree
  # predicate) to home-manager packages — see CLAUDE.md.
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  # Protects pre-existing dotfiles (e.g. ~/.config/gh from a manual `gh auth
  # login`) from blocking activation when home-manager wants to write them.
  home-manager.backupFileExtension = "hm-bak";

  home-manager.users.dbf = { ... }: {
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

    home.username = "dbf";
    home.homeDirectory = "/home/dbf";

    # Match the NixOS stateVersion — set once, never change.
    home.stateVersion = "25.11";

    # Suppress home-manager news output on every rebuild.
    news.display = "silent";

    # Let home-manager manage itself within the NixOS module integration.
    programs.home-manager.enable = true;
  };
}
