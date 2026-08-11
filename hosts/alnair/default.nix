# Host-specific configuration for Alnair (Surface Laptop 4 15″ Intel 1978,
# i7-1185G7 Tiger Lake, Iris Xe, 16 GiB, 256 GB NVMe, x86_64-linux, bare
# metal). ADR-045 star name — a Portable / unattached star in the roster.
# The fleet's FIRST Linux laptop (#636): first built-in HiDPI panel, first
# NixOS-side mobility cluster, and the strongest theft case (roaming).
#
# Composes foundation + capability bundles + standalone modules directly
# (ADR-027). Personal-only dev box: single personal git identity + full
# agent-CLI set. Mirrors Alcyone's desktop composition MINUS its discrete
# GPU (Iris Xe needs no nvidia.nix) and MINUS docker.nix (out of #636
# scope), PLUS the Surface silicon and mobility clusters.
#
# Bootstrap via nixos-anywhere + disko (ADR-022); three-file host
# structure (ADR-023). Host key pre-generated on the operator
# (`just gen-host-key alnair`) and injected at install; secrets are
# sops-nix. Runbook: docs/runbooks/headless-bootstrap.md.
{ inputs, lib, ... }:
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
    ../../modules/nixos/bundles/mobility.nix # Fleet's first NixOS laptop cluster — suspend/lid/backlight/power posture (#636) plus roaming-identity privacy (#753, #754).

    # Standalone system modules.
    ../../modules/nixos/boot-systemd.nix
    ../../modules/nixos/networking-networkmanager.nix
    ../../modules/nixos/tailscale.nix
    ../../modules/nixos/claude-desktop.nix # Claude Desktop for Linux, Phase 1 (Chat + Claude Code); Cowork deferred upstream (#683).
    ../../modules/nixos/btrfs-scrub.nix # Periodic checksum verification on btrfs subvolumes (monthly default).
    ../../modules/nixos/unit-failure-notifier.nix # Fan systemd unit failures to ntfy over the tailnet (#199) — client only; alnair runs no ntfy server.
    ../../modules/nixos/surface.nix # Surface silicon — SAM chain (initrd + runtime), Iris Xe graphics, webcam device access. Alnair-only host-scoped hardware, never a shared bundle (#636).
    ../../modules/nixos/ephemeral-root.nix # Enforced from first boot — see ephemeralRoot below; docs/design/ephemeral-root.md.
    ../../modules/nixos/persist-os-core.nix # OS-core persist whitelist (machine-id, /var/lib/nixos, systemd timers/coredump, /var/log, /var/db/sudo, /root).
  ];

  networking.hostName = "alnair";

  # Set once at install; never change, even after upgrading. 26.11 = the
  # release Alnair installs against (system.nixos.release); greenfield box,
  # so no legacy state to strand. Per-host install-era marker, not a
  # fleet-wide constant — metis stays 25.11 (its own install era).
  system.stateVersion = "26.11";

  # systemd initrd — required for the TPM2 LUKS auto-unseal declared in
  # disko.nix (`crypttabExtraOpts = tpm2-device=auto`): only the systemd
  # stage-1 supports TPM2 unlocking. See disko.nix header (#636 / #557).
  # Also a hard requirement of the ephemeral-root initrd rollback below.
  boot.initrd.systemd.enable = true;

  # Ephemeral root ENFORCED from first boot (#636 decision log): greenfield
  # host, no legacy state to inventory, whitelist already seeded fleet-wide
  # by owning modules and metis-proven. Every boot archives @root (30-day
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
  # 16 GiB. No disk swap (no hibernate; and disk swap outside the LUKS
  # container would leak plaintext memory pages past encryption-at-rest).
  zramSwap.enable = true;
  swapDevices = [ ];

  # systemd-oomd: kills the heaviest descendant in user.slice at 80 %
  # memory-pressure. Agent CLIs can saturate zram on 16 GiB; system/root
  # slices excluded so oomd can't kill sshd — break-glass on a laptop is
  # the physical console / greetd login.
  systemd.oomd.enableUserSlices = true;

  # Roaming SSH posture (#636 Option B): sshd runs fleet-hardened via
  # remote-access, but port 22 is never opened on the physical NIC —
  # inbound rides the tailnet only (tailscale.nix trustedInterfaces +
  # ts-input). mkForce because sshd.nix sets openFirewall = true without
  # mkDefault. Declared != enforced (#336): the #636 runtime probe (nc
  # from an untrusted network) gates install sign-off, not this line.
  services.openssh.openFirewall = lib.mkForce false;

  # Per-host parametrisation consumed by home-manager modules (ADR-019).
  # extraHomeModules is the full HM imports list — capability bundles plus
  # standalone modules (ADR-027). Personal-only dev box: cli tooling +
  # single personal git identity + GitHub CLI + desktop-env + laptop niri
  # fragment + login info display + base agent CLIs + agent-CLI extras +
  # outbound SSH.
  #
  # flakePath omitted — the host-context default ("/home/dbf/nix-config")
  # matches this host.
  hostContext = {
    hostName = "alnair";
    # Guarded idle→suspend (Noctalia, home/nixos/noctalia.nix) — natural
    # for a laptop (#636); the s2idle-only suspend path is the mobility
    # bundle's concern.
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
      ../../home/nixos/niri-laptop.nix # Alnair-scoped niri fragment — MacBook-Air touchpad feel + HiDPI, not the shared desktop niri.nix (#636).
      ../../home/shared/ssh.nix
      ../../home/shared/macchina.nix
      ../../home/nixos/macchina-shell-init.nix
      ../../home/shared/agent-clis.nix
      ../../home/shared/agent-clis-extras.nix
    ];
  };
}
