# storage-integrity — host tells the operator when its storage is going
# wrong. A bundle rather than foundation: see ADR-027 §History
# ("Storage-integrity capability bundle").
#
# The two members answer different questions and neither substitutes for
# the other: a scrub finds data that has *already* rotted, SMART reports a
# drive that is *about to* fail.
#
# Pure aggregation per the bundle-purity rule (PRD §8.1 #3):
#
#   - btrfs-scrub.nix — periodic checksum verification of what is on disk.
#   - disk-health.nix — the drive's own pre-failure counters, via SMART.
{
  imports = [
    ../btrfs-scrub.nix
    ../disk-health.nix
  ];
}
