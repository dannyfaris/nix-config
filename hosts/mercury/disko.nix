# Disko disk layout for Mercury (AWS EC2, Nitro, x86_64, t3.medium).
#
# Single EBS volume at /dev/nvme0n1 (Nitro presents EBS as NVMe). GPT,
# 512 MiB ESP + ext4 root filling the rest. UEFI boot via the ESP —
# paired with `ec2.efi = true` in default.nix.
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
          size = "512M";
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
