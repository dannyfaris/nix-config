# Periodic btrfs scrub on every mounted btrfs filesystem (monthly by
# default; tune with services.btrfs.autoScrub.interval if needed). Detects
# silent bit-rot by verifying checksums against stored data; corrects
# errors on its own if redundancy is available, surfaces them via systemd
# otherwise. Runs ionice'd via a systemd timer — negligible foreground
# impact.
{
  services.btrfs.autoScrub.enable = true;
}
