# niri user keybinds — the minimal set required for slice 3.
#
# DMS provides most of the keybind suite (Mod+Space spotlight, Mod+N
# notifications, Mod+X powermenu, Mod+V clipboard, XF86Audio*, etc.)
# via its homeModules.niri integration with enableKeybinds = true
# (set in ./dms.nix). This file adds only what DMS doesn't:
#
#   - Mod+Return → foot (slice 5's verification matrix needs a terminal bind).
#   - Mod+Shift+E → niri quit (emergency exit without dropping to console).
#
# Niri itself is enabled at the system layer (modules/core/nixos/niri.nix).
# niri-flake's nixosModule auto-imports homeModules.config (the typed
# settings surface) into every HM user when home-manager runs as a NixOS
# module, so this module just sets settings.binds — there's no
# programs.niri.enable here. homeModules.config declares no `enable`
# option; setting one would be an undeclared-option eval failure.
#
# Per ADR-028.
_: {
  programs.niri.settings.binds = {
    "Mod+Return".action.spawn = "foot";
    "Mod+Shift+E".action.quit = { };
  };
}
