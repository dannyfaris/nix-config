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
#   - power.nix           — power posture (upower telemetry, platform
#                           profiles, s2idle suspend, lid handling).
#   - backlight.nix       — screen + keyboard backlight control.
#   - bluetooth.nix       — Bluetooth for laptop peripherals.
#   - roaming-privacy.nix — the identifiers a portable broadcasts on every
#                           network it joins (Wi-Fi MAC, DHCP hostname).
{
  imports = [
    ../power.nix
    ../backlight.nix
    ../bluetooth.nix
    ../roaming-privacy.nix
  ];
}
