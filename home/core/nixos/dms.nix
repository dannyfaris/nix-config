# Dank Material Shell — Quickshell-based Material You shell.
#
# Three switches:
#   - enable = true — DMS shell itself.
#   - systemd.enable = true — DMS launches via a systemd user service
#     bound to config.wayland.systemd.target (default
#     graphical-session.target). niri.service declares
#     BindsTo=graphical-session.target + Before=graphical-session.target;
#     DMS's HM-side service uses PartOf + After + WantedBy on the same
#     target, so DMS is pulled in when niri activates it. Cleaner than
#     niri spawn-at-startup.
#   - niri.enableKeybinds = true — DMS adds its IPC binds (Mod+Space
#     spotlight, Mod+N notifications, Mod+X powermenu, Mod+V clipboard,
#     XF86Audio*, XF86MonBrightness*, etc.) into programs.niri.settings.binds
#     via lib.mkMerge. No conflict with the Mod+Return / Mod+Shift+E binds
#     set in ./niri.nix (DMS doesn't bind either).
#
# niri.includes.enable defaults true: DMS ships KDL fragments
# (colors, layout, alttab, windowrules, ...) that niri-flake's home
# module includes into the final niri config. Combined with
# enableKeybinds, DMS supplies the user-facing niri configuration almost
# in full.
#
# Theming intentionally NOT wired here — slice 4 (issue #34) owns the
# customThemeFile derived from config.lib.stylix.colors. Slice 3
# enables DMS in its default Material You palette to verify closure
# shape.
#
# TODO: DMS emits an eval warning when niri.enableKeybinds and
# niri.includes.enable are both true (the binds.kdl shipped by includes
# overlaps with the mkMerge that enableKeybinds installs). The overlap
# is acceptable for slice 3 — the warning is annotated but not silenced.
# Revisit at slice 4 by either omitting "binds" from
# niri.includes.filesToInclude or migrating to niri.enableSpawn-only.
#
# Per ADR-028.
_: {
  programs.dank-material-shell = {
    enable = true;
    systemd.enable = true;
    niri.enableKeybinds = true;
  };
}
