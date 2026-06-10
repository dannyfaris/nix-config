# fnott — Wayland-native notification daemon.
#
# Stylix theming is wired centrally via `stylix.targets.fnott.enable
# = true` in home/nixos/stylix-targets-desktop.nix; Stylix writes the
# full base16 colour palette including per-urgency-level border accents
# (low → base03, normal → base0D, critical → base08) and the polarity-
# driven icon-theme (when stylix.icons is configured). We don't
# override Stylix's colour writes.
#
# Font: we DO override Stylix here. Stylix would default fnott's three
# font keys to the sansSerif slot (Inter); instead the Wayland chrome
# uses the one mono Nerd Font (JetBrainsMono Nerd Font), matching foot,
# waybar, and fuzzel. See docs/desktop/fnott.md.
#
# Lives under nixos/ because fnott is Wayland-only and doesn't
# compile off Linux — same placement reasoning as foot.nix and
# fuzzel.nix. macOS hosts get notifications from macOS Notification
# Center natively; no fnott equivalent is wired.
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
{ config, lib, ... }:
let
  # Mono Nerd Font (monospace slot + popups size), overriding Stylix's
  # sansSerif default for fnott's three font keys so notifications
  # match the rest of the chrome. mkForce: Stylix's fnott target also
  # writes these.
  monoPopup = lib.mkForce "${config.stylix.fonts.monospace.name}:size=${toString config.stylix.fonts.sizes.popups}";
in
{
  services.fnott.enable = true;
  services.fnott.settings.main = {
    "title-font" = monoPopup;
    "summary-font" = monoPopup;
    "body-font" = monoPopup;
  };

  # Restart fnott when its rendered config changes. fnott reads config
  # only at startup (no file-watch, no reload signal) and its ExecStart
  # is a stable symlink, so without this an `nh os switch` font/colour
  # edit leaves the daemon serving stale settings until a manual
  # restart. See docs/desktop/fnott.md §Sharp edges.
  systemd.user.services.fnott.Unit.X-Restart-Triggers = [
    config.xdg.configFile."fnott/fnott.ini".source
  ];
}
