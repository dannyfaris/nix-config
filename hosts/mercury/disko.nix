# Disko disk layout for Mercury (AWS EC2, Nitro, x86_64, t3.medium).
#
# Single EBS volume at /dev/nvme0n1 (Nitro presents EBS as NVMe). GPT,
# 1 GiB ESP + ext4 root filling the rest. UEFI boot via the ESP —
# paired with `ec2.efi = true` in default.nix.
#
# ESP at 1 GiB: comfortable for 15-20 retained generations of
# systemd-boot's kernel+initrd. Floor is ~512 MiB (5-8 gens); 1 GiB
# gives ergonomic headroom on a cheap EBS volume.
#
# amazon-image.nix's fileSystems declarations are lib.mkDefault
# (nixpkgs PR #377406, merged Feb 2026), so disko wins without
# mkForce. Adding mkForce here would actively break eval per the
# 25.05 release notes.
#
# See ADR-022 (bootstrap), ADR-023 (three-file host structure).
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "fmask=0022" "dmask=0022" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
