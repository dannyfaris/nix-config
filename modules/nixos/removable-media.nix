# Removable media (system side) — udisks2 (the mount daemon) + the userspace
# filesystem helpers it shells out to. Auto-mount, notifications, and the
# browse surface are home-side (home/nixos/removable-media.nix: udiskie + the
# mount.yazi plugin). See docs/desktop/removable-media.md (#105).
#
# Mounting a removable device is passwordless for the active local session
# (udisks2's filesystem-mount polkit action defaults to allow_active = yes),
# so this does NOT depend on the polkit agent (#103) and needs no
# storage-group polkit rule — only internal/system disks would prompt.
{ pkgs, ... }:
{
  services.udisks2.enable = true;

  # Userspace mount helpers udisks2 invokes for common USB filesystems,
  # named explicitly (whitelist > blanket): exFAT, NTFS, FAT. exfatprogs is
  # the current exFAT package (the old exfat/exfat-utils FUSE pkgs are
  # deprecated); ntfs3g gives reliable NTFS read-write (udisks2 prefers it
  # over the in-kernel ntfs3 driver, which has documented mount quirks);
  # dosfstools covers FAT.
  environment.systemPackages = with pkgs; [
    exfatprogs
    ntfs3g
    dosfstools
  ];
}
