# waybar — GTK3 Wayland status bar.
#
# Stylix theming is wired centrally via `stylix.targets.waybar.enable
# = true` in home/core/shared/stylix-targets.nix; Stylix writes the
# CSS (programs.waybar.style) with the full base16 palette as
# @define-color variables, default background (@base00 with desktop
# opacity), text (@base05), tooltips, and per-state workspace-button
# styling (focused/active border @base05; urgent @base08). The font
# defaults to monospace (JetBrains Mono Nerd Font on this host),
# which is the right call for Nerd Font glyphs in network + tray.
# We deliberately don't override Stylix's writes — the settings
# below are behaviour-only.
#
# Lives under nixos/ because waybar is Linux-only — same placement
# reasoning as foot.nix, fuzzel.nix, and fnott.nix. macOS hosts get
# their own bar (or rely on macOS menu bar) when home/core/darwin/
# lands per the mac-mini onboarding epic #11.
#
# Auto-start via systemd: `programs.waybar.systemd.enable = true`
# adds a systemd user unit bound to `graphical-session.target`.
# Unlike fnott's lazy D-Bus activation, this is target-pulled —
# niri activates the target on session start and waybar comes up as
# a side effect. Status: `systemctl --user status waybar.service`.
#
# Module set is intentionally minimal day-1: niri/workspaces on the
# left; network + tray + clock on the right (clock rightmost, macOS
# top-right convention). No audio module — volume control via
# hardware keys or `wpctl` from a terminal when needed. See
# docs/desktop/waybar.md for the full selection rationale, the
# Stylix wiring details, and sharp edges (GTK3 closure footprint,
# StatusNotifierItem-only tray, niri dynamic workspaces, font
# trade-off).
#
# Per #75.
_: {
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 30;
      modules-left = [ "niri/workspaces" ];
      modules-right = [
        "network"
        "tray"
        "clock"
      ];

      "niri/workspaces" = { };
      network = {
        format-ethernet = "wired";
        format-disconnected = "offline";
      };
      tray.spacing = 10;
      clock.format = "{:%I:%M %p  %a %d %b}"; # 02:23 PM  Fri 29 May
    };
  };
}
