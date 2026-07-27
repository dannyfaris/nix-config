# Host-specific configuration for Maia (Lenovo ThinkCentre M720q, x86_64-linux,
# bare metal) — TEMPORARY desktop incarnation.
#
# Purpose: a working niri desktop now, and a low-stakes proving ground ahead of
# the planned headless Maia (Pleiades node, docs/taxonomy.md) — it is the
# x86_64 + KVM host for the ephemeral-root VM gate (`nix build .#ephemeral-root-vm`),
# and a clean first run of the new-host sops recipient / host-key custody flow
# before that flow is relied on elsewhere. DISPOSABLE: lives on a throwaway
# feature branch, never merged to main, and gets wiped + reprovisioned as the
# planned headless Maia with ephemeral-root + LUKS (#557) once that design loop
# lands. Do not build on it as if permanent.
#
# Delta from metis (the desktop it mirrors): drops metis's fleet-infra roles
# (ntfy server #199, wiki log-host, unit-failure notifier) and the maintenance/
# dev extras (btrfs-scrub, docker); no LUKS, no @persist, persist off;
# ephemeral-root probe report-only.
#
# BOOTSTRAP PREREQUISITE — add maia to .sops.yaml and run
# `sops updatekeys secrets/secrets.yaml` BEFORE install, or first boot cannot
# decrypt `dbf-password` (neededForUsers) and there is no login hash. Under that
# failure the desktop console is NOT a break-glass: greetd, the tty gettys, and
# root (locked under `mutableUsers = false`) all need the same hash — recovery
# is live-USB only. Host key generated on the operator, injected via
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

  # Ephemeral-root PROBE only, persist + rollback off — the mutable-root
  # pre-adoption posture (probe.enable is independent of `enable`). Daily local
  # reports inventory the undeclared desktop-session tail (docs/design/
  # ephemeral-root.md §Drawbacks). The probe's ntfy/onFailure couplings to the
  # excluded metis-side modules are inert on this disposable host — branch notes.
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
    idleSuspend = true; # Mirrors metis (dev-box parity).
    # Same desktop + dev home set as metis: cli tooling, dual git identity, the
    # desktop bundle, outbound ssh, login info, agent CLIs. flakePath omitted —
    # the host-context default ("/home/dbf/nix-config") matches this host.
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
