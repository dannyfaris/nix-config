# Disko disk layout for Maia (Lenovo ThinkCentre M720q, bare metal, x86_64) —
# TEMPORARY desktop incarnation.
#
# UEFI GPT, 2 GiB ESP, rest btrfs with three flat subvolumes: @root / @home /
# @nix. The `@` prefix avoids disko#442's mktemp -d collision during install.
#
# No LUKS and no @persist — deliberate for this disposable phase (persist off;
# encryption arrives with the headless reprovision under #557). No disk swap
# (zram only, enabled in default.nix). The eventual headless Maia gets a fresh
# disko with LUKS + @persist; this layout is thrown away with the host.
#
# See ADR-022 (bootstrap), ADR-023 (three-file host structure), disko#442.
{
  disko.devices.disk.main = {
    type = "disk";
    # Single internal drive. VERIFY with `lsblk` from the live USB before
    # invoking nixos-anywhere — the M720q ships in NVMe and SATA storage
    # variants; this assumes NVMe. Change to /dev/sda for a SATA unit.
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
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
            # -L nixos: filesystem label (referenced by ephemeralRoot.device as
            # /dev/disk/by-label/nixos). -f: overwrite any prior signature.
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
