# SMART pre-failure disk-health signal (#847). Nothing on the fleet reads
# SMART data today — a drive can cross from healthy to dying between the
# rare moments someone thinks to check by hand, and the first sign is the
# box not coming back. This is a periodic oneshot (systemd timer, no
# resident smartd) that runs smartctl against every device it can find and
# exits non-zero the moment one trips a threshold the DRIVE ITSELF reports
# — never an invented number, since the fleet's currently probed drives
# already disagree on their own warning/critical temperature thresholds.
#
# smartctl (not nvme-cli) is the reader: it autodetects ATA/SAT/NVMe alike
# and emits stable JSON (--json), where nvme-cli is NVMe-only and would
# already be a dead end the day a SATA-only host (Atlas, #642) joins the
# fleet. Discovery is `smartctl --scan-open -j`, which opens each candidate
# device and performs real SAT/USB autodetection — but only its "nvme" type
# is ever propagated back as an explicit `-d nvme`. Every other device is
# simply left to the per-device call's own fresh autodetection, which is
# just as reliable as trusting the scan's type string.
#
# smartctl signals through a BITMASK exit code, not a pass/fail one, and
# several of its bits (a failed ancillary log query, drive-history/log-
# record bits) are noise, not a health verdict — a bare `if ! smartctl` is
# wrong in both directions. So the verdict here comes entirely from PARSED
# fields: the drive's own smart_status.passed, available-spare and
# temperature vs the drive's own reported thresholds, and — SATA — four
# attributes with a natural healthy floor of zero. A device only counts as
# unreadable when smart_status.passed itself fails to parse at all (the
# fail-safe direction: missing a dying drive is worse than a spurious
# alert); the exit code is consulted only then, to explain why in the
# alert body, never as the verdict itself. Error Information Log Entries /
# the ATA error log are never read at all: a healthy drive can carry
# hundreds of benign retried-command entries there (one current fleet
# drive: thousands, all one repeated benign admin-queue error), so any
# count-based gate on that field misfires on healthy hardware.
#
# "Exits non-zero on a real problem" only helps if something watches
# systemd; on a box no one logs into, a dying drive with no alert is silent
# until the box doesn't come back. So the check opts into the fleet failure
# notifier (#199) — see modules/nixos/unit-failure-notifier.nix.
{ pkgs, ... }:
let
  diskHealthCheck = pkgs.writeShellApplication {
    name = "disk-health-check";
    runtimeInputs = [
      pkgs.smartmontools
      pkgs.jq
      pkgs.coreutils # `timeout`, wrapping both smartctl invocations below.
      pkgs.systemd # `udevadm`, for the settle between scan attempts.
    ];
    text = ''
      # Discovery is best-effort: a failed or empty scan is itself
      # informative (nothing was checked, not that everything is healthy),
      # so it must never abort the script via set -e.
      #
      # Bounded with `timeout`: an unbounded smartctl can wedge on a dying
      # bus and block the whole run silently. `timeout` cannot kill a
      # process stuck in uninterruptible (D) state — it can only bound the
      # common cases (slow/hung-but-killable I/O).
      # Retried once against the actual condition: a catch-up run can reach
      # timers.target before udev has settled the device nodes, so an empty
      # first scan is not yet evidence of a diskless host (#858).
      for attempt in 1 2; do
        scan_json=$(timeout 30s smartctl --scan-open -j 2>/dev/null) || scan_json="{}"
        device_count=$(jq -r '.devices | length' <<<"$scan_json" 2>/dev/null) || device_count=0
        case "$device_count" in
          ''' | null) device_count=0 ;;
        esac
        [ "$device_count" -gt 0 ] && break
        # `udevadm settle`, not a fixed sleep: it returns as soon as the event
        # queue drains, so the wait matches reality instead of guessing it.
        # Nonzero means the timeout expired with events still pending — the
        # rescan below is then the best available answer, not a reason to abort.
        [ "$attempt" -eq 1 ] && udevadm settle --timeout 30 || true
      done

      if [ "$device_count" -eq 0 ]; then
        echo "disk-health-check: smartctl --scan-open found 0 devices — cannot confirm any drive is healthy"
        exit 1
      fi

      ok=0
      fail=0

      while IFS=$'\t' read -r path type; do
        # Only NVMe's scan type is trustworthy enough to replay (see
        # header): everything else gets no -d at all.
        devargs=()
        [ "$type" = "nvme" ] && devargs=(-d nvme)

        # `|| true`, not `|| out="{}"`: the bitmask exit code goes nonzero on
        # real health signals too (see header), and a substitution's stdout
        # is captured regardless — `|| true` only stops set -e from tripping.
        out=$(timeout 30s smartctl -a -j "''${devargs[@]}" "$path" 2>/dev/null) || true

        # jq on completely empty input still exits 0 and prints nothing, so
        # every `jq ... || fallback` below would silently pass an empty read
        # straight through unparsed instead of hitting its fallback — coerce
        # to "{}" so the unreadable branch further down is what handles it.
        [ -z "$out" ] && out="{}"

        reasons=()
        model=$(jq -r '.model_name // "unknown model"' <<<"$out" 2>/dev/null) || model="unknown model"
        serial=$(jq -r '.serial_number // "unknown serial"' <<<"$out" 2>/dev/null) || serial="unknown serial"

        # Ternary rather than a raw boolean read: distinguishes a real
        # false from a field that plain didn't parse, which the raw exit
        # code alone can't do reliably (see header).
        passed=$(jq -r 'if .smart_status.passed == true then "true" elif .smart_status.passed == false then "false" else "unknown" end' <<<"$out" 2>/dev/null) || passed="unknown"

        if [ "$passed" = "unknown" ]; then
          # No trustworthy verdict at all. The exit code and any diagnostic
          # messages are surfaced here purely to explain why — they never
          # gated this branch.
          exit_status=$(jq -r '.smartctl.exit_status // "?"' <<<"$out" 2>/dev/null) || exit_status="?"
          diag=$(jq -r '[.smartctl.messages[]?.string] | join("; ")' <<<"$out" 2>/dev/null) || diag=""
          reasons+=("unreadable (smartctl exit=$exit_status''${diag:+: $diag})")
        else
          [ "$passed" = "false" ] && reasons+=("smart_status.passed=false")

          # NVMe fields — no-op on ATA/SATA devices, which lack this key.
          if jq -e '.nvme_smart_health_information_log' <<<"$out" >/dev/null 2>&1; then
            # The spec's own purpose-built alert register: any nonzero
            # value is alert-worthy on its own terms.
            cw=$(jq -r '.nvme_smart_health_information_log.critical_warning // 0' <<<"$out")
            [ "$cw" != "0" ] && reasons+=("critical_warning=$cw")

            # The drive states its own failure point here — compared as
            # reported, never against an invented number.
            spare=$(jq -r '.nvme_smart_health_information_log.available_spare // empty' <<<"$out")
            spare_thresh=$(jq -r '.nvme_smart_health_information_log.available_spare_threshold // empty' <<<"$out")
            if [[ "$spare" =~ ^[0-9]+$ && "$spare_thresh" =~ ^[0-9]+$ ]] && [ "$spare" -le "$spare_thresh" ]; then
              reasons+=("available_spare=$spare% <= available_spare_threshold=$spare_thresh%")
            fi

            # Uncorrectable media/data errors — categorically different
            # from (never conflated with) the excluded error-log entry
            # count: this is a real correction failure, not log noise.
            media=$(jq -r '.nvme_smart_health_information_log.media_errors // 0' <<<"$out")
            [ "$media" != "0" ] && reasons+=("media_and_data_integrity_errors=$media")

            # Current temperature vs the drive's OWN critical threshold —
            # never hardcoded, and skipped (not defaulted) when the drive
            # doesn't report a threshold at all.
            temp=$(jq -r '.nvme_smart_health_information_log.temperature // empty' <<<"$out")
            crit_temp=$(jq -r '.nvme_composite_temperature_threshold.critical // empty' <<<"$out")
            if [[ "$temp" =~ ^[0-9]+$ && "$crit_temp" =~ ^[0-9]+$ ]] && [ "$temp" -ge "$crit_temp" ]; then
              reasons+=("temperature=''${temp}C >= drive's critical threshold=''${crit_temp}C")
            fi
          fi

          # SATA/ATA attributes — no-op on NVMe. Each has a natural healthy
          # floor of zero, so no bound is invented; Spin_Retry_Count is
          # HDD-only and simply absent from an SSD's table.
          if jq -e '.ata_smart_attributes.table' <<<"$out" >/dev/null 2>&1; then
            for attr in Reallocated_Sector_Ct Current_Pending_Sector Offline_Uncorrectable Spin_Retry_Count; do
              raw=$(jq -r --arg n "$attr" '.ata_smart_attributes.table[]? | select(.name == $n) | .raw.value // empty' <<<"$out")
              [ -n "$raw" ] && [ "$raw" != "0" ] && reasons+=("$attr raw=$raw")
            done
          fi
        fi

        if [ "''${#reasons[@]}" -eq 0 ]; then
          ok=$((ok + 1))
        else
          fail=$((fail + 1))
          echo "FAILING: $path ($model, S/N $serial)"
          for r in "''${reasons[@]}"; do
            echo "  - $r"
          done
        fi
      done < <(jq -r '.devices[] | [.name, .type] | @tsv' <<<"$scan_json")

      # Summary printed LAST, deliberately: the failure notifier's alert body
      # is a tail of the journal (unit-failure-notifier.nix) keeping only
      # the most RECENT lines — printing last is what survives truncation.
      echo "disk-health-check: $device_count device(s) scanned, $ok OK, $fail FAILING"

      [ "$fail" -eq 0 ]
    '';
  };
in
{
  # smartctl on PATH for hand-reading counters at the console — same binary
  # the check needs, so nearly free, and matters at break-glass (CLAUDE.md
  # §Break-glass), before any user/home-manager session exists.
  environment.systemPackages = [ pkgs.smartmontools ];

  systemd.services.disk-health-check = {
    description = "SMART pre-failure disk-health check";
    onFailure = [ "notify-failure@%n.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${diskHealthCheck}/bin/disk-health-check";
      # Backstop above the bounded phases (two 30s scan attempts plus a settle,
      # then 30s per device): bounds the unit itself if `timeout` can't reach
      # a process wedged in D state.
      TimeoutStartSec = "10m";
    };
  };

  systemd.timers.disk-health-check = {
    description = "Daily SMART pre-failure disk-health check";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true; # catch up if the host was off at OnCalendar
    };
  };

  # No persist declaration: every comparison is against a value the drive
  # reports about itself in that same run, so there is no baseline or state
  # for this module to own (contrast btrfs-scrub.nix's /var/lib/btrfs).
}
