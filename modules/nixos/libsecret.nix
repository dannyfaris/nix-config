# libsecret — the libsecret CLI (`secret-tool`), system-installed.
#
# The Secret Service daemon (`org.freedesktop.secrets`, provided by
# gnome-keyring) is already running on this host as a transitive
# consequence of niri-flake's nixosModule — see docs/desktop/gnome-keyring.md
# for the full picture of inherited state vs what this slice actually
# owns. The only concrete addition #104 makes to the configuration is
# putting `secret-tool` on PATH so the operator can:
#
#   1. Verify the PAM auto-unlock works under tuigreet (the primary
#      sharp edge): after login, a `secret-tool store`/`lookup`
#      round-trip should succeed without prompting.
#   2. Script against the Secret Service from the shell when needed
#      (debugging, one-off lookups, future automation).
#
# System-level placement matches the desktop-env bundle's other modules
# (electron-wayland, greetd, …): the CLI is a desktop-host capability,
# available regardless of which user is logged in. Closure cost is
# small — libsecret is already pulled in by libsecret-using daemons and
# clients on metis; this just exposes the CLI binaries.
#
# Per #104. The gnome-keyring activation itself is accepted as
# inherited from niri-flake's nixosModule (same precedent as
# xdg.portal.enable, also inherited and not re-asserted) — see the
# doc for the full inheritance picture.
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.libsecret ];
}
