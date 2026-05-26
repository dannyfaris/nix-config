# Host-specific configuration for Metis (HP ProDesk Mini 600 G9, x86_64-linux,
# bare metal). Adopts the headless role (via parts/nixos.nix) and adds the
# bare-metal platform modules (systemd-boot, NetworkManager) that the role
# itself doesn't pick.
#
# Personal dev box: dual git identity (personal + work) + full agent-CLI set,
# mirroring nixos-vm.
#
# Bootstrap via nixos-anywhere + disko (ADR-022); per-host files follow the
# three-file convention (ADR-023). Host key is pre-generated on the operator
# (`just gen-host-key metis`) and injected at install via --extra-files;
# secrets are sops-nix (ADR-018, amended by ADR-022 for acquisition order).
# Runbook: docs/runbooks/headless-bootstrap.md (slice 4 will consolidate
# the old AWS- and Metis-specific runbooks into one).
{ inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    inputs.disko.nixosModules.disko

    ../../modules/core/nixos/boot-systemd.nix
    ../../modules/core/nixos/networking-networkmanager.nix
    ../../modules/core/nixos/tailscale.nix
    ../../modules/core/nixos/docker.nix   # Rootless Docker — see ADR-021.
    ../../modules/core/nixos/btrfs-scrub.nix   # Periodic checksum verification on btrfs subvolumes (monthly default).
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
  _module.args.hostContext = {
    hostName  = "metis";
    flakePath = "/home/dbf/nix-config";
    # Personal dev box: dual identity (personal default; work under ~/work/)
    # plus full GitHub CLI + agent-CLI set — mirrors nixos-vm.
    extraHomeModules = [
      ../../home/core/nixos/git-identity-dual.nix
      ../../home/core/nixos/gh.nix
      ../../home/core/nixos/agent-clis-extras.nix
    ];
  };
}
