# Hardware configuration for Metis (HP ProDesk Mini 600 G9, x86_64-linux,
# bare metal).
#
# Filesystem layout: btrfs on a single NVMe partition with three flat
# subvolumes (root / home / nix). Snapshot tooling is intentionally NOT
# wired up — the layout is a clean foundation we can layer Snapper onto
# later if needed, without restructuring.
#
# The kernel-module list below is a placeholder. Real values get filled in
# during install from `nixos-generate-config --no-filesystems` output —
# see docs/runbooks/headless-bootstrap-metis.md (Phase 7) for the exact
# block-replacement procedure. Everything else in this file (the
# `btrfsOpts` let-binding, the `fileSystems` entries, `zramSwap.enable`,
# `boot.supportedFilesystems`) is the committed configuration and must
# survive that replacement.
#
# Full bootstrap procedure: docs/runbooks/headless-bootstrap-metis.md.
#
{ lib, ... }:
let
  # Shared mount options for every btrfs subvolume on the NVMe SSD:
  #   compress=zstd:1 — transparent compression, near-zero CPU cost.
  #   noatime         — skip atime updates on read, cutting CoW write churn.
  #   ssd             — SSD-aware allocator behaviour.
  #   discard=async   — batched TRIM (smoother than sync discard).
  btrfsOpts = subvol: [
    "subvol=${subvol}"
    "compress=zstd:1"
    "noatime"
    "ssd"
    "discard=async"
  ];
in
{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # PLACEHOLDER kernel modules — replace with nixos-generate-config output.
  # `nvme` is included unconditionally: without it, stage-1 cannot see the
  # NVMe disk and the boot drops to an emergency shell.
  boot.initrd.availableKernelModules = [
    "nvme"
    "ahci"
    "xhci_pci"
    "ehci_pci"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # Defensive: a fileSystems entry with fsType="btrfs" already pulls the
  # module into the initrd, but stating it explicitly matches what
  # nixos-generate-config emits and survives future refactors.
  boot.supportedFilesystems = [ "btrfs" ];

  # btrfs root, three flat subvolumes sharing one partition.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = btrfsOpts "root";
  };
  fileSystems."/home" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = btrfsOpts "home";
  };
  fileSystems."/nix" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "btrfs";
    options = btrfsOpts "nix";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  # No disk swap. Compressed RAM-backed swap as an overflow valve for cold
  # anonymous pages — keeps reclaim graceful under load with zero SSD wear.
  # Default sizing (50 % of RAM, zstd) is appropriate for 32 GiB.
  zramSwap.enable = true;
  swapDevices = [ ];
}
