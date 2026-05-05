# Waybar status bar configuration (home-manager).
# Themed by Stylix automatically.
{ ... }:

{
  home-manager.users.dbf.programs.waybar = {
    enable = true;

    settings.mainBar = {
      # niri requires layer = "top" for waybar to be visible.
      layer = "top";
      position = "top";

      modules-left = [ "niri/workspaces" ];
      modules-center = [ "clock" ];
      modules-right = [ "cpu" "memory" "network" "tray" ];

      clock = {
        format = "{:%H:%M}";
        tooltip-format = "{:%A, %d %B %Y}";
      };

      cpu = {
        format = "CPU {usage}%";
        interval = 5;
      };

      memory = {
        format = "MEM {percentage}%";
        interval = 5;
      };

      network = {
        format-wifi = "WiFi {signalStrength}%";
        format-ethernet = "ETH";
        format-disconnected = "offline";
      };
    };
  };
}
