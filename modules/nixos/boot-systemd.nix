# Bootloader configuration.
{ lib, ... }:
{
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;

    # Cap retained boot entries so the ESP can't be filled by accumulated
    # kernel+initrd files. nix.gc's `--delete-older-than 30d`
    # (modules/shared/nix-daemon.nix) is age-based and orthogonal: an
    # active host can accumulate enough generations within 30 days to
    # fill the ESP, and the *next* `nh os switch` then fails to write
    # its boot entry. mkDefault so a host with a smaller ESP can override
    # down without re-declaring the rest. Per #196.
    systemd-boot.configurationLimit = lib.mkDefault 10;
  };
}
