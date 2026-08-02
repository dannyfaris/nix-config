# Host-specific configuration for Electra (Lenovo ThinkCentre M920q Tiny
# 10RRS2L700, i5-8500T Coffee Lake, 8 GiB — 16 GiB planned (#637), 256 GB
# NVMe, x86_64-linux, bare metal). ADR-045 star name; main-homelab
# Pleiades group (taxonomy.md). Genuinely headless, personal-only,
# always-on service-tier node — role deliberately open (#637); the
# CI-runner candidacy (#546) and any role bundles land as their own
# deliberate follow-ons, never scaffold riders.
#
# Composes foundation + capability bundles + standalone modules directly
# (ADR-027). True headless: no desktop-env at system or home level.
# Personal-only dev box: single personal git identity + full agent-CLI
# set. ADR-042 service-tier SINK: accepts the workstations' keys, never
# sources — no outbound SSH key exists on this host at all (see
# hostContext below).
#
# Bootstrap via nixos-anywhere + disko (ADR-022); three-file host
# structure (ADR-023). Host key pre-generated on the operator
# (`just gen-host-key electra`) and injected at install; secrets are
# sops-nix. Runbook: docs/runbooks/headless-bootstrap.md.
{ inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    inputs.disko.nixosModules.disko

    # Foundation — bundle every NixOS host imports by convention.
    ../../modules/nixos/foundation.nix

    # Capability bundles. remote-access only — no desktop-env (true
    # headless, #637 decision 3); break-glass is the physical console.
    ../../modules/nixos/bundles/remote-access.nix

    # Standalone system modules.
    ../../modules/nixos/boot-systemd.nix
    ../../modules/nixos/networking-networkmanager.nix
    ../../modules/nixos/tailscale.nix
    ../../modules/nixos/btrfs-scrub.nix # Periodic checksum verification on btrfs subvolumes (monthly default).
    ../../modules/nixos/wake-on-lan-emitter.nix # WoL emitter (#632) — always-on, same /24 as alcyone; provides the wake-alcyone wrapper. ADR-042: LAN broadcast, not an SSH edge.
    ../../modules/nixos/unit-failure-notifier.nix # Fan systemd unit failures to metis's ntfy over the tailnet (#199) — client from day one; the ntfy SERVER relocating here is a #637 follow-on, not scaffold scope.
    ../../modules/nixos/ephemeral-root.nix # Enforced from first boot — see ephemeralRoot below; docs/design/ephemeral-root.md.
    ../../modules/nixos/persist-os-core.nix # OS-core persist whitelist (machine-id, /var/lib/nixos, systemd timers/coredump, /var/log, /var/db/sudo, /root).
    # No docker.nix — the open role decision (#637) gates container
    # tooling; adopt deliberately with the role, mirroring alnair's
    # explicit omission.
  ];

  networking.hostName = "electra";

  # Set once at install; never change, even after upgrading. 26.11 = the
  # release Electra installs against (system.nixos.release); greenfield
  # box, so no legacy state to strand. Per-host install-era marker, not a
  # fleet-wide constant — metis stays 25.11 (its own install era).
  system.stateVersion = "26.11";

  # systemd initrd — required for the TPM2 LUKS auto-unseal declared in
  # disko.nix (`crypttabExtraOpts = tpm2-device=auto`): only the systemd
  # stage-1 supports TPM2 unlocking. See disko.nix header (#637 / #557).
  # Also a hard requirement of the ephemeral-root initrd rollback below.
  boot.initrd.systemd.enable = true;

  # Ephemeral root ENFORCED from first boot (#637 decision 2): greenfield
  # host, no legacy state to inventory, whitelist already seeded
  # fleet-wide by owning modules and metis-proven. Every boot archives
  # @root (30-day retention, purged daily) and boots a fresh empty root;
  # only the persist whitelist survives, /home and /nix untouched. The
  # probe runs both halves — daily live scan and per-boot archive scan.
  # Recovery: docs/runbooks/ephemeral-root-recovery.md; one-boot
  # kill-switch: ephemeral.skip-rollback on the kernel cmdline at the
  # systemd-boot menu.
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

  # zram-only swap — 50 % of RAM, zstd compression. Sized against today's
  # 8 GiB (the #637 16 GiB bump is a deferred bench visit, not scaffold
  # scope). No disk swap (no hibernate; and disk swap outside the LUKS
  # container would leak plaintext memory pages past encryption-at-rest).
  zramSwap.enable = true;
  swapDevices = [ ];

  # systemd-oomd: kills the heaviest descendant in user.slice at 80 %
  # memory-pressure. Agent CLIs + flake evals can saturate zram on 8 GiB;
  # system/root slices excluded so oomd can't kill sshd — break-glass on
  # this headless box is otherwise the physical console.
  systemd.oomd.enableUserSlices = true;

  # Per-host parametrisation consumed by home-manager modules (ADR-019).
  # extraHomeModules is the full HM imports list — capability bundles plus
  # standalone modules (ADR-027). Personal-only headless box: cli tooling
  # + single personal git identity + GitHub CLI + TUI theming + login info
  # display + base agent CLIs + agent-CLI extras.
  #
  # idleSuspend omitted (defaults false) — always-on is the point (#637
  # decision 3).
  #
  # No home/shared/ssh.nix, deliberately (#637 decision 4): Electra is an
  # ADR-042 pure sink with NO outbound SSH key at all — git/gh reach
  # GitHub over HTTPS (ADR-009). Do not "fix" by adding a key.
  #
  # flakePath omitted — the host-context default ("/home/dbf/nix-config")
  # matches this host.
  hostContext = {
    hostName = "electra";
    extraHomeModules = [
      ../../home/shared/bundles/cli-tooling.nix
      # Personal-only identity: base git + single personal identity +
      # GitHub CLI, imported individually (no git-multi-identity bundle —
      # that carries the work identity this host deliberately omits).
      ../../home/shared/git.nix
      ../../home/shared/git-identity.nix
      ../../home/shared/gh.nix
      ../../home/shared/stylix-targets.nix # Headless TUI theming — desktop hosts get this via Noctalia instead.
      ../../home/shared/macchina.nix
      ../../home/nixos/macchina-shell-init.nix
      ../../home/shared/agent-clis.nix
      ../../home/shared/agent-clis-extras.nix
    ];
  };
}
