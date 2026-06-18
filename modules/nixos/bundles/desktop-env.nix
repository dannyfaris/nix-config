# desktop-env — host runs a Wayland desktop session.
#
# Pure aggregation per the bundle-purity rule (PRD §8.1 #3): bundles
# contain only an `imports` list and no inline option setting. The
# capabilities a desktop host needs are factored into standalone modules
# beside this file:
#
#   - niri.nix             — compositor (system enablement + cache opt-out).
#   - keyd.nix             — Caps Lock → Hyper modifier (keyboard parity with the mac's Karabiner).
#   - greetd.nix           — display manager (tuigreet on tty1).
#   - desktop-fonts.nix    — Stylix font selections (mono/sans/emoji) + install wiring.
#   - electron-wayland.nix — NIXOS_OZONE_WL=1 so Electron apps render native Wayland.
#   - libsecret.nix        — secret-tool CLI for the (transitively-enabled) Secret Service.
#   - removable-media.nix  — udisks2 + filesystem helpers (auto-mount is home-side udiskie). See docs/desktop/removable-media.md (#105).
#   - onepassword-gui.nix  — 1Password desktop password manager (GUI only). See docs/desktop/1password.md (#112).
#   - ratbagd.nix          — gaming-mouse device layer (ratbagd + Piper) for the G502 HERO. See docs/desktop/input.md (#107).
#
# The home-side companion bundle is at home/nixos/bundles/desktop-env.nix.
#
# Per ADR-028 (amended by ADR-029).
{
  imports = [
    ../niri.nix
    ../keyd.nix
    ../greetd.nix
    ../desktop-fonts.nix
    ../electron-wayland.nix
    ../libsecret.nix
    ../removable-media.nix
    ../onepassword-gui.nix
    ../ratbagd.nix
  ];
}
