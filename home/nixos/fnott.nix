# fnott — Wayland-native notification daemon.
#
# Stylix theming is wired centrally via `stylix.targets.fnott.enable
# = true` in home/shared/stylix-targets.nix; Stylix writes
# three fonts (title/summary/body all Inter at popups size), full
# base16 colour palette including per-urgency-level border accents
# (low → base03, normal → base0D, critical → base08), and the
# polarity-driven icon-theme (when stylix.icons is configured). We
# deliberately don't override Stylix's writes — this module is
# enable-only.
#
# Lives under nixos/ because fnott is Wayland-only and doesn't
# compile off Linux — same placement reasoning as foot.nix and
# fuzzel.nix. macOS hosts get notifications from macOS Notification
# Center natively when home/darwin/ lands per the mac-mini
# onboarding epic #11.
#
# Auto-start is D-Bus-activated, not session-target-pulled: HM's
# services.fnott module ships an org.freedesktop.Notifications D-Bus
# service file pointing at fnott.service, and the unit comes up the
# first time any client emits a notification. PartOf =
# graphical-session.target ties shutdown to session lifetime for
# clean teardown.
#
# Verification on fresh login: `systemctl --user status fnott.service`
# reads inactive (dead) until the first notification arrives. Test
# with `notify-send test`. See docs/desktop/fnott.md for the full
# selection rationale and sharp edges.
#
# Per #74.
_: {
  services.fnott.enable = true;
}
