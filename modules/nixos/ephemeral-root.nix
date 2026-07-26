# Ephemeral root — archive-rollback of the btrfs @root subvolume at every
# boot, so nothing on / survives a reboot except the impermanence persist
# whitelist. Design + rationale: docs/design/ephemeral-root.md (#553).
#
# Two parts:
#   1. A systemd stage-1 *initrd* service that, before sysroot.mount, mounts
#      the btrfs top level (subvolid=5), renames @root into a timestamped
#      roots-archive/ entry, and creates a fresh empty @root. Fail-safe: any
#      error leaves the existing @root in place and lets boot proceed.
#   2. A normal-boot *purge* timer that transiently mounts the top level and
#      recursively deletes archives older than `retentionDays`.
#
# Scripted-initrd hooks (boot.initrd.postDeviceCommands / postResumeCommands)
# are INERT under systemd stage-1 (the fleet default) — this is a real
# initrd systemd service, per §De-risk.
{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.ephemeralRoot;

  # The systemd .device unit for the backing device. escapeSystemdPath turns
  # /dev/disk/by-label/nixos into dev-disk-by\x2dlabel-nixos, matching what
  # systemd names the device unit (a naive /->- replace mishandles the
  # embedded '-' in by-label). Same helper btrfs-scrub.nix uses for mounts.
  deviceUnit = "${utils.escapeSystemdPath cfg.device}.device";

  # The degraded marker the running system (and the probe, #633) reads to
  # learn the initrd rollback bailed out. On tmpfs /run so it is naturally
  # per-boot; the running system sees whatever this boot's initrd wrote.
  degradedMarker = "/run/ephemeral-root-degraded";

  # Runtime deps of the normal-boot purge service: btrfs subvolume
  # list/delete, mount/umount, find (findutils), awk/sort/cut, mkdir/rm.
  purgeTools = [
    pkgs.btrfs-progs
    pkgs.util-linux
    pkgs.coreutils
    pkgs.findutils
    pkgs.gawk
  ];
in
{
  options.ephemeralRoot = {
    enable = lib.mkEnableOption "btrfs archive-rollback of @root at every boot";

    device = lib.mkOption {
      type = lib.types.str;
      description = ''
        The backing btrfs block device (the whole filesystem, any subvolume).
        Mounted at subvolid=5 in the initrd to rename @root and create a
        fresh one. Match the device disko formats (e.g. by /dev/disk/by-label).
      '';
      example = "/dev/disk/by-label/nixos";
    };

    retentionDays = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 30;
      description = ''
        Archived roots older than this many days are purged (recursively,
        nested subvolumes included) by the normal-boot purge timer. The one
        figure attested in prior art; a starting point, not a defended value.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      # ---- 1. The initrd rollback service -------------------------------
      boot.initrd = {
        # btrfs-progs must be in the initrd store closure for the service.
        systemd.initrdBin = [ pkgs.btrfs-progs ];

        # The rollback mounts btrfs in the initrd, BEFORE sysroot.mount pulls
        # the real root's fs module in — so btrfs must be force-loaded early,
        # not left to the root-fs machinery. Without this the service's mount
        # fails with "unknown filesystem type 'btrfs'" and bails (no wipe). A
        # host with a btrfs root has btrfs in the initrd anyway, but at an
        # ordering the pre-sysroot service cannot rely on; this makes it
        # explicit.
        kernelModules = [ "btrfs" ];

        systemd.services.ephemeral-root-rollback = {
          description = "Archive @root and create a fresh empty @root";

          # Ordering: after the backing device appears (ordering only — no
          # `wants`), strictly before the real root is mounted. DefaultDependencies
          # off — a boot-critical unit must not acquire the usual shutdown/basic
          # ordering that could sequence it after sysroot.mount.
          #
          # `after` WITHOUT `wants` is deliberate and fail-safe: on a real host the
          # root-fs machinery already pulls the device in, so `after` orders us
          # correctly behind it; but pulling it in ourselves (`wants`) would make a
          # boot where the device never appears BLOCK the initrd on a device job
          # that never completes. Ordering-only means the service instead runs and
          # bails on the mount, letting boot proceed — the fail-safe direction.
          wantedBy = [ "initrd-root-fs.target" ];
          before = [ "sysroot.mount" ];
          after = [ deviceUnit ];
          unitConfig.DefaultDependencies = false;

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            # Bound the mount attempt so a wedged device can't stall the initrd;
            # on timeout the service fails, but the wrapper below never fails the
            # boot (it exits 0 on every path).
            TimeoutStartSec = "30s";
          };

          # The whole body is wrapped so it can NEVER fail the boot: the script
          # exits 0 on every path. A helper `bail` logs, writes the degraded
          # marker, and exits 0 leaving @root untouched — the fail-safe
          # direction is structural (every error routes through bail), not
          # incidental. `set -u` catches typos; there is deliberately no
          # `set -e` — we handle each step's failure explicitly via bail.
          script = ''
            set -u
            TOP=/run/ephemeral-root-toplevel

            bail() {
              echo "ephemeral-root: $1 — leaving existing @root in place, booting on it" >&2
              mkdir -p "$(dirname ${degradedMarker})" 2>/dev/null || true
              echo "$1" > ${degradedMarker} 2>/dev/null || true
              # Best-effort cleanup of the transient mount so sysroot.mount is free.
              umount "$TOP" 2>/dev/null || true
              exit 0
            }

            # Kill-switch: checked FIRST. If ephemeral.skip-rollback is on the
            # kernel cmdline, skip the rollback entirely for this one boot. Shell
            # `case` (not grep — gnugrep is not in the default systemd initrd);
            # space-padding makes the match word-safe.
            case " $(cat /proc/cmdline) " in
              *' ephemeral.skip-rollback '*)
                echo "ephemeral-root: ephemeral.skip-rollback on cmdline — skipping rollback this boot" >&2
                exit 0
                ;;
            esac

            mkdir -p "$TOP" || bail "could not create mount point"

            # Mount the btrfs top level (subvolid=5): the level that holds @root
            # and roots-archive/ as sibling subvolumes.
            mount -t btrfs -o subvolid=5 "${cfg.device}" "$TOP" \
              || bail "could not mount btrfs top level (${cfg.device})"

            # If there is no @root to archive (fresh disk), just make one.
            if [ ! -e "$TOP/@root" ]; then
              btrfs subvolume create "$TOP/@root" || bail "could not create initial @root"
              umount "$TOP" || bail "could not unmount top level after initial create"
              exit 0
            fi

            mkdir -p "$TOP/roots-archive" || bail "could not create roots-archive/"

            # ISO-8601 basic-form timestamp (colon-free, filename-safe), UTC.
            STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
            DEST="$TOP/roots-archive/$STAMP"
            # Collision guard: if two boots land in the same second, suffix.
            if [ -e "$DEST" ]; then
              DEST="$DEST.$$"
            fi

            # Atomic O(1) rename — carries nested subvolumes along intact.
            mv "$TOP/@root" "$DEST" || bail "could not archive @root -> $DEST"

            # Archive age must count from archiving, not from the root's birth:
            # mv preserves the subvolume top-dir mtime (set when activation
            # populated / at the root's creation boot, rarely advanced since),
            # and the purge's find -mmin selects on exactly that — without this
            # refresh, a root with uptime past retentionDays is archived
            # already-stale and reaped at the next purge. Same restore idiom as
            # the create failure below; the runbook's manual displacement
            # (docs/runbooks/ephemeral-root-recovery.md §Promote) carries the
            # same invariant.
            if ! touch "$DEST"; then
              mv "$DEST" "$TOP/@root" 2>/dev/null || true
              bail "could not refresh archive mtime (restored archived root)"
            fi

            # Fresh empty root. If this fails after the mv, restore the archived
            # root so the host still boots (fail-safe): mv it back into place.
            if ! btrfs subvolume create "$TOP/@root"; then
              mv "$DEST" "$TOP/@root" 2>/dev/null || true
              bail "could not create fresh @root (restored archived root)"
            fi

            umount "$TOP" || bail "could not unmount top level after rollback"
          '';
        };
      };
    })

    (lib.mkIf cfg.enable {
      # ---- 2. The normal-boot purge timer -------------------------------
      #
      # Recursively deletes archived roots older than retentionDays. Runs in
      # the booted system (not the initrd): transiently mounts the top level,
      # walks roots-archive/, and for each stale entry deletes its nested
      # subvolumes (btrfs subvolume list -o, deepest-first) then the entry
      # itself. Never touches @root — only roots-archive/ entries.
      systemd.services.ephemeral-root-purge = {
        description = "Purge archived roots older than ${toString cfg.retentionDays} days";
        onFailure = [ "notify-failure@%n.service" ];
        path = purgeTools;
        serviceConfig.Type = "oneshot";
        script = ''
          set -u
          TOP=/run/ephemeral-root-purge-toplevel
          mkdir -p "$TOP"
          cleanup() { umount "$TOP" 2>/dev/null || true; }
          trap cleanup EXIT

          mount -t btrfs -o subvolid=5 "${cfg.device}" "$TOP"
          [ -d "$TOP/roots-archive" ] || exit 0

          # Retention in minutes for find -mmin (retentionDays=0 => -mmin +0,
          # i.e. anything at least a minute old, which the retention-zero test
          # relies on to purge an aged fixture archive).
          MMIN=$(( ${toString cfg.retentionDays} * 24 * 60 ))

          # find -maxdepth 1: archive entries are the immediate children of
          # roots-archive/. -mmin +$MMIN selects the stale ones.
          find "$TOP/roots-archive" -maxdepth 1 -mindepth 1 -mmin +"$MMIN" -print0 \
          | while IFS= read -r -d "" entry; do
              # Nested subvolumes must be deleted before their parent; list
              # them (paths relative to $TOP) and delete deepest-first. -o
              # lists only subvolumes below the given path.
              btrfs subvolume list -o "$entry" 2>/dev/null \
                | awk '{print $NF}' \
                | awk '{print length, $0}' | sort -rn | cut -d" " -f2- \
                | while IFS= read -r sv; do
                    btrfs subvolume delete "$TOP/$sv" 2>/dev/null || true
                  done
              # The archive entry itself is a subvolume (the renamed @root).
              btrfs subvolume delete "$entry" 2>/dev/null \
                || rm -rf "$entry" 2>/dev/null || true
            done
        '';
      };

      systemd.timers.ephemeral-root-purge = {
        description = "Daily purge of archived roots past retention";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
      };
    })
  ];
}
