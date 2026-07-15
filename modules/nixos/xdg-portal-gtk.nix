# xdg-portal-gtk — the GTK xdg-desktop-portal backend niri's own config
# names but niri-flake doesn't ship.
#
# niri-flake installs only the gnome general-purpose portal (plus the
# Secret-only gnome-keyring one) — xdg-desktop-portal-gnome is kept: it serves
# ScreenCast and the color-scheme Settings bridge that Firefox/GTK dark-
# light theming rides on — see home/nixos/portal-color-scheme.nix / ADR-044).
# But niri's shipped `niri-portals.conf` declares
#   default=gnome;gtk;
#   org.freedesktop.impl.portal.Access=gtk;
#   org.freedesktop.impl.portal.Notification=gtk;
# — naming a `gtk` backend that was never on the system. FileChooser is the
# loud casualty: since GNOME 43 the gnome portal doesn't implement the file
# picker itself, it delegates to the gtk backend, so with gtk absent every
# portal file dialog fails with "The name is not activatable" (Access and
# Notification routing break silently too).
#
# Adding the gtk portal completes niri's intended setup — gnome stays first
# in the default order (so ScreenCast + Settings are unaffected); gtk only
# fills FileChooser (via delegation) and the two interfaces niri pins to it.
{ pkgs, ... }:
{
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
}
