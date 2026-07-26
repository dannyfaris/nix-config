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

  probeCfg = cfg.probe;

  # ---- Probe: build-time interpolation of the prune + ignore sets ----------
  #
  # The design's central correction: everything the probe compares against is
  # baked into the script at BUILD time from the module's own `config` view —
  # never a runtime `nix eval`, which would cost a full re-evaluation and
  # describe git HEAD rather than the running generation.

  # Prune set — the persist whitelist. Referencing config.environment.persistence
  # requires the impermanence module imported; that is a documented contract
  # (hosts import impermanence with empty declarations pre-adoption). Guarded
  # with `or` defaults so the attr access is safe when the "/persist" key or a
  # sub-list is absent. Each directory prunes its whole subtree; each file
  # prunes the exact path.
  persistRoot = config.environment.persistence."/persist" or { };
  prunedDirs = map (d: d.directory) (persistRoot.directories or [ ]);
  prunedFiles = map (f: f.file) (persistRoot.files or [ ]);

  # Ignore skeleton — config-derived at build time. /etc/<name> for each
  # managed etc entry, and the target path (2nd whitespace field) of each
  # tmpfiles rule. These are populated by activation/tmpfiles, not drift.
  etcIgnores = map (name: "/etc/${name}") (lib.attrNames config.environment.etc);
  tmpfilesPaths = lib.filter (p: p != "") (
    map (
      rule:
      let
        fields = lib.filter (s: s != "") (lib.splitString " " rule);
      in
      if lib.length fields >= 2 then lib.elemAt fields 1 else ""
    ) config.systemd.tmpfiles.rules
  );

  # Curated static ignores — pure-runtime trees no config attr enumerates.
  staticIgnores = [
    "/dev" # devtmpfs, kernel-populated
    "/proc" # procfs
    "/sys" # sysfs
    "/run" # tmpfs, per-boot
    "/tmp" # scratch, per-boot
    "/root" # root's home — populated by activation, not drift-tracked here
    "/lost+found" # fsck artifact
    "/etc/NIXOS" # NixOS marker file, activation-created
  ];

  buildTimeIgnores = lib.unique (etcIgnores ++ tmpfilesPaths ++ staticIgnores);

  # The four build-time-derived path lists, each materialised as its own store
  # file (never a heredoc: an in-source heredoc's terminator would collide with
  # Nix's indented-string dedent). Sorted + deduped for stable build output.
  writeList =
    name: xs:
    pkgs.writeText "ephemeral-root-probe-${name}" (
      lib.concatStringsSep "\n" (lib.sort (a: b: a < b) (lib.unique xs)) + "\n"
    );
  pruneDirsFile = writeList "prune-dirs" prunedDirs;
  pruneFilesFile = writeList "prune-files" prunedFiles;
  ignoresFile = writeList "ignores" buildTimeIgnores;
  extraGlobsFile = writeList "extra-globs" probeCfg.extraIgnorePatterns;

  probeTools = [
    pkgs.coreutils
    pkgs.findutils
    pkgs.gawk
    pkgs.gnugrep
    pkgs.util-linux
    pkgs.btrfs-progs
    pkgs.curl
  ];

  # State dir (StateDirectory=ephemeral-root-probe -> /var/lib/ephemeral-root-probe).
  stateDir = "/var/lib/ephemeral-root-probe";

  # One script, parameterized `live` | `archive`, shared by both services.
  probe = pkgs.writeShellApplication {
    name = "ephemeral-root-probe";
    runtimeInputs = probeTools;
    text = ''
      # $1 = mode: "live" (scan the running root subvolume) | "archive"
      # (transiently mount subvolid=5 and scan the newest un-scanned archive).
      mode="''${1:?usage: ephemeral-root-probe <live|archive>}"

      STATE=${stateDir}
      SEEN="$STATE/seen"
      MARKER="$STATE/last-scanned-archive"
      NTFY=${lib.escapeShellArg probeCfg.ntfyUrl}
      HOST=${lib.escapeShellArg config.networking.hostName}
      DEGRADED=${degradedMarker}
      # Archive scan's OWN transient mountpoint — never the purge's, so the two
      # can never race over a shared mount.
      ARCHTOP=/run/ephemeral-root-probe-toplevel
      DEVICE=${lib.escapeShellArg cfg.device}

      mkdir -p "$STATE"
      touch "$SEEN"

      # Prune set (persist whitelist) and ignore skeleton, baked at build time
      # into store files (paths interpolated here). Directory prunes match the
      # path and its whole subtree; file prunes and ignores match the exact path.
      PRUNE_DIRS=${pruneDirsFile}
      PRUNE_FILES=${pruneFilesFile}
      IGNORES=${ignoresFile}
      EXTRA_GLOBS=${extraGlobsFile}

      # Is $1 pruned/ignored? A path is dropped if it (or an ancestor) is a
      # pruned directory or a build-time ignore, if it equals a pruned/ignored
      # file, if it is a symlink resolving into /nix/store, or if it matches an
      # extraIgnorePatterns glob (shell `case`, which is glob-capable — literal
      # deltas cannot follow random-suffixed leaf names).
      is_kept() {
        local p="$1" d g target
        # Directory-subtree prunes + build-time ignores (prefix match at a path
        # boundary: exact, or the entry followed by "/").
        while IFS= read -r d; do
          [ -n "$d" ] || continue
          case "$p" in
            "$d" | "$d"/*) return 0 ;;
          esac
        done < <(cat "$PRUNE_DIRS" "$IGNORES")
        # Exact-path file prunes.
        while IFS= read -r d; do
          [ -n "$d" ] || continue
          [ "$p" = "$d" ] && return 0
        done < "$PRUNE_FILES"
        # extraIgnorePatterns as globs.
        while IFS= read -r g; do
          [ -n "$g" ] || continue
          # shellcheck disable=SC2254  # $g is intentionally a glob pattern
          case "$p" in
            $g) return 0 ;;
          esac
        done < "$EXTRA_GLOBS"
        # Store symlinks: activation litters / with symlinks into /nix/store;
        # those are closure, not drift.
        if [ -L "$root_prefix$p" ]; then
          target=$(readlink -f "$root_prefix$p" 2>/dev/null || true)
          case "$target" in
            /nix/store/*) return 0 ;;
          esac
        fi
        return 1
      }

      # Depth-limited rollup (depth 3) of a path list: aggregate to the first 3
      # components with a per-dir count — the ntfy body, kept small.
      rollup() {
        awk -F/ '{
          n = (NF > 4) ? 4 : NF
          key = ""
          for (i = 2; i <= n; i++) key = key "/" $i
          if (key == "") key = "/"
          c[key]++
        }
        END { for (k in c) printf "%s (%d)\n", k, c[k] }' | sort
      }

      # Post a delta rollup to the quiet ntfy topic, plain priority. Returns
      # curl's status: a FAILED post must not advance the seen-set (the delta
      # would be lost silently), so the caller gates the seen-set append on it.
      post_delta() {
        local title="$1" body="$2"
        curl -fsS --max-time 10 \
          -H "Title: $HOST: $title" \
          -H "Priority: default" \
          -H "Tags: mag" \
          -d "$body" \
          "$NTFY"
      }

      ts=$(date -u +%Y%m%dT%H%M%SZ)

      if [ "$mode" = "live" ]; then
        # Scan the live root subvolume. -xdev keeps find on the root device:
        # /nix, /home, /persist, tmpfs and other subvolume mounts self-exclude
        # (different st_dev); nested subvolumes under / (e.g. /var/lib/machines)
        # also self-exclude, acceptable per the design.
        root_prefix=""
        # `|| true`: find hits permission-denied dirs and exits nonzero, which
        # under the wrapper's pipefail+errexit would abort the whole probe.
        candidates=$( { find / -xdev 2>/dev/null || true; } | sort)
        report="$STATE/report-live-$ts"
        report_title="live-root drift"

      elif [ "$mode" = "archive" ]; then
        # A degraded boot created NO new archive; scanning the newest would
        # mislabel an older cycle. Post the degraded event and skip the scan.
        if [ -e "$DEGRADED" ]; then
          post_delta "ephemeral-root DEGRADED boot" \
            "initrd rollback bailed this boot; archive scan skipped ($(cat "$DEGRADED" 2>/dev/null || echo unknown))" || true
          exit 0
        fi
        mkdir -p "$ARCHTOP"
        cleanup() { umount "$ARCHTOP" 2>/dev/null || true; }
        trap cleanup EXIT
        mount -t btrfs -o subvolid=5 "$DEVICE" "$ARCHTOP"
        if [ ! -d "$ARCHTOP/roots-archive" ]; then
          exit 0
        fi
        newest=$( { find "$ARCHTOP/roots-archive" -maxdepth 1 -mindepth 1 -printf '%f\n' 2>/dev/null || true; } | sort | tail -n1)
        [ -n "$newest" ] || exit 0
        # Already scanned? The marker records the last archive we recorded.
        if [ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "$newest" ]; then
          exit 0
        fi
        root_prefix="$ARCHTOP/roots-archive/$newest"
        # Candidate paths are the archive's contents, re-rooted to / so the
        # prune/ignore sets (which are absolute /-paths) match. -xdev keeps the
        # scan on the archived subvolume. `|| true` for the same errexit reason
        # as the live scan; grep -v drops the empty leading line from the sed.
        candidates=$( { find "$root_prefix" -xdev 2>/dev/null || true; } \
          | sed "s#^$root_prefix##" | { grep -v '^$' || true; } | sort)
        report="$STATE/report-archive-$ts-$newest"
        report_title="archive drift ($newest)"
      else
        echo "unknown mode: $mode" >&2
        exit 2
      fi

      # Candidate paths minus ignores minus prune set = drift candidates.
      : > "$report"
      while IFS= read -r p; do
        [ -n "$p" ] || continue
        [ "$p" = "/" ] && continue
        if is_kept "$p"; then continue; fi
        printf '%s\n' "$p" >> "$report"
      done <<< "$candidates"

      # The full listing is ALWAYS written locally, regardless of the seen-set
      # or the post outcome. Delta = report minus the shared seen-set (live and
      # archive share one seen-set, so the archive posts only what live never
      # saw). comm needs sorted inputs; both are sorted.
      sort -u -o "$report" "$report"
      delta=$(comm -23 "$report" "$SEEN" || true)

      if [ -z "$delta" ]; then
        # Empty delta — nothing new. Post an explicit empty-delta note so a
        # repeated run is observable (the seen-set biting), then stop.
        post_delta "$report_title (no new drift)" "no new undeclared paths" || true
        exit 0
      fi

      body=$(printf '%s\n' "$delta" | rollup)
      if post_delta "$report_title" "$body"; then
        # Only on a SUCCESSFUL post do we record the delta as seen — a failed
        # post must not lose it. Merge and re-sort the seen-set.
        printf '%s\n' "$delta" | sort -u - "$SEEN" -o "$SEEN"
        # Archive mode: advance the last-scanned marker only after a good post.
        if [ "$mode" = "archive" ]; then
          printf '%s' "$newest" > "$MARKER"
        fi
      else
        # Post failed: the unit fails so notify-failure fires on the failure
        # topic, and the delta stays un-seen for the next run to retry.
        echo "ephemeral-root-probe: post to ntfy failed; delta not recorded" >&2
        exit 1
      fi
    '';
  };
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

    # The drift-detection probe (#633). INDEPENDENT of `enable`: the live scan
    # is the pre-adoption retrofit inventory (runs report-only while the root
    # is still mutable to seed the whitelist), the archive scan is the
    # post-adoption ground-truth confirmation. So `probe.enable` gates the
    # live half on its own; the archive half additionally needs `enable`.
    probe = {
      enable = lib.mkEnableOption "drift-detection probe: report undeclared state on / against the persist whitelist";

      extraIgnorePatterns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Glob patterns (shell `case` semantics) suppressing hand-tuned
          residue the config-derived ignore skeleton cannot name — pure-runtime
          trees whose leaf names are random-suffixed, which literal-path deltas
          would report forever. Applied on top of the build-time ignore set.
        '';
        example = [ "/var/cache/*" ];
      };

      ntfyUrl = lib.mkOption {
        type = lib.types.str;
        # The QUIET second topic on the existing self-hosted ntfy — drift
        # reports on the high-priority fleet-failures topic would train alert
        # fatigue. The option is the test seam (point at a local sink so posts
        # succeed) and the receiver-relocation point (one-line move here).
        default = "http://metis:8090/fleet-state";
        description = "ntfy topic the probe posts drift rollups to (quiet, non-failure channel).";
      };
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

    # ---- 3. The drift-detection probe (#633) ---------------------------
    #
    # Live half: gated on probe.enable ALONE (the retrofit inventory runs
    # while the root is still mutable). Daily timer, so a drifted path is
    # reported while still alive — whitelistable before the next reboot loses
    # it. Mirrors the purge timer's OnCalendar/Persistent shape.
    (lib.mkIf probeCfg.enable {
      systemd.services.ephemeral-root-probe-live = {
        description = "Scan the live root for state undeclared on the persist whitelist";
        onFailure = [ "notify-failure@%n.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${probe}/bin/ephemeral-root-probe live";
          # /var/lib/ephemeral-root-probe: seen-set, last-scanned marker, reports.
          StateDirectory = "ephemeral-root-probe";
        };
      };

      systemd.timers.ephemeral-root-probe-live = {
        description = "Daily live-root drift scan";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
      };
    })

    # Archive half: additionally needs `enable` — archives only exist once the
    # rollback runs. Once per boot (after multi-user), scans the newest archive
    # not yet recorded in the marker, then records it — ground-truth of what
    # the whitelist actually missed on the just-wiped cycle.
    (lib.mkIf (cfg.enable && probeCfg.enable) {
      systemd.services.ephemeral-root-probe-archive = {
        description = "Scan the newest archived root for undeclared state";
        onFailure = [ "notify-failure@%n.service" ];
        wantedBy = [ "multi-user.target" ];
        after = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${probe}/bin/ephemeral-root-probe archive";
          StateDirectory = "ephemeral-root-probe";
        };
      };

      # Module-owns-its-state, applied to the probe itself: its seen-set +
      # marker + reports must outlive the reboot the mechanism enforces, or
      # every boot would re-post the whole delta. Pre-adoption (enable=false)
      # this mkIf is off and the state just lives on the mutable root.
      environment.persistence."/persist".directories = [ stateDir ];
    })
  ];
}
