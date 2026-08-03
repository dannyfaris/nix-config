# mobility — host is a battery-powered portable, so it needs laptop
# posture (power, backlight, Bluetooth peripherals). Hardware-agnostic:
# it sets how *any* laptop behaves, so a future portable reuses it
# unchanged.
#
# The silicon seam (#636): surface.nix is host-scoped and makes this
# exact battery *readable* (SAM/battery/charger drivers); this bundle
# sets how a laptop should *behave* on top of that telemetry.
#
# Pure aggregation per the bundle-purity rule (PRD §8.1 #3): the
# capabilities are factored into standalone modules beside this file —
#
#   - power.nix            — power posture (upower telemetry, platform
#                            profiles, s2idle suspend, lid handling).
#   - backlight.nix        — screen + keyboard backlight control.
#   - bluetooth.nix        — Bluetooth for laptop peripherals.
#   - wifi-mac-privacy.nix — per-SSID Wi-Fi MAC, so a roaming host is not
#                            linkable across networks.
{
  imports = [
    ../power.nix
    ../backlight.nix
    ../bluetooth.nix
    ../wifi-mac-privacy.nix
  ];
}
