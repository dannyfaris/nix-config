# Fuzzel application launcher configuration (home-manager).
# Themed by Stylix automatically.
{ ... }:

{
  home-manager.users.dbf.programs.fuzzel = {
    enable = true;

    settings.main = {
      terminal = "ghostty";
      layer = "overlay";
    };
  };
}
