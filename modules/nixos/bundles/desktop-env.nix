# desktop-env — host runs a Wayland desktop session.
#
# Pure aggregation per the bundle-purity rule (PRD §8.1 #3): bundles
# contain only an `imports` list and no inline option setting. The
# capabilities a desktop host needs are factored into standalone modules
# beside this file:
#
#   - niri.nix             — compositor (system enablement + cache opt-out).
#   - greetd.nix           — display manager (tuigreet on tty1).
#   - desktop-fonts.nix    — Stylix font selections (mono/sans/emoji) + install wiring.
#   - electron-wayland.nix — NIXOS_OZONE_WL=1 so Electron apps render native Wayland.
#   - libsecret.nix        — secret-tool CLI for the (transitively-enabled) Secret Service.
#
# The home-side companion bundle is at home/nixos/bundles/desktop-env.nix.
#
# Per ADR-028 (amended by ADR-029).
{
  imports = [
    ../niri.nix
    ../greetd.nix
    ../desktop-fonts.nix
    ../electron-wayland.nix
    ../libsecret.nix
  ];
}
