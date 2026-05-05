# Desktop environment: niri + waybar + fuzzel + ghostty + mako.
# Stylix provides system-wide theming. The session manager (greetd) is
# host-specific — see hosts/<host>/default.nix.
{ pkgs, ... }:

{
  imports = [
    ./niri.nix
    ./waybar.nix
    ./fuzzel.nix
    ./ghostty.nix
  ];

  # --- Stylix (system-wide theming)
  stylix = {
    enable = true;
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-dark.yaml";

    fonts = {
      monospace = {
        package = pkgs.jetbrains-mono;
        name = "JetBrains Mono";
      };
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.noto-fonts;
        name = "Noto Serif";
      };
    };
  };

  # --- mako (notification daemon, themed by Stylix)
  home-manager.users.dbf.services.mako.enable = true;
}
