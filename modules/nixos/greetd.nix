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
# --sessions is passed explicitly: tuigreet since 0.11 scans only hardcoded
# /usr/share/wayland-sessions, which no NixOS host has, and no longer consults
# XDG_DATA_DIRS. The niri entry lives in the `desktops` derivation NixOS
# collects from `services.displayManager.sessionPackages` (niri declares itself
# there via `passthru.providedSessions`). Without the flag the greeter offers
# no session and rejects every login with "no command configured".
#
# Per ADR-028.
{ config, pkgs, ... }:
{
  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session = {
      command =
        "${pkgs.tuigreet}/bin/tuigreet"
        + " --time --remember --remember-session --asterisks"
        + " --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
      user = "greeter";
    };
  };
}
