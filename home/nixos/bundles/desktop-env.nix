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
#   - noctalia-shell.nix — the cohesive Quickshell shell: bar, launcher,
#     notifications, OSD, lock, wallpaper, idle (ADR-036, #385). Subsumes
#     the waybar/fuzzel/fnott/swaylock+swayidle surfaces, all decommissioned
#     in #385 (lock + idle-lock + displays-off are now Noctalia's IdleService;
#     see the swaylock note in noctalia.md §Sharp edges for the one accepted gap).
#   - firefox.nix — programs.firefox.enable + stub default profile
#     + xdg.mimeApps default-handler registration (Gecko engine,
#     native Wayland; see docs/desktop/firefox.md).
#   - thunderbird.nix — programs.thunderbird.enable (install only;
#     accounts runtime/GUI-managed; Gecko Wayland auto-detect; see
#     docs/desktop/thunderbird.md). Personal Gmail + iCloud (#388).
#   - cursor-ide.nix — home.packages addition for pkgs.code-cursor
#     (AI-coding-focused vscode fork; Wayland via host-wide
#     NIXOS_OZONE_WL set in modules/nixos/electron-wayland.nix).
#   - portal-color-scheme.nix — bridges `stylix.polarity` to the
#     xdg-desktop-portal `color-scheme` interface via dconf so
#     portal-querying apps (Firefox, libadwaita) follow the
#     host's polarity. Closes the gap #141 left unresolved.
#   - polkit-agent.nix — mate-polkit (GTK3) authentication agent,
#     replacing niri-flake's default KDE agent (disabled system-side
#     in modules/nixos/niri.nix). See docs/desktop/polkit.md (#103).
#   - removable-media.nix — udiskie auto-mount + notifications (tray-less)
#     and the mount.yazi unmount/eject plugin. Pairs with the system-side
#     udisks2 + fs helpers. See docs/desktop/removable-media.md (#105).
#
# First occupant of home/nixos/bundles/. The desktop stack is
# Linux-only (niri, greetd-launched Foot + the Noctalia shell
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
    # set-font — runtime remap of a fontconfig generic (the conductor's
    # friendly front-end; #390). See docs/desktop/fonts.md §Runtime UX.
    ../set-font.nix
    # Noctalia Shell — cohesive Wayland shell (ADR-036, #385). waybar, fuzzel,
    # fnott and (last, once Noctalia's lock + idle were verified) swaylock +
    # swayidle were all decommissioned in #385; Noctalia owns those surfaces.
    ../noctalia-shell.nix
    ../firefox.nix
    ../thunderbird.nix
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
