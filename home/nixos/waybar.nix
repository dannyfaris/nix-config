# waybar — GTK3 Wayland status bar.
#
# Stylix theming is wired centrally via `stylix.targets.waybar.enable
# = true` in home/nixos/stylix-targets-desktop.nix; Stylix writes the
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
# reasoning as foot.nix, fuzzel.nix, and fnott.nix. macOS hosts rely
# on the native macOS menu bar; no waybar equivalent is wired.
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
{ config, lib, ... }:
let
  tokens = import ../../lib/theme-tokens.nix { inherit config; };
in
{
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

    # Active workspace indicator → the focus role (base0D, via theme-tokens).
    # Stylix's waybar target colours the focused/active workspace underline
    # @base05 (foreground); re-point it to the idiomatic accent slot so it
    # matches niri's active border. Appended (mkAfter) with the same selectors
    # as Stylix's rules — equal specificity, later in the sheet → wins. Colour
    # only: width (3px) and the urgent @base08 state stay as Stylix writes them.
    # See theme-tokens.nix, docs/desktop/waybar.md, and the accent map (#108).
    style = lib.mkAfter ''
      .modules-left #workspaces button.focused,
      .modules-left #workspaces button.active,
      .modules-center #workspaces button.focused,
      .modules-center #workspaces button.active,
      .modules-right #workspaces button.focused,
      .modules-right #workspaces button.active {
        border-bottom-color: @${tokens.color.role.focus.slot};
      }
    '';
  };
}
