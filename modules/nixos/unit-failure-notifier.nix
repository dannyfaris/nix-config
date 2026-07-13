# NixOS systemd unit-failure surfacing (#199). Darwin parallel: modules/darwin/launchd-failure-notifier.nix (#346).
#
# Headless hosts (mercury, nixos-vm) have no human watching
# `systemctl --failed`, so a failed nix-gc or btrfs scrub is invisible
# until something downstream breaks. This module defines a generic
# OnFailure notifier: any unit opts in with
#   systemd.services.<name>.onFailure = [ "notify-failure@%n.service" ];
# and a one-shot POSTs the failure (plus a journal tail) to the
# self-hosted ntfy instance on metis, reached over the tailnet.
#
# Transport rationale (recorded here per the repo's infra-module-comment
# convention rather than an ADR — cf. btrfs-scrub.nix, this module's
# companion, which likewise carries its "why" inline): self-hosted ntfy
# over Tailscale was chosen over email-via-relay (needs an MTA + relay
# creds = a new secret) and ntfy SaaS (a public dependency + a token)
# because the tailnet already spans every host and gives a private,
# authenticated transport for free. ntfy listens only on the Tailscale
# interface (modules/nixos/ntfy-server.nix), so tailnet membership IS the
# auth — no token/secret is introduced (#199's acceptance constraint).
# Receiver is metis: an always-on node already on the tailnet, with a
# human + an on-screen notification daemon (Noctalia) at its own console
# so the receiver's own failures aren't blind.
#
# Not covered, deliberately: sops-install-secrets. On a running host
# sops-nix installs secrets via an activation script / initrd, not a
# steady-state systemd service, so there is no unit to attach OnFailure
# to. The bootstrap OOM caveat the issue references is install-time and
# fails loudly at the interactive console (docs/runbooks/headless-bootstrap.md).
#
# Scope guard (#199): this surfaces "did a unit fail", not metrics — no
# Prometheus/node-exporter unless a metrics need is independently established.
{ config, pkgs, ... }:
let
  # The self-hosted ntfy endpoint on metis, addressed by its MagicDNS name
  # over the tailnet. One constant: every sender targets the same receiver
  # (metis reaches its own instance over the tunnel too). Moving the
  # receiver or renaming metis is a one-line edit here.
  ntfyUrl = "http://metis:8090/fleet-failures";

  notify = pkgs.writeShellApplication {
    name = "notify-unit-failure";
    runtimeInputs = [
      pkgs.curl
      pkgs.systemd
    ];
    text = ''
      unit="''${1:?usage: notify-unit-failure <unit>}"
      # A journal tail gives the alert enough context to triage without
      # SSHing in. Best-effort throughout: --max-time stops a network-down
      # failure from hanging the notifier, and the trailing `|| true` keeps
      # a failed POST from itself triggering another OnFailure cascade.
      body="$(journalctl -u "$unit" -n 20 --no-pager 2>/dev/null || echo '(journal unavailable)')"
      curl -fsS --max-time 10 \
        -H "Title: ${config.networking.hostName}: $unit failed" \
        -H "Priority: high" \
        -H "Tags: rotating_light" \
        -d "$body" \
        "${ntfyUrl}" || true
    '';
  };
in
{
  # Templated notifier. The opting-in unit's
  # `OnFailure=notify-failure@%n.service` makes `%i` the failed unit's full
  # name (e.g. nix-gc.service), which the script uses for the title and the
  # journal lookup. Use `%i`, not `%I`: `%I` path-unescapes, which mangles
  # the escaped scrub unit (btrfs-scrub--.service -> btrfs/scrub//.service);
  # `%i` hands journalctl the real unit name verbatim.
  systemd.services."notify-failure@" = {
    description = "ntfy notification that %i failed";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${notify}/bin/notify-unit-failure %i";
    };
  };

  # nix-gc runs fleet-wide (nix.gc.automatic, weekly on NixOS) and is the
  # canonical "fails silently on a headless box" unit — opt it in here
  # since it exists on every host. Per-host units (e.g. btrfs scrub on
  # metis) opt in at their own definition site.
  systemd.services.nix-gc.onFailure = [ "notify-failure@%n.service" ];
}
