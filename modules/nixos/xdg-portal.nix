# xdg-portal — make xdg-desktop-portal actually work on the niri desktop.
#
# niri ships a portal config (`niri-portals.conf`, delivered via
# xdg.portal.configPackages) that reads:
#   default=gnome;gtk;
#   org.freedesktop.impl.portal.Access=gtk;
#   org.freedesktop.impl.portal.Notification=gtk;
#   org.freedesktop.impl.portal.Secret=gnome-keyring;
# but niri-flake installs only the gnome and gnome-keyring backends — never
# the gtk one those pins name. Two failures result:
#
#   1. Access/Notification route to a gtk backend that isn't on the system.
#   2. FileChooser is unpinned, so it falls to `default` → gnome. But
#      xdg-desktop-portal-gnome doesn't implement the picker itself; it
#      delegates to `org.gnome.Nautilus`, which isn't installed on this
#      niri box. A live D-Bus trace showed the frontend calling gnome,
#      gnome calling Nautilus, and the bus returning ServiceUnknown ("The
#      name is not activatable") — so every portal file dialog silently
#      does nothing (found via Obsidian's "Open folder as vault"). This is
#      niri#3765 / nixpkgs#360101.
#
# Fix (the non-Nautilus route the niri wiki documents, and exactly what the
# nixpkgs programs.niri module does under `useNautilus = false` — an option
# niri-flake's module does not expose, so we wire it by hand):
#   - install the gtk backend (extraPortals) — the general-purpose,
#     GNOME-session-free implementation of FileChooser/Access/Notification.
#   - route FileChooser to it (config.niri), bypassing gnome's Nautilus
#     dependency, exactly as niri already does for Access/Notification.
#
# gnome is kept (first in `default`): it serves ScreenCast and the
# color-scheme Settings bridge that Firefox/GTK dark-light rides on (see
# home/nixos/portal-color-scheme.nix / ADR-044).
#
# Defining xdg.portal.config.niri makes NixOS ignore niri's configPackages
# copy entirely and write a wholesale /etc/xdg override, so niri's other
# pins are re-declared here verbatim (drop one and e.g. Secret silently
# breaks). Re-sync this block if niri changes its portal defaults.
{ pkgs, ... }:
{
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  xdg.portal.config.niri = {
    default = [
      "gnome"
      "gtk"
    ];
    "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ]; # the fix; the rest mirror niri-portals.conf
    "org.freedesktop.impl.portal.Access" = [ "gtk" ];
    "org.freedesktop.impl.portal.Notification" = [ "gtk" ];
    "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
  };
}
