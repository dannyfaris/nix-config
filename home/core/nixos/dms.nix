# Dank Material Shell — Quickshell-based Material You shell.
#
# Four switches:
#   - enable = true — DMS shell itself.
#   - systemd.enable = true — DMS launches via a systemd user service
#     bound to config.wayland.systemd.target (default
#     graphical-session.target). niri.service declares
#     BindsTo=graphical-session.target + Before=graphical-session.target;
#     DMS's HM-side service uses PartOf + After + WantedBy on the same
#     target, so DMS is pulled in when niri activates it. Cleaner than
#     niri spawn-at-startup.
#   - enableDynamicTheming = false — load-bearing for the
#     Stylix-decoupling decision (see ADR-028 §History 2026-05-29).
#     This is the single gate in DMS's distro/nix/common.nix:19 that
#     pulls matugen into the closure. With it false, matugen is absent
#     from build and runtime and cannot stomp the GTK/Qt files
#     Stylix's gtk/qt targets already manage.
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
# DMS theming intentionally decoupled from Stylix per ADR-028 §History
# 2026-05-29. DMS uses its built-in palette + its own runtime wallpaper
# picker. Stylix remains canonical for the TUI surface, foot terminal,
# GTK/Qt apps, and niri focus-ring/cursor.
#
# TODO (open, post-decoupling): DMS emits an eval warning when
# niri.enableKeybinds and niri.includes.enable are both true (the
# binds.kdl shipped by includes overlaps with the mkMerge that
# enableKeybinds installs). The overlap is acceptable for slice 3 — the
# warning is annotated but not silenced. Possible resolutions when next
# iterating on the niri/DMS interface: omit "binds" from
# niri.includes.filesToInclude, or migrate to niri.enableSpawn-only.
#
# Per ADR-028.
_: {
  programs.dank-material-shell = {
    enable = true;
    systemd.enable = true;
    enableDynamicTheming = false;
    niri.enableKeybinds = true;
  };
}
