# Disko disk layout for Metis (HP ProDesk Mini 600 G9, bare metal, x86_64).
#
# UEFI GPT, 2 GiB ESP, rest as btrfs with three flat subvolumes:
# @root / @home / @nix. The `@` prefix avoids disko#442's mktemp -d
# collision during install. Mount options exclude `discard=async` and
# `ssd` — both are auto-applied by Linux 6.2+ on capable devices;
# NixOS 25.11 ships Linux 6.12, so listing them would be noise.
#
# No LUKS (unattended boot after power loss is required — see the
# Metis decisions table in the runbook). No disk swap (zram only,
# enabled in default.nix).
#
# See ADR-022 (bootstrap), ADR-023 (three-file host structure),
# disko#442 (the @ prefix gotcha).
{
  disko.devices.disk.main = {
    type = "disk";
    # Single internal NVMe. Verify with `lsblk` from the live USB
    # before invoking nixos-anywhere — the ProDesk Mini 600 G9 ships
    # in multiple storage variants (NVMe SSD, SATA SSD).
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          # 2 GiB — comfortable for 15-20 retained systemd-boot
          # generations (kernel + initrd per generation).
          size = "2G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [
              "fmask=0022"
              "dmask=0022"
            ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "btrfs";
            # -L nixos: filesystem label. -f: required to overwrite
            # any prior filesystem signature (fresh install or
            # reinstall on the same disk).
            extraArgs = [
              "-L"
              "nixos"
              "-f"
            ];
            subvolumes = {
              "@root" = {
                mountpoint = "/";
                mountOptions = [
                  "subvol=@root"
                  "compress=zstd:1"
                  "noatime"
                ];
              };
              "@home" = {
                mountpoint = "/home";
                mountOptions = [
                  "subvol=@home"
                  "compress=zstd:1"
                  "noatime"
                ];
              };
              "@nix" = {
                mountpoint = "/nix";
                mountOptions = [
                  "subvol=@nix"
                  "compress=zstd:1"
                  "noatime"
                ];
              };
            };
          };
        };
      };
    };
  };
}
