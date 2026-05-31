# niri user keybinds — niri-only desktop, curated essential set.
#
# Bind composition + rationale + the three-modifier-namespace
# philosophy under which bindings are organised lives in
# docs/desktop/keybinds.md. This module is the implementation surface
# for that document; every binding here corresponds to a row in the
# doc's "Active bindings" tables.
#
# Doc-before-code: changes to bindings land first in keybinds.md,
# then here in the same PR.
#
# niri itself is enabled at the system layer
# (modules/nixos/niri.nix). niri-flake's nixosModule auto-imports
# homeModules.config (the typed settings surface) into every HM user
# when home-manager runs as a NixOS module, so this module just sets
# settings.binds — there's no `programs.niri.enable` here.
# homeModules.config declares no `enable` option; setting one would
# be an undeclared-option eval failure.
#
# See #69 for the niri-only baseline close-out under which this
# curated bind set was established.
_: {
  programs.niri.settings.binds = {
    # Navigation — focus (arrow + vim-style mirrors)
    "Mod+Left".action.focus-column-left = { };
    "Mod+Down".action.focus-window-down = { };
    "Mod+Up".action.focus-window-up = { };
    "Mod+Right".action.focus-column-right = { };
    "Mod+H".action.focus-column-left = { };
    "Mod+J".action.focus-window-down = { };
    "Mod+K".action.focus-window-up = { };
    "Mod+L".action.focus-column-right = { };

    # Navigation — move (arrow + vim-style mirrors)
    "Mod+Ctrl+Left".action.move-column-left = { };
    "Mod+Ctrl+Down".action.move-window-down = { };
    "Mod+Ctrl+Up".action.move-window-up = { };
    "Mod+Ctrl+Right".action.move-column-right = { };
    "Mod+Ctrl+H".action.move-column-left = { };
    "Mod+Ctrl+J".action.move-window-down = { };
    "Mod+Ctrl+K".action.move-window-up = { };
    "Mod+Ctrl+L".action.move-column-right = { };

    # Window management — interim binding; philosophical target is
    # Super+Hyper+W. See docs/desktop/keybinds.md §Implementation status.
    "Mod+W".action.close-window = { };

    # Workspaces — focus
    "Mod+1".action.focus-workspace = 1;
    "Mod+2".action.focus-workspace = 2;
    "Mod+3".action.focus-workspace = 3;
    "Mod+4".action.focus-workspace = 4;
    "Mod+5".action.focus-workspace = 5;
    "Mod+6".action.focus-workspace = 6;
    "Mod+7".action.focus-workspace = 7;
    "Mod+8".action.focus-workspace = 8;
    "Mod+9".action.focus-workspace = 9;

    # Workspaces — move window to
    "Mod+Shift+1".action.move-window-to-workspace = 1;
    "Mod+Shift+2".action.move-window-to-workspace = 2;
    "Mod+Shift+3".action.move-window-to-workspace = 3;
    "Mod+Shift+4".action.move-window-to-workspace = 4;
    "Mod+Shift+5".action.move-window-to-workspace = 5;
    "Mod+Shift+6".action.move-window-to-workspace = 6;
    "Mod+Shift+7".action.move-window-to-workspace = 7;
    "Mod+Shift+8".action.move-window-to-workspace = 8;
    "Mod+Shift+9".action.move-window-to-workspace = 9;

    # Spawn — terminal + application launcher
    "Mod+Return".action.spawn = "foot";
    "Mod+Space".action.spawn = "fuzzel";

    # Session — quit (niri shows a confirmation dialog by default)
    "Mod+Shift+E".action.quit = { };

    # Discovery
    "Mod+O".action.toggle-overview = { };
    "Mod+Shift+Slash".action.show-hotkey-overlay = { };
  };
}
