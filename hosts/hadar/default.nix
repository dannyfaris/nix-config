# Host-specific configuration for Hadar (HP ProDesk Mini 600 G9,
# x86_64-linux, bare metal — the former metis hardware redeployed to the
# off-site Centaurus location, #798). ADR-045 star name; offsite-homelab
# Centaurus group (taxonomy.md). Genuinely headless, personal-only,
# always-on node at the fleet's second physical site (#641's two-site
# turn made concrete); no additional services at this stage — the #641
# off-site role candidates (backup, DR mirror, monitoring vantage) land
# as their own deliberate follow-ons, never scaffold riders.
#
# Composes foundation + capability bundles + standalone modules directly
# (ADR-027). True headless: no desktop-env at system or home level.
# Personal-only dev box: single personal git identity + full agent-CLI
# set. ADR-042 service-tier SINK: accepts the workstations' keys, never
# sources — no outbound SSH key exists on this host at all (see
# hostContext below). Tailscale is the ONLY remote path — off-site, so
# no LAN fallback from the homelab; break-glass is the physical console
# at the off-site location.
#
# Bootstrap via nixos-anywhere + disko (ADR-022); three-file host
# structure (ADR-023). Host key pre-generated on the operator
# (`just gen-host-key hadar`) and injected at install; secrets are
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
    # headless, #798); break-glass is the off-site physical console.
    ../../modules/nixos/bundles/remote-access.nix

    # Standalone system modules.
    ../../modules/nixos/boot-systemd.nix
    ../../modules/nixos/networking-networkmanager.nix
    ../../modules/nixos/tailscale.nix
    ../../modules/nixos/btrfs-scrub.nix # Periodic checksum verification on btrfs subvolumes (monthly default).
    ../../modules/nixos/unit-failure-notifier.nix # Fan systemd unit failures to ntfy over the tailnet (#199) — the tailnet reaches off-site, so client-side nothing changes.
    ../../modules/nixos/ephemeral-root.nix # Enforced from first boot — see ephemeralRoot below; docs/design/ephemeral-root.md.
    ../../modules/nixos/persist-os-core.nix # OS-core persist whitelist (machine-id, /var/lib/nixos, systemd timers/coredump, /var/log, /var/db/sudo, /root).
    # No docker.nix — no additional services at this stage (#798); any
    # #641 role adopts its tooling deliberately, mirroring electra's
    # explicit omission.
    # No wake-on-lan-emitter.nix — it broadcasts on alcyone's /24
    # (#632); meaningless from the off-site LAN.
    # No ntfy-server.nix — the fleet receiver stays on electra (#688);
    # this host is a unit-failure-notifier client only.
  ];

  networking.hostName = "hadar";

  # Set once at install; never change, even after upgrading. 26.11 = the
  # release Hadar installs against (system.nixos.release); full reformat
  # of the metis-era disk, so no legacy state to strand — the metis
  # install era (25.11) does not carry over.
  system.stateVersion = "26.11";

  # systemd initrd — required for the TPM2 LUKS auto-unseal declared in
  # disko.nix (`crypttabExtraOpts = tpm2-device=auto`): only the systemd
  # stage-1 supports TPM2 unlocking. See disko.nix header (#798).
  # Also a hard requirement of the ephemeral-root initrd rollback below.
  boot.initrd.systemd.enable = true;

  # Ephemeral root ENFORCED from first boot (#798): greenfield reinstall,
  # no legacy state to inventory, whitelist seeded fleet-wide by owning
  # modules and proven on metis/electra. Every boot archives @root
  # (30-day retention, purged daily) and boots a fresh empty root; only
  # the persist whitelist survives, /home and /nix untouched. The probe
  # runs both halves — daily live scan and per-boot archive scan.
  # Recovery: docs/runbooks/ephemeral-root-recovery.md; one-boot
  # kill-switch: ephemeral.skip-rollback on the kernel cmdline at the
  # systemd-boot menu — which off-site means hands on the console there.
  ephemeralRoot = {
    enable = true;
    # The LUKS-mapped device, matching the root fileSystems entry disko
    # generates — the btrfs top level lives INSIDE the container, so the
    # initrd can only mount it post-unlock. Ordering after
    # initrd-root-device.target implies the cryptsetup unlock has
    # completed and the mapper node exists.
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

  # zram-only swap — 50 % of RAM, zstd compression, appropriate for the
  # 32 GiB carried over from the metis era. No disk swap (no hibernate;
  # and disk swap outside the LUKS container would leak plaintext memory
  # pages past encryption-at-rest).
  zramSwap.enable = true;
  swapDevices = [ ];

  # systemd-oomd: kills the heaviest descendant in user.slice at 80 %
  # memory-pressure. 32 GiB makes thrash-to-hang rare, but agent CLIs +
  # flake evals can still saturate zram; system/root slices excluded so
  # oomd can't kill sshd — break-glass on this off-site box is otherwise
  # a physical console a different building away.
  systemd.oomd.enableUserSlices = true;

  # Per-host parametrisation consumed by home-manager modules (ADR-019).
  # extraHomeModules is the full HM imports list — capability bundles plus
  # standalone modules (ADR-027). Personal-only headless box: cli tooling
  # + single personal git identity + GitHub CLI + TUI theming + login info
  # display + base agent CLIs + agent-CLI extras.
  #
  # idleSuspend omitted (defaults false) — always-on is the point; an
  # off-site box that suspends is unreachable until someone drives there.
  #
  # No home/shared/ssh.nix, deliberately (#798): Hadar is an ADR-042 pure
  # sink with NO outbound SSH key at all — git/gh reach GitHub over HTTPS
  # (ADR-009). Do not "fix" by adding a key.
  #
  # flakePath omitted — the host-context default ("/home/dbf/nix-config")
  # matches this host.
  hostContext = {
    hostName = "hadar";
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
