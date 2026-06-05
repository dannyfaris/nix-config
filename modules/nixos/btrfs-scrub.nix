# Periodic btrfs scrub on every mounted btrfs filesystem (monthly by
# default; tune with services.btrfs.autoScrub.interval if needed). Detects
# silent bit-rot by verifying checksums against stored data; corrects
# errors on its own if redundancy is available, surfaces them via systemd
# otherwise. Runs ionice'd via a systemd timer — negligible foreground
# impact.
#
# "Surfaces via systemd" only helps if something watches systemd; on a box
# no one logs into, a failed scrub is the bit-rot signal that must not be
# missed. So each scrub service opts into the fleet failure notifier (#199)
# — see modules/nixos/unit-failure-notifier.nix.
{
  config,
  lib,
  utils,
  ...
}:
let
  # autoScrub creates one service per btrfs filesystem, named
  # btrfs-scrub-<escaped-mountpoint> (root `/` → btrfs-scrub--). Derive the
  # names from the same source autoScrub uses, so onFailure tracks whatever
  # mounts it picks up rather than hardcoding an escaped path.
  scrubServices = map (
    fs: "btrfs-scrub-${utils.escapeSystemdPath fs}"
  ) config.services.btrfs.autoScrub.fileSystems;
in
{
  services.btrfs.autoScrub.enable = true;

  systemd.services = lib.genAttrs scrubServices (_: {
    onFailure = [ "notify-failure@%n.service" ];
  });
}
