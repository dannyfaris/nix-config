# Darwin-side companion to modules/shared/nix-daemon.nix — owns the
# nix-daemon knobs that nix-darwin expresses differently from NixOS.
#
# Two pieces today:
#
# - `nix.gc.interval` — launchd-style scheduling. NixOS uses
#   `nix.gc.dates = "weekly"` (systemd-calendar string); nix-darwin
#   takes a list of `StartCalendarInterval` blocks (each an attrset of
#   Weekday / Day / Hour / Minute integers). `Weekday = 7` (or
#   equivalently 0) is Sunday in launchd's convention; pinning
#   Hour/Minute keeps the run off-hours.
#
# - `nix.optimise.automatic = true` — scheduled hardlink-dedupe of
#   /nix/store. nix-darwin asserts a narrow nix/lix version window on
#   `nix.settings.auto-optimise-store = true` (the at-write variant the
#   NixOS sibling uses) to guard against race-condition data-corruption
#   bugs in older nix versions; the scheduled `optimise` operation
#   doesn't have the same race window so it's safe across all
#   supported nix versions. Net dedupe is equivalent; just deferred to
#   the scheduled run instead of every write.
#
# Sibling to modules/nixos/nix-daemon-nixos.nix.
_: {
  nix.gc.interval = [
    {
      Weekday = 7;
      Hour = 4;
      Minute = 0;
    }
  ];

  nix.optimise.automatic = true;
}
