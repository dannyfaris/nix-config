# Home-manager module for user dbf.
# Pattern: useGlobalPkgs so the unfree predicate from system applies here too.
{ pkgs, ... }:

{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.dbf = {
    home.username = "dbf";
    home.homeDirectory = "/home/dbf";

    # Packages managed per-user (relocated from environment.systemPackages).
    home.packages = with pkgs; [
      claude-code
    ];

    # Let home-manager manage itself within the NixOS module integration.
    programs.home-manager.enable = true;

    # Match the NixOS stateVersion — set once, never change.
    home.stateVersion = "25.11";
  };
}
