# PLACEHOLDER — regenerate on the actual M720q at bootstrap.
#
# This is NOT `nixos-generate-config` output; it is a hand-written stub so the
# flake evaluates and builds before the hardware exists. At install, replace it
# wholesale with the generated hardware-configuration.nix from the target
# (nixos-anywhere / nixos-generate-config), which carries the M720q's real
# initrd module set. The lists below are a generic Intel-mini-PC guess (mirrors
# metis, a comparable Intel mini PC) and must NOT be trusted until regenerated.
# `nixpkgs.hostPlatform` here is the single source of truth for the platform
# (ADR-023), which is why the stub sets it.
{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "uas"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
