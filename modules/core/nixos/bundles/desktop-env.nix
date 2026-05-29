# desktop-env — host runs a Wayland desktop session.
#
# Pure aggregation per the bundle-purity rule (PRD §8.1 #4): bundles
# contain only an `imports` list and no inline option setting. The
# capabilities a desktop host needs are factored into standalone modules
# beside this file:
#
#   - niri.nix             — compositor (system enablement + cache opt-out).
#   - greetd.nix           — display manager (tuigreet on tty1).
#   - desktop-fonts.nix    — Stylix font selections (mono/sans/emoji) + install wiring.
#   - dms-home-bridge.nix  — bridges DMS HM modules into home-manager.sharedModules.
#
# The home-side companion bundle is at home/core/nixos/bundles/desktop-env.nix.
#
# Per ADR-028.
{
  imports = [
    ../niri.nix
    ../greetd.nix
    ../desktop-fonts.nix
    ../dms-home-bridge.nix
  ];
}
