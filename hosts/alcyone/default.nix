# Host-specific configuration for Alcyone (Gigabyte B550 GAMING X V2,
# Ryzen 7 5700X, RTX 4060, x86_64-linux, bare metal). ADR-045 star name;
# main-homelab Pleiades group (taxonomy.md). The fleet's flagship desktop
# and its first discrete GPU + first encrypted-at-rest host (#631).
#
# Composes foundation + capability bundles + standalone modules directly
# (ADR-027). Personal-only dev box: single personal git identity + full
# agent-CLI set. Mirrors metis's desktop composition MINUS its log-host
# roles (wiki-pipeline, ntfy-server — the latter now on electra, #688) and
# PLUS the NVIDIA GPU module.
#
# Bootstrap via nixos-anywhere + disko (ADR-022); three-file host
# structure (ADR-023). Host key pre-generated on the operator
# (`just gen-host-key alcyone`) and injected at install; secrets are
# sops-nix. Runbook: docs/runbooks/headless-bootstrap.md.
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
    ../../modules/nixos/docker.nix # Rootless Docker — see ADR-021.
    ../../modules/nixos/btrfs-scrub.nix # Periodic checksum verification on btrfs subvolumes (monthly default).
    ../../modules/nixos/unit-failure-notifier.nix # Fan systemd unit failures to ntfy over the tailnet (#199) — client only; alcyone runs no ntfy server.
    ../../modules/nixos/nvidia.nix # RTX 4060 (Ada) — open kernel module + proprietary userspace. Alcyone-only; never the shared desktop-env bundle (metis is Intel iGPU).
    ../../modules/nixos/wake-on-lan-target.nix # Arm WoL on enp5s0 (target side, #632) — interface set via wakeOnLan.interfaces below. Emitter lives on electra.
    ../../modules/nixos/ephemeral-root.nix # Enforced from first boot — see ephemeralRoot below; docs/design/ephemeral-root.md.
    ../../modules/nixos/persist-os-core.nix # OS-core persist whitelist (machine-id, /var/lib/nixos, systemd timers/coredump, /var/log, /var/db/sudo, /root).
  ];

  networking.hostName = "alcyone";

  # Arm Wake-on-LAN on the wired NIC (target side, #632). enp5s0 verified
  # on-metal; wakes from a broadcast magic packet emitted by always-on
  # electra (same /24). Firmware WoL/S3 dependency is out of Nix's control
  # — see modules/nixos/wake-on-lan-target.nix header. This arms the OS
  # side only; end-to-end wake from idle-suspend is proven under #691.
  wakeOnLan.interfaces = [ "enp5s0" ];

  # Set once at install; never change, even after upgrading. 26.11 = the
  # release Alcyone installs against (system.nixos.release); greenfield box,
  # so no legacy state to strand. Per-host install-era marker, not a
  # fleet-wide constant — metis stays 25.11 (its own install era).
  system.stateVersion = "26.11";

  # systemd initrd — required for the TPM2 LUKS auto-unseal declared in
  # disko.nix (`crypttabExtraOpts = tpm2-device=auto`): only the systemd
  # stage-1 supports TPM2 unlocking. See disko.nix header (#631 / #557).
  # Also a hard requirement of the ephemeral-root initrd rollback below.
  boot.initrd.systemd.enable = true;

  # Ephemeral root ENFORCED from first boot (adoption decision 2026-07-31,
  # beyond #631's probe-only scoping): greenfield host, no legacy state to
  # inventory, whitelist already seeded fleet-wide by owning modules and
  # metis-proven since 2026-07-30. Every boot archives @root (30-day
  # retention, purged daily) and boots a fresh empty root; only the persist
  # whitelist survives, /home and /nix untouched. The probe runs both
  # halves — daily live scan and per-boot archive scan. Recovery:
  # docs/runbooks/ephemeral-root-recovery.md; one-boot kill-switch:
  # ephemeral.skip-rollback on the kernel cmdline at the systemd-boot menu.
  ephemeralRoot = {
    enable = true;
    # The LUKS-mapped device, matching the root fileSystems entry disko
    # generates — the btrfs top level lives INSIDE the container, so the
    # initrd can only mount it post-unlock (unlike metis's bare
    # by-partlabel). Ordering after initrd-root-device.target implies the
    # cryptsetup unlock has completed and the mapper node exists.
    device = "/dev/mapper/cryptroot";
    probe.enable = true;
  };

  # Persist whitelist active from first boot: @persist exists from the
  # disko format (no metis-style online retrofit), so the neededForBoot
  # mount and the owning-module bind mounts are all greenfield-empty and
  # populate naturally. Host key lands in /persist/etc/ssh at install
  # (runbook §persist hosts); machine-id seeds itself via the stage-2
  # oneshot in ephemeral-root.nix.
  persist.enable = true;
  fileSystems."/persist".neededForBoot = true;

  # Defensive — kept deliberately even though disko's btrfs module also
  # pulls btrfs into the initrd. Matches what nixos-generate-config emits
  # and survives future refactors. Do NOT strip as redundant.
  boot.supportedFilesystems = [ "btrfs" ];

  # zram-only swap — 50 % of RAM, zstd compression, appropriate for
  # 32 GiB. No disk swap (no hibernate; and disk swap outside the LUKS
  # container would leak plaintext memory pages past encryption-at-rest).
  zramSwap.enable = true;
  swapDevices = [ ];

  # systemd-oomd: kills the heaviest descendant in user.slice at 80 %
  # memory-pressure. Docker builds + agent CLIs can saturate zram on
  # 32 GiB; system/root slices excluded so oomd can't kill sshd
  # (break-glass via LAN SSH). Mirrors metis.
  systemd.oomd.enableUserSlices = true;

  # Per-host parametrisation consumed by home-manager modules (ADR-019).
  # extraHomeModules is the full HM imports list — capability bundles plus
  # standalone modules (ADR-027). Personal-only dev box: cli tooling +
  # single personal git identity + GitHub CLI + desktop-env + login info
  # display + base agent CLIs + agent-CLI extras + outbound SSH.
  #
  # flakePath omitted — the host-context default ("/home/dbf/nix-config")
  # matches this host.
  hostContext = {
    hostName = "alcyone";
    # Guarded idle→suspend (Noctalia, home/nixos/noctalia.nix) — #631 Power
    # scope; the nvidia powerManagement hooks make the sleep cycle safe.
    idleSuspend = true;
    extraHomeModules = [
      ../../home/shared/bundles/cli-tooling.nix
      # Personal-only identity: base git + single personal identity +
      # GitHub CLI, imported individually (no git-multi-identity bundle —
      # that carries the work identity this host deliberately omits).
      ../../home/shared/git.nix
      ../../home/shared/git-identity.nix
      ../../home/shared/gh.nix
      ../../home/nixos/bundles/desktop-env.nix
      ../../home/shared/ssh.nix
      ../../home/shared/macchina.nix
      ../../home/nixos/macchina-shell-init.nix
      ../../home/shared/agent-clis.nix
      ../../home/shared/agent-clis-extras.nix
    ];
  };
}
