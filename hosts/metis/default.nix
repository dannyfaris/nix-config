# Host-specific configuration for Metis (HP ProDesk Mini 600 G9, x86_64-linux,
# bare metal).
#
# Composes foundation + capability bundles + standalone modules directly
# (per ADR-027), no longer adopts the `headless` role. Personal dev box:
# dual git identity (personal + work) + full agent-CLI set.
#
# Bootstrap via nixos-anywhere + disko (ADR-022); per-host files follow the
# three-file convention (ADR-023). Host key is pre-generated on the operator
# (`just gen-host-key metis`) and injected at install via --extra-files;
# secrets are sops-nix (ADR-018, amended by ADR-022 for acquisition order).
# Runbook: docs/runbooks/headless-bootstrap.md.
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
    ../../modules/nixos/unit-failure-notifier.nix # Fan systemd unit failures to ntfy over the tailnet (#199).
    inputs.wiki-infra.nixosModules.wiki-pipeline # Wiki timer family, state dir, R1 exclusion record (wiki repo: deployment-packaging.md).
    ../../modules/nixos/ephemeral-root.nix # Probe-only for now — see ephemeralRoot below; enforcement flips per docs/design/ephemeral-root.md §Rollout.
    ../../modules/nixos/persist-os-core.nix # OS-core persist whitelist (machine-id, /var/lib/nixos, systemd timers/coredump, /var/log, /var/db/sudo, /root).
  ];

  networking.hostName = "metis";

  # Ephemeral root ENFORCED (flipped 2026-07-30, operator at console —
  # design note §Rollout): every boot archives @root into roots-archive/
  # (30-day retention, purged daily) and boots a fresh empty root; only the
  # persist whitelist survives, /home and /nix untouched. The probe runs
  # both halves — daily live scan (pre-loss warning) and per-boot archive
  # scan (what the whitelist missed). Recovery:
  # docs/runbooks/ephemeral-root-recovery.md; one-boot kill-switch:
  # ephemeral.skip-rollback on the kernel cmdline at the systemd-boot menu.
  ephemeralRoot = {
    enable = true;
    # by-partlabel, matching the root fileSystems entry disko generates —
    # the initrd orders against this device's unit, and the by-label alias
    # is never queued on this host (first-enforcing-boot finding, #553).
    device = "/dev/disk/by-partlabel/disk-main-root";
    probe.enable = true;
  };

  # Persist-whitelist staging (pre-flip): the @persist subvolume exists
  # (created online 2026-07-26, see disko.nix) and the whitelist declarations
  # are ACTIVE — state migrates onto /persist bind mounts while the root is
  # still mutable, so the flip changes enforcement, not data location.
  # ORDERING CONSTRAINT: the @persist subvolume and its pre-populated
  # content must exist BEFORE this config activates (the neededForBoot
  # mount fails a boot without it; empty bind mounts would shadow live
  # service state) — retrofit choreography in PR #658.
  persist.enable = true;
  fileSystems."/persist".neededForBoot = true;

  # Wiki pipeline (log-host role) — metis is the ruled log host (wiki repo:
  # deployment-topology.md, decisions.md 021). Every other option defaults
  # to the ruled topology; expectedHost is asserted against hostName at
  # eval, and the units carry WIKI_EXPECTED_* for the wiki's own runtime
  # drift guard against deploy/topology.toml.
  services.wiki-pipeline = {
    enable = true;
    expectedHost = "metis";
  };

  # Set once at install; never change, even after upgrading.
  system.stateVersion = "25.11";

  # Defensive — kept deliberately even though disko's btrfs module also
  # pulls btrfs into the initrd. Matches what nixos-generate-config emits
  # and survives future refactors. Do NOT strip as redundant.
  boot.supportedFilesystems = [ "btrfs" ];

  # zram-only swap — 50 % of RAM, zstd compression, appropriate for
  # 32 GiB. No disk swap (no hibernate on a headless box; zero SSD wear).
  zramSwap.enable = true;
  swapDevices = [ ];

  # systemd-oomd: kills the heaviest descendant in user.slice at 80 %
  # memory-pressure (systemd default duration). 32 GiB makes
  # thrash-to-hang rare, but Docker builds + agent CLIs can still
  # saturate zram, so the mitigation stays.
  # system/root slices excluded so oomd can't kill sshd (break-glass
  # via LAN SSH).
  systemd.oomd.enableUserSlices = true;

  # Per-host parametrisation consumed by home-manager modules
  # (editor.nix nixd options, nix-tooling NH_FLAKE). Set via the typed
  # option layer in modules/nixos/host-context.nix; bridged to
  # extraSpecialArgs via the host-context module's _module.args write.
  # See ADR-019.
  #
  # extraHomeModules is the full HM imports list for this host — capability
  # bundles plus standalone modules, per ADR-027's bundle model. Personal
  # dev box: cli tooling + dual git identity + GitHub CLI + agent CLI
  # extras + login info display + base agent CLIs + outbound SSH.
  #
  # flakePath omitted — the host-context default ("/home/dbf/nix-config")
  # matches this host.
  hostContext = {
    hostName = "metis";
    # Guarded idle→suspend (stance change, #644 — retires "no auto-suspend
    # on a desktop"). The guard skips while caffeine/SSH/agent activity is
    # present; flip to false at the #387 homelab re-role.
    idleSuspend = true;
    extraHomeModules = [
      ../../home/shared/bundles/cli-tooling.nix
      ../../home/shared/bundles/git-multi-identity.nix
      # No stylix-targets.nix here — historically because Noctalia owned
      # the terminal palette on the Linux desktop (ADR-036, #385, E1);
      # now moot fleet-wide, since the whitelist is empty (ADR-041: TUIs
      # follow the terminal palette). The shared per-tool ANSI config
      # (bat/helix/fzf/zellij/...) reaches metis through cli-tooling and
      # follows foot's theme-menu palette — coherent with the
      # runtime-conductor model. stylix.enable stays on (the four
      # eval-time statuslines still read the colour table).
      ../../home/nixos/bundles/desktop-env.nix
      ../../home/shared/ssh.nix
      ../../home/shared/macchina.nix
      ../../home/nixos/macchina-shell-init.nix
      ../../home/shared/agent-clis.nix
      ../../home/shared/agent-clis-extras.nix
    ];
  };
}
