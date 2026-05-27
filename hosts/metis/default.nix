# Host-specific configuration for Metis (HP ProDesk Mini 600 G9, x86_64-linux,
# bare metal).
#
# Composes foundation + capability bundles + standalone modules directly
# (per ADR-027), no longer adopts the `headless` role. Personal dev box:
# dual git identity (personal + work) + full agent-CLI set, mirroring
# nixos-vm.
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
    ../../modules/core/nixos/foundation.nix

    # Capability bundles.
    ../../modules/core/nixos/bundles/remote-access.nix

    # Standalone system modules.
    ../../modules/core/nixos/boot-systemd.nix
    ../../modules/core/nixos/networking-networkmanager.nix
    ../../modules/core/nixos/tailscale.nix
    ../../modules/core/nixos/docker.nix # Rootless Docker — see ADR-021.
    ../../modules/core/nixos/btrfs-scrub.nix # Periodic checksum verification on btrfs subvolumes (monthly default).
  ];

  networking.hostName = "metis";

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
  # thrash-to-hang rarer than on Mercury, but Docker builds + agent
  # CLIs can still saturate zram — same failure mode, same mitigation.
  # system/root slices excluded so oomd can't kill sshd (break-glass
  # via LAN SSH).
  systemd.oomd.enableUserSlices = true;

  # Per-host values consumed by home-manager modules (editor.nix nixd
  # options, nix-tooling NH_FLAKE). Forwarded into the HM submodule system
  # via extraSpecialArgs in modules/core/nixos/home-manager.nix. See ADR-019.
  #
  # extraHomeModules is now the full HM imports list for this host —
  # capability bundles plus standalone modules, per ADR-027's bundle
  # model. Personal dev box: cli tooling + dual git identity + GitHub
  # CLI + agent CLI extras + login info + base agent CLIs + outbound
  # SSH. Mirrors nixos-vm.
  _module.args.hostContext = {
    hostName = "metis";
    flakePath = "/home/dbf/nix-config";
    extraHomeModules = [
      ../../home/core/shared/bundles/cli-tooling.nix
      ../../home/core/shared/bundles/git-personal.nix
      ../../home/core/shared/ssh.nix
      ../../home/core/nixos/macchina.nix
      ../../home/core/shared/agent-clis.nix
      ../../home/core/shared/agent-clis-extras.nix
    ];
  };
}
