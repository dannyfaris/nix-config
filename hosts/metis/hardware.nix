# Placeholder hardware configuration for Metis (HP ProDesk Mini 600 G9,
# x86_64-linux, bare metal).
#
# PLACEHOLDER — replace with nixos-generate-config output after installation.
#
# Bootstrap procedure (run once after the ISO install):
#
# 1. Boot the NixOS ISO and install normally (accept the generated config).
#
# 2. Boot into the installed system. Retrieve the SSH host age key:
#      nix-shell -p ssh-to-age --run \
#        'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
#
# 3. On the Mac: add the resulting age key to .sops.yaml alongside the
#    existing &nixos-vm key, then re-encrypt so both hosts can decrypt:
#      sops updatekeys secrets/secrets.yaml
#
# 4. Replace this file with the actual hardware config:
#      nixos-generate-config --show-hardware-config
#    Copy the output here (fileSystems, initrd modules, kernelModules,
#    swapDevices — replace placeholder values below with real ones).
#
# 5. Commit, push, then on metis:
#      nixos-rebuild switch --flake .#metis
#
{ lib, ... }:
{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Placeholder kernel modules — replace with nixos-generate-config output.
  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "ehci_pci"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Placeholder filesystems — replace with actual values from nixos-generate-config.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  swapDevices = [ ];
}
