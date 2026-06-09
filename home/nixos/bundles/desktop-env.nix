# desktop-env — home-manager pieces for the Wayland desktop session.
#
# Pure aggregation per the bundle-purity rule (PRD §8.1 #3): bundles
# contain only an `imports` list and no inline option setting. The
# user-facing capabilities the desktop session needs are factored into
# standalone modules beside this file:
#
#   - niri.nix — programs.niri.settings.binds (curated essential set;
#     see docs/desktop/keybinds.md for the full taxonomy).
#   - foot.nix — programs.foot.enable.
#   - fuzzel.nix — programs.fuzzel.enable + launcher behaviour
#     settings (see docs/desktop/fuzzel.md).
#   - fnott.nix — services.fnott.enable (notification daemon;
#     D-Bus-activated; see docs/desktop/fnott.md).
#   - screen-lock.nix — programs.swaylock + services.swayidle (session
#     lock + idle handling: lock on idle, displays off, lock before
#     sleep; see docs/desktop/screen-lock.md).
#   - waybar.nix — programs.waybar.enable + status-bar layout
#     settings (top of screen; tray-bearing; see
#     docs/desktop/waybar.md).
#   - firefox.nix — programs.firefox.enable + stub default profile
#     + xdg.mimeApps default-handler registration (Gecko engine,
#     native Wayland; see docs/desktop/firefox.md).
#   - zen-browser.nix — programs.zen-browser.enable + stub default
#     profile. Audit-phase parallel installation alongside Firefox
#     per #127; HM module sourced from the 0xc000022070 community
#     flake. See docs/desktop/zen.md.
#   - cursor-ide.nix — home.packages addition for pkgs.code-cursor
#     (AI-coding-focused vscode fork; Wayland via host-wide
#     NIXOS_OZONE_WL set in modules/nixos/electron-wayland.nix).
#   - portal-color-scheme.nix — bridges `stylix.polarity` to the
#     xdg-desktop-portal `color-scheme` interface via dconf so
#     portal-querying apps (Firefox, Zen, libadwaita) follow the
#     host's polarity. Closes the gap #141 left unresolved.
#   - polkit-agent.nix — mate-polkit (GTK3) authentication agent,
#     replacing niri-flake's default KDE agent (disabled system-side
#     in modules/nixos/niri.nix). See docs/desktop/polkit.md (#103).
#   - removable-media.nix — udiskie auto-mount + notifications (tray-less)
#     and the mount.yazi unmount/eject plugin. Pairs with the system-side
#     udisks2 + fs helpers. See docs/desktop/removable-media.md (#105).
#
# First occupant of home/nixos/bundles/. The desktop stack is
# Linux-only (niri, greetd-launched Foot + fuzzel + fnott + waybar
# all carry Linux paths; firefox's xdg.mimeApps wiring is Linux-only
# even though pkgs.firefox builds on Darwin; cursor-ide's launcher
# integration is Linux-only although pkgs.code-cursor builds on
# Darwin) so per scripts/lint-shared-purity.sh this lives under
# nixos/, not shared/.
#
# The system-side companion bundle is at modules/nixos/bundles/desktop-env.nix.
#
# Per ADR-028 (amended by ADR-029).
{
  imports = [
    ../niri.nix
    ../foot.nix
    ../fuzzel.nix
    ../fnott.nix
    ../screen-lock.nix
    ../waybar.nix
    ../firefox.nix
    ../zen-browser.nix
    ../cursor-ide.nix
    ../portal-color-scheme.nix
    ../polkit-agent.nix
    ../removable-media.nix
    # Desktop-only Stylix targets — co-located with the bundle that
    # enables them, so desktop hosts pick them up transitively. The
    # cross-platform TUI targets stay in `home/shared/stylix-targets.nix`.
    ../stylix-targets-desktop.nix
  ];
}
