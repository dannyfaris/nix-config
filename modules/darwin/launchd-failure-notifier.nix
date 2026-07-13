# launchd job-failure surfacing for Darwin hosts (#346). Darwin parallel to
# modules/nixos/unit-failure-notifier.nix — share its transport rationale
# (self-hosted ntfy over Tailscale, recorded there per the infra-module
# convention). This module is Darwin-specific: launchd has no `OnFailure=`
# hook, so failure detection is a periodic polling inspector rather than a
# per-job trigger.
#
# Mechanic: a launchd system daemon runs every 10 minutes (StartInterval 600)
# and inspects every config-managed launchd job. It runs as root so it can
# read both the `system` domain (org.nixos.* daemons) and the operator's
# `gui/501` domain (org.nixos.* user agents and org.nix-community.home.*
# home-manager agents). Failure is detected via `launchctl print` output:
#   state = "not running" AND last exit code != 0
# A KeepAlive job that crashes-and-restarts shows state = "running" even
# when its last exit was non-zero, so it does NOT trigger a notification —
# only a job that has exited and stayed down is flagged.
#
# Enumeration is the union of the DECLARED set (org.nixos.*.plist under
# /Library/LaunchDaemons; org.nixos.* and org.nix-community.home.* plists
# under the operator's ~/Library/LaunchAgents) and the runtime `launchctl
# list`. The declared side is load-bearing: nix-darwin activates via legacy
# `launchctl load`, which exits 0 even when the load is rejected, so a
# rejected job never appears in the runtime list — a declared-but-unlisted
# label is flagged via the "unloaded" branch (launchctl print exit 113).
#
# Dedup contract: /var/lib/launchd-failure-notifier/<label> holds the last
# failure identity (exit:<code> or "unloaded") for which a notification was
# DELIVERED — state is written only on curl success, so a tailnet-down POST
# retries every poll until it lands. The notifier re-arms (deletes the state
# file) when the job returns to healthy (state = running, or state = not
# running + exit 0), and prunes state for labels no longer in the checked
# set (job removed from config). Net: a persistently-failed job notifies
# once per failure identity, not every poll.
#
# Scope guard: inspects only labels starting with "org.nixos." (nix-darwin
# system daemons + user agents) and "org.nix-community.home." (home-manager
# agents). Platform-Apple and third-party labels are not our problem.
# Self-coverage: this daemon's own label is in the checked set; dedup
# bounds any self-report to a single notification.
#
# Neptune-only: saturn is a roaming laptop, asleep half the time; the
# polling inspector has no meaningful signal there. Import by the host file;
# do not add to foundation.
#
# Limitation: if the tailnet is down the POST fails and no dedup state is
# written, so the alert retries each poll until delivered. The notifier
# cannot report its own death; #569's dead-man's layer is the answer there.
{ config, pkgs, ... }:
let
  ntfyUrl = "http://metis:8090/fleet-failures";

  operator = import ../../lib/operator.nix;

  # Operator UID for the gui domain. Neptune assigns UID 501 to the first
  # macOS user (verified against `id -u dbf`); the host file asserts
  # `users.users.dbf.uid = 501` for nix-darwin's tracking.
  operatorUid = toString config.users.users.${operator.name}.uid;

  # Where nix-darwin's user agents and home-manager's agents install their
  # plists — root-readable; launchd itself loads gui agents from here.
  operatorAgentsDir = "${operator.darwinHome}/Library/LaunchAgents";

  inspector = pkgs.writeShellApplication {
    name = "launchd-failure-inspector";
    runtimeInputs = [
      pkgs.curl
    ];
    text = ''
      STATE_DIR="/var/lib/launchd-failure-notifier"
      HOST="${config.networking.hostName}"

      # Inspect one label. Domain is "system" for daemons, "gui/UID" for agents.
      check_label() {
        local domain="$1"
        local label="$2"
        local state_file="$STATE_DIR/$label"

        local print_out
        # launchctl print exits 113 if the job is not loaded at all — reached
        # for a declared plist whose (legacy, exit-0) load was rejected.
        if ! print_out="$(launchctl print "$domain/$label" 2>&1)"; then
          local current="unloaded"
          local body="launchctl print $domain/$label failed (job not loaded or ejected)"
          send_if_new "$label" "$current" "$body"
          return
        fi

        local state code
        state="$(printf '%s' "$print_out" | awk '/^\tstate = / { sub(/^\tstate = /, ""); print; exit }')"
        code="$(printf '%s' "$print_out" | awk '/^\tlast exit code = / { sub(/^\tlast exit code = /, ""); print; exit }')"

        if [ "$state" = "not running" ] \
          && [ -n "$code" ] \
          && [ "$code" != "0" ] \
          && [ "$code" != "(never exited)" ]; then
          # Job exited with an error and did not restart — this is a failure.
          local current="exit:$code"
          # Best-effort log tail from the job's stderr path if one is set.
          local stderr_path
          stderr_path="$(printf '%s' "$print_out" | awk '/^\tstderr path = / { sub(/^\tstderr path = /, ""); print; exit }')"
          local body="state: $state | last exit code: $code"
          if [ -n "$stderr_path" ] && [ -r "$stderr_path" ]; then
            body="$body"$'\n'"$(tail -n 20 "$stderr_path" 2>/dev/null || true)"
          fi
          send_if_new "$label" "$current" "$body"
        else
          # Job is healthy — re-arm by removing any prior failure state file.
          rm -f "$state_file"
        fi
      }

      # Post to ntfy only if this failure identity is new (dedup by label + code).
      send_if_new() {
        local label="$1" current="$2" body="$3"
        local state_file="$STATE_DIR/$label"
        local last
        last="$(cat "$state_file" 2>/dev/null || true)"
        if [ "$last" = "$current" ]; then
          return  # already notified for this failure identity; stay quiet
        fi
        # Record delivery only on POST success — a failed POST (tailnet down)
        # leaves state unwritten so the alert retries next poll.
        if curl -fsS --max-time 10 \
          -H "Title: $HOST: $label failed" \
          -H "Priority: high" \
          -H "Tags: rotating_light" \
          -d "$body" \
          "${ntfyUrl}"; then
          printf '%s' "$current" > "$state_file"
        fi
      }

      # Checked set = declared plists on disk + runtime-loaded labels, prefix-
      # filtered to config ownership (org.nixos., org.nix-community.home.).
      # The declared side catches jobs whose legacy `launchctl load` was
      # rejected (it exits 0 on rejection — they never reach `launchctl list`).
      system_labels="$(
        {
          for f in /Library/LaunchDaemons/org.nixos.*.plist; do
            [ -e "$f" ] || continue
            basename -s .plist "$f"
          done
          launchctl list 2>/dev/null | awk 'NR>1 && $3 ~ /^org\.nixos\./ { print $3 }' || true
        } | sort -u
      )"

      # Root reads the operator's gui domain and LaunchAgents dir directly;
      # `asuser` targets the gui session's launchd for the list call.
      gui_labels="$(
        {
          for f in ${operatorAgentsDir}/org.nixos.*.plist ${operatorAgentsDir}/org.nix-community.home.*.plist; do
            [ -e "$f" ] || continue
            basename -s .plist "$f"
          done
          launchctl asuser ${operatorUid} launchctl list 2>/dev/null \
            | awk 'NR>1 && ($3 ~ /^org\.nixos\./ || $3 ~ /^org\.nix-community\.home\./) { print $3 }' || true
        } | sort -u
      )"

      while IFS= read -r label; do
        [ -n "$label" ] || continue
        check_label "system" "$label"
      done <<<"$system_labels"

      while IFS= read -r label; do
        [ -n "$label" ] || continue
        check_label "gui/${operatorUid}" "$label"
      done <<<"$gui_labels"

      # State hygiene: prune dedup state for labels no longer in the checked
      # set — a job removed from the config must not leave state behind.
      for state_file in "$STATE_DIR"/*; do
        [ -e "$state_file" ] || continue
        label="$(basename "$state_file")"
        if ! printf '%s\n%s\n' "$system_labels" "$gui_labels" | grep -qxF "$label"; then
          rm -f "$state_file"
        fi
      done
    '';
  };
in
{
  # Ensure the state directory exists before the daemon starts.
  system.activationScripts.preActivation.text = ''
    mkdir -p /var/lib/launchd-failure-notifier
  '';

  # Periodic inspector: every 10 minutes. Runs as root (system daemon) so it
  # can inspect both the system domain and the operator's gui domain. No log
  # paths: the daemon is near-silent and failures surface via ntfy.
  launchd.daemons.launchd-failure-notifier = {
    serviceConfig = {
      Label = "org.nixos.launchd-failure-notifier";
      ProgramArguments = [
        "${inspector}/bin/launchd-failure-inspector"
      ];
      StartInterval = 600;
    };
  };
}
