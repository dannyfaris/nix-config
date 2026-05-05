# Niri compositor configuration.
# System-level enablement + home-manager settings for keybindings and behaviour.
{ ... }:

{
  programs.niri.enable = true;

  home-manager.users.dbf.programs.niri.settings = {
    # Spawn these on niri startup.
    spawn-at-startup = [
      { argv = [ "waybar" ]; }
      { argv = [ "mako" ]; }
    ];

    # Input settings.
    input.keyboard.xkb.layout = "us";

    # Key bindings.
    binds = let
      super = "Mod+";
      superShift = "Mod+Shift+";
    in {
      # Applications
      "${super}Return".action.spawn = "ghostty";
      "${super}D".action.spawn = "fuzzel";

      # Window management
      "${super}Q".action.close-window = [];
      "${super}F".action.fullscreen-window = [];

      # Focus movement
      "${super}Left".action.focus-column-left = [];
      "${super}Right".action.focus-column-right = [];
      "${super}Up".action.focus-window-up = [];
      "${super}Down".action.focus-window-down = [];

      # Move windows
      "${superShift}Left".action.move-column-left = [];
      "${superShift}Right".action.move-column-right = [];
      "${superShift}Up".action.move-window-up = [];
      "${superShift}Down".action.move-window-down = [];

      # Workspaces
      "${super}1".action.focus-workspace = 1;
      "${super}2".action.focus-workspace = 2;
      "${super}3".action.focus-workspace = 3;
      "${super}4".action.focus-workspace = 4;
      "${superShift}1".action.move-window-to-workspace = 1;
      "${superShift}2".action.move-window-to-workspace = 2;
      "${superShift}3".action.move-window-to-workspace = 3;
      "${superShift}4".action.move-window-to-workspace = 4;

      # Session
      "${superShift}E".action.quit = [];
    };
  };
}
