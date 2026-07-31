# Screen + keyboard backlight control (#636).
{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Screen + kbd backlight via the logind seat ACL — no udev rules needed.
  environment.systemPackages = [ pkgs.brightnessctl ];

  # Persist whitelist (module-owns-its-state, docs/design/ephemeral-root.md):
  # systemd-backlight restore has nothing to read across ephemeral-root
  # reboots without this. Stand-in owner for systemd-created state (idiom
  # per persist-os-core.nix). Gated on persist.enable (adopting hosts only).
  environment.persistence."/persist".directories = lib.mkIf config.persist.enable [
    "/var/lib/systemd/backlight"
  ];
}
