# Bluetooth peripherals for the desktop hosts (#636, #773). The pairing UI rides the shell.
{ config, lib, ... }:
{
  hardware.bluetooth.enable = true;

  # Persist whitelist (module-owns-its-state, docs/design/ephemeral-root.md):
  # device pairings survive the ephemeral root. Gated on persist.enable
  # (adopting hosts only — see modules/nixos/persist.nix).
  environment.persistence."/persist".directories = lib.mkIf config.persist.enable [
    "/var/lib/bluetooth"
  ];
}
