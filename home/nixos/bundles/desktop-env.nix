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
#   - Theming is delegated to Noctalia's own native engine (ADR-048,
#     reversing ADR-044/#609 for Linux — #819 Epic G, docs/design/
#     noctalia-theming-delegation.md). The theme-menu.nix conductor + its
#     `theme` CLI + portal-color-scheme.nix's dconf bridge are DELETED, not
#     deprecated in place — Nix now declares only the mechanism residue a
#     surface doesn't handle natively (the template whitelist + the
#     colors_changed repaint hook, both in noctalia.nix; the pre-declared
#     foot/niri mount-points). Darwin's home/darwin/theme-menu.nix
#     conductor is untouched.
#   - polkit-agent.nix — mate-polkit (GTK3) authentication agent,
#     replacing niri-flake's default KDE agent (disabled system-side
#     in modules/nixos/niri.nix). See docs/desktop/polkit.md (#103).
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
#     stylix.cursor + niri cursor block). See docs/desktop/pointer-icons.md (#110).
#
# First occupant of home/nixos/bundles/. The desktop stack is
# Linux-only (niri, greetd-launched Foot + the Noctalia shell
# all carry Linux paths; firefox's xdg.mimeApps wiring is Linux-only
# even though pkgs.firefox builds on Darwin; obsidian's launcher
# integration is Linux-only although pkgs.obsidian builds on
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
