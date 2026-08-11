# greetd + tuigreet — Wayland-aware display manager.
#
# tuigreet runs on tty1 (greetd's hardcoded VT — the per-host `vt`
# option was removed upstream with the message "The VT is now fixed to
# VT1"). Break-glass: kernel TTYs 2-6 remain unmanaged getty entries
# (Ctrl-Alt-F2..F6) so the operator can drop to a shell if greetd or
# the session manager misbehaves. CLAUDE.md's "break-glass via physical
# console" posture is preserved by this path.
#
# useTextGreeter switches the systemd unit to TTY-input plumbing
# (TTYReset/TTYVHangup/TTYVTDisallocate); without it, kernel/systemd
# messages can paint over the tuigreet UI during cold boot.
#
# tuigreet discovers wayland-sessions through XDG_DATA_DIRS — no --sessions
# flag needed. The entry comes from `services.displayManager.sessionPackages`,
# which NixOS collects into the `desktops` derivation that XDG_DATA_DIRS points
# at; the niri package declares itself there via `passthru.providedSessions`.
# NOT from system-path: `environment.pathsToLink` carries no wayland-sessions
# entry, so /run/current-system/sw/share/wayland-sessions does not exist (the
# comment here asserted otherwise until #763 checked the built system).
#
# Per ADR-028.
{ pkgs, ... }:
{
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet" + " --time --remember --remember-session --asterisks";
      user = "greeter";
    };
  };
}
