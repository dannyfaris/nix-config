# Gaming-mouse device layer (#107) — ratbagd + Piper for the Logitech
# G502 HERO's DPI tiers, button remaps, report rate, and onboard profiles.
# These are written to the mouse's onboard memory and travel with the
# hardware, so they are deliberately NOT declared in the flake: the flake
# enables the capability, the device carries the state. Compositor-layer
# pointer feel (accel/scroll) is separate, in niri (home/nixos/niri.nix).
# Selection rationale: docs/desktop/input.md.
{ pkgs, ... }:
{
  # D-Bus-activated daemon (do not systemctl-enable it). `enable` also puts
  # `ratbagctl` on PATH — preferred over Piper for the HERO's side buttons,
  # which have open mapping bugs in the GUI (input.md §Sharp edges).
  services.ratbagd.enable = true;

  # Piper — the GTK frontend over ratbagd, for DPI/profile editing by GUI
  # (the operator's stated preference). Useless without the daemon above.
  environment.systemPackages = [ pkgs.piper ];
}
