# fnott — Wayland-native notification daemon.
#
# Stylix theming is wired centrally via `stylix.targets.fnott.enable
# = true` in home/nixos/stylix-targets-desktop.nix; Stylix writes the
# full base16 colour palette including per-urgency-level border accents
# (low → base03, normal → base0D, critical → base08) and the polarity-
# driven icon-theme (when stylix.icons is configured). We override the
# normal-urgency border to base09 (the "attention" accent — distinct from
# the base0D "focus" accent so notifications don't blend into the focused
# window's border); low/critical stay as Stylix writes them. See
# docs/desktop/fnott.md and the accent map (#108).
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
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Mono Nerd Font (monospace slot + popups size), overriding Stylix's
  # sansSerif default for fnott's three font keys so notifications
  # match the rest of the chrome. mkForce: Stylix's fnott target also
  # writes these.
  monoPopup = lib.mkForce "${config.stylix.fonts.monospace.name}:size=${toString config.stylix.fonts.sizes.popups}";
in
{
  # notify-send (libnotify) so the operator can send and test notifications
  # from the terminal; pairs with the fnott daemon. Desktop-only — headless
  # hosts have no notification daemon to talk to.
  home.packages = [ pkgs.libnotify ];

  services.fnott = {
    enable = true;
    settings = {
      main = {
        "title-font" = monoPopup;
        "summary-font" = monoPopup;
        "body-font" = monoPopup;

        # Border 2px + 10px radius, matching the niri/fuzzel chrome. 2px
        # renders crisp on metis's 4K panel at scale 1.5 (1px lands on the
        # half-pixel grid); fnott 1.8 supports both, Stylix sets neither
        # (defaults: thin, square). See docs/desktop/fnott.md.
        "border-size" = 2;
        "border-radius" = 10;
      };

      # Normal-urgency border → base09 ("attention"), distinct from the
      # base0D "focus" accent (see header). mkForce: Stylix's fnott target
      # writes normal → base0D. Format is RRGGBBAA.
      normal."border-color" = lib.mkForce "${config.lib.stylix.colors."base09-hex"}ff";
    };
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
