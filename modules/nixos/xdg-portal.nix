# xdg-portal — make xdg-desktop-portal actually work on the niri desktop.
#
# nixpkgs' programs.niri module pins niri's portal routing:
#   default=gnome;gtk;
#   org.freedesktop.impl.portal.Access=gtk;
#   org.freedesktop.impl.portal.Notification=gtk;
#   org.freedesktop.impl.portal.Secret=gnome-keyring;
# and installs the gnome, gnome-keyring and gtk backends. It pins
# FileChooser to gtk only under `useNautilus = false`, which is *not* the
# default — so FileChooser is what this module still has to fix:
#
#   1. (historical, pre-#763) under niri-flake the gtk backend named by
#      those pins was never installed, so Access/Notification routed to a
#      backend that wasn't on the system. nixpkgs installs it.
#   2. FileChooser is unpinned, so it falls to `default` → gnome. But
#      xdg-desktop-portal-gnome doesn't implement the picker itself; it
#      delegates to `org.gnome.Nautilus`. At the time this was diagnosed,
#      Nautilus wasn't installed on this niri box, so a live D-Bus trace
#      showed the frontend calling gnome, gnome calling Nautilus, and the
#      bus returning ServiceUnknown ("The name is not activatable") — so
#      every portal file dialog silently does nothing (found via
#      Obsidian's "Open folder as vault"). This is niri#3765 /
#      nixpkgs#360101. Nautilus is now installed (see
#      docs/desktop/file-manager.md), but FileChooser stays pinned to gtk
#      below rather than gnome/Nautilus — see the fix rationale that
#      follows.
#
# Fix (the non-Nautilus route the niri wiki documents, and what the nixpkgs
# module itself does under `useNautilus = false`):
#   - install the gtk backend (extraPortals) — the general-purpose,
#     GNOME-session-free implementation of FileChooser/Access/Notification.
#     nixpkgs' wayland-session helper now supplies it too, but the pin below
#     is meaningless without the backend, so this module keeps declaring the
#     one its own fix depends on rather than inheriting it.
#   - route FileChooser to it (config.niri), bypassing gnome's Nautilus
#     dependency, exactly as niri already does for Access/Notification.
#
# gnome is kept (first in `default`): it serves ScreenCast and the
# color-scheme Settings bridge that Firefox/GTK dark-light rides on (see
# home/nixos/portal-color-scheme.nix / ADR-044).
#
# niri's other pins are re-declared here verbatim. Since #763 they duplicate
# the nixpkgs module's own definitions rather than replacing a configPackages
# copy: identical values merge, and a divergence — upstream changing a pin,
# or this block drifting — is a loud eval conflict rather than a silent
# behaviour change. Re-sync this block if that fires.
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
