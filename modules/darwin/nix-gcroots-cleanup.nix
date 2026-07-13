# Nix GC-roots cleanup daemon for the Darwin hosts. nix-darwin does not automatically
# remove dead symlinks from /nix/var/nix/gcroots — NixOS handles this via
# its own periodic maintenance, but macOS has no equivalent. Dead symlinks
# silently pin store paths against GC: `nix store gc` honours every gcroot
# it finds, live or dangling.
#
# Script posture: best-effort per-step. `set -u` catches undefined variable
# bugs; `-e` is omitted so a failed deletion (e.g. a root that disappeared
# mid-run) does not abort remaining steps. No `|| true` needed — without
# `-e` each find runs to completion regardless of its exit code. Two steps
# in order, narrowest-to-broadest:
#
#   1. Stale temproots (> 10 days): PIDs written by active builds. On a
#      crashed or killed build the file is never cleaned up; after 10 days
#      the PID has certainly exited. Verified present on neptune
#      (/nix/var/nix/temproots exists; files named by PID).
#
#   2. Dangling symlinks (-xtype l) anywhere under gcroots: the target no
#      longer resolves — the store path (or the intermediate result symlink)
#      is already gone. This is the only safe age-independent vector:
#      a non-dangling gcroot, however old, may still protect a live build
#      the operator cares about. Age-based deletion of non-dangling roots
#      (the -mtime +30 form the issue proposed) was deliberately dropped
#      because `auto` roots can point to project .direnv paths that stay live
#      indefinitely — deleting the gcroot changes GC behaviour for builds
#      the operator has not explicitly invalidated. Dangling-only is safe;
#      age-only is not.
#
# No automatic Darwin GC accompanies this daemon today; the cleanup still
# pays off for manual `nix store gc` runs and for keeping gcroot accounting
# honest. Should a Darwin GC daemon be added later, schedule it after this
# cleanup (dead-root pruning → GC is more effective than GC → pruning).
#
# Schedule: Sunday 03:30, chosen to run shortly before the existing nix GC
# (nix-daemon-darwin.nix: Weekday = 7; Hour = 4; Minute = 0). If a run is
# missed while the host is asleep, launchd coalesces all missed intervals
# into one event and fires it on next wake — semantics are catch-up, not skip.
#
# Post-activation verification:
#   sudo launchctl print system/org.nixos.nix-gcroots-cleanup
# Manual trigger (with a pre-planted dangling link to confirm deletion):
#   sudo launchctl kickstart -k system/org.nixos.nix-gcroots-cleanup
{ pkgs, ... }:
{
  launchd.daemons.nix-gcroots-cleanup = {
    script = ''
      set -u
      ${pkgs.findutils}/bin/find /nix/var/nix/temproots -type f -mtime +10 -delete
      ${pkgs.findutils}/bin/find /nix/var/nix/gcroots -xtype l -delete
    '';
    serviceConfig.StartCalendarInterval = [
      {
        Weekday = 7;
        Hour = 3;
        Minute = 30;
      }
    ];
  };
}
