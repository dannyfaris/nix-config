# Host-specific configuration for Maia (Lenovo ThinkCentre M720q, x86_64-linux,
# bare metal) — TEMPORARY desktop incarnation.
#
# Stood up while metis is being recovered (#553 incident) to: give a working
# niri desktop now, serve as the x86_64-linux + KVM host for the ephemeral-root
# VM gate (`nix build .#ephemeral-root-vm`) that metis normally runs, and
# rehearse the sops host-key custody flow whose failure locked metis out. This
# config is DISPOSABLE — it lives on a throwaway feature branch, is never merged
# to main, and gets wiped + reprovisioned as the PLANNED headless Maia (Pleiades
# node, docs/taxonomy.md) with ephemeral-root + LUKS (#557) once that design
# loop lands. Do not build on it as if permanent.
#
# Delta from metis (the desktop it mirrors): drops metis's fleet-infra roles
# (ntfy server #199, wiki log-host, unit-failure notifier) and the maintenance/
# dev extras (btrfs-scrub, docker); no LUKS, no @persist, persist off.
#
# BOOTSTRAP PREREQUISITE (the sops rehearsal): Maia is not yet a recipient in
# .sops.yaml. Before install, add its host-key age pubkey and run
# `sops updatekeys secrets/secrets.yaml`, or first boot cannot decrypt
# `dbf-password` (neededForUsers) and login is rejected — the exact metis
# failure class. Host key generated on the operator and injected via
# --extra-files (ADR-022). Runbook: docs/runbooks/headless-bootstrap.md.
{ inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    inputs.disko.nixosModules.disko

    # Foundation — bundle every NixOS host imports by convention.
    ../../modules/nixos/foundation.nix

    # Capability bundles.
    ../../modules/nixos/bundles/remote-access.nix
    ../../modules/nixos/bundles/desktop-env.nix

    # Standalone system modules.
    ../../modules/nixos/boot-systemd.nix
    ../../modules/nixos/networking-networkmanager.nix
    ../../modules/nixos/tailscale.nix
    ../../modules/nixos/ephemeral-root.nix # Probe report-only (persist off) — see ephemeralRoot below.
  ];

  networking.hostName = "maia";

  # Ephemeral-root PROBE only — persist off, rollback off: the mutable-root
  # pre-adoption posture the module is built for (probe.enable is independent of
  # `enable`; with enable=false the probe's seen-set lives on the mutable root).
  # The daily live scan's LOCAL reports inventory this host's undeclared state —
  # here the desktop-session tail no prior art enumerates (docs/design/
  # ephemeral-root.md §Drawbacks) — sparing metis that discovery cost.
  #
  # KNOWN COUPLINGS while metis is down (both inert, neither fatal; flagged for
  # review): the probe posts rollups to metis's ntfy (`probe.ntfyUrl` default)
  # and its `onFailure` targets notify-failure@ from the EXCLUDED
  # unit-failure-notifier — so a failed daily run logs "unit not found" and the
  # post retries without advancing the seen-set (no data lost). The local report
  # under /var/lib/ephemeral-root-probe is written regardless — that is the value.
  ephemeralRoot = {
    device = "/dev/disk/by-label/nixos";
    probe.enable = true;
  };

  # Set once at install; never change, even after upgrading.
  system.stateVersion = "25.11";

  # Defensive — kept even though disko's btrfs module also pulls btrfs into the
  # initrd. Matches nixos-generate-config and survives future refactors.
  boot.supportedFilesystems = [ "btrfs" ];

  # zram-only swap — no disk swap (no hibernate; zero SSD wear).
  zramSwap.enable = true;
  swapDevices = [ ];

  # systemd-oomd: kill the heaviest user.slice descendant under memory pressure;
  # system/root slices excluded so it can't kill sshd (LAN-SSH break-glass).
  systemd.oomd.enableUserSlices = true;

  hostContext = {
    hostName = "maia";
    # Off, unlike metis: Maia doubles as a local build + VM-test host, so an
    # unattended `nix build` / ephemeral-root VM run must not be suspended
    # mid-flight. (The guard skips on SSH/agent activity, but a local build is
    # not activity by that guard's definition.)
    idleSuspend = false;
    # Same desktop + dev home set as metis (mirrors its dev-box parity: cli
    # tooling, dual git identity, the desktop bundle, outbound ssh, login info,
    # agent CLIs). flakePath omitted — the host-context default
    # ("/home/dbf/nix-config") matches this host.
    extraHomeModules = [
      ../../home/shared/bundles/cli-tooling.nix
      ../../home/shared/bundles/git-multi-identity.nix
      ../../home/nixos/bundles/desktop-env.nix
      ../../home/shared/ssh.nix
      ../../home/shared/macchina.nix
      ../../home/nixos/macchina-shell-init.nix
      ../../home/shared/agent-clis.nix
      ../../home/shared/agent-clis-extras.nix
    ];
  };
}
