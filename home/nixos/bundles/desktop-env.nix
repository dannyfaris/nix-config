# desktop-env — home-manager pieces for the Wayland desktop session.
#
# Pure aggregation per the bundle-purity rule (PRD §8.1 #3): bundles
# contain only an `imports` list and no inline option setting. The
# user-facing capabilities the desktop session needs are factored into
# standalone modules beside this file:
#
#   - niri.nix — writes the repo-owned config.kdl (lib/niri-config.nix,
#     including the curated bind set; see docs/desktop/keybinds.md for the
#     full taxonomy) after gating it on `niri validate`.
#   - foot.nix — programs.foot.enable.
#   - noctalia.nix — the cohesive shell, v5 native rewrite (ADR-036; #644):
#     bar, launcher, notifications, OSD, lock, wallpaper, clipboard, idle —
#     including the guarded idle→suspend + the lock-on-sleep user unit.
#     Subsumes the waybar/fuzzel/fnott/swaylock+swayidle surfaces, all
#     decommissioned in #385.
#   - firefox.nix — programs.firefox.enable + stub default profile
#     + xdg.mimeApps default-handler registration (Gecko engine,
#     native Wayland; see docs/desktop/firefox.md).
#   - thunderbird.nix — programs.thunderbird.enable (install only;
#     accounts runtime/GUI-managed; Gecko Wayland auto-detect; see
#     docs/desktop/thunderbird.md). Personal Gmail + iCloud (#388).
#   - cursor-ide.nix — home.packages addition for pkgs.code-cursor
#     (AI-coding-focused vscode fork; Wayland via host-wide
#     NIXOS_OZONE_WL set in modules/nixos/electron-wayland.nix).
#   - theme-menu.nix — Nix-declared runtime theme menu: renders one entry dir
#     per declared family (lib/theme-families.nix), maintains the per-target
#     resolved symlinks in $XDG_STATE_HOME/theme-menu/, seeds them at first
#     activation, and ships the `theme` CLI (ADR-044, #609).
#   - portal-color-scheme.nix — documentation marker for the xdg-desktop-portal
#     color-scheme bridge. The dconf write moved into theme-menu.nix's gated
#     seed so rebuilds no longer reset runtime polarity. Closes the gap #141
#     left unresolved (now via theme-menu's seed + `theme` CLI).
#   - polkit-agent.nix — mate-polkit (GTK3) authentication agent, the
#     session's only one (niri ships none). See docs/desktop/polkit.md (#103).
#   - removable-media.nix — udiskie auto-mount + notifications (tray-less)
#     and the mount.yazi unmount/eject plugin. Pairs with the system-side
#     udisks2 + fs helpers. See docs/desktop/removable-media.md (#105).
#   - screen-capture.nix — grim, non-interactive wlr-screencopy capture for
#     remote/agent visual verification over SSH. niri's interactive
#     screenshot UI stays the console path. See docs/desktop/screen-capture.md (#529).
#   - file-manager.nix — trash purge timer + inode/directory handler for
#     Nautilus (system-side package + gvfs in modules/nixos/file-manager.nix).
#     See docs/desktop/file-manager.md (#771).
#   - pointer-icons.nix — Colloid icons + phinger cursor (stylix.icons /
#     stylix.cursor; niri's cursor block reads the same values via niri.nix).
#     See docs/desktop/pointer-icons.md (#110).
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
    # Noctalia Shell v5 — cohesive Wayland shell (ADR-036; #644). waybar,
    # fuzzel, fnott and swaylock + swayidle were all decommissioned in #385;
    # Noctalia owns those surfaces.
    ../noctalia.nix
    ../firefox.nix
    ../thunderbird.nix
    ../cursor-ide.nix
    # obsidian.nix — home.packages addition for pkgs.obsidian (the PKM /
    # notes GUI; unfree, whitelisted in modules/shared/nix-daemon.nix).
    # GUI only; the git-synced ~/wiki vault is separate. See
    # docs/desktop/obsidian.md and docs/design/wiki.md (#506).
    ../obsidian.nix
    # typora.nix — home.packages addition for pkgs.typora (the operator's
    # daily-driver markdown editor; unfree, whitelisted in
    # modules/shared/nix-daemon.nix) plus the xdg.mimeApps default-handler
    # registration for markdown files. See docs/desktop/typora.md.
    ../typora.nix
    ../theme-menu.nix
    ../portal-color-scheme.nix
    ../polkit-agent.nix
    ../removable-media.nix
    ../screen-capture.nix
    ../file-manager.nix
    ../pointer-icons.nix
    # Desktop-only Stylix targets — co-located with the bundle that
    # enables them, so desktop hosts pick them up transitively. The
    # cross-platform TUI targets stay in `home/shared/stylix-targets.nix`.
    ../stylix-targets-desktop.nix
  ];
}
