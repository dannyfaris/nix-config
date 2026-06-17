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
    ../../modules/nixos/ntfy-server.nix # Self-hosted ntfy receiver for the fleet's failure notifications (#199).
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

  # Per-host parametrisation consumed by home-manager modules
  # (editor.nix nixd options, nix-tooling NH_FLAKE). Set via the typed
  # option layer in modules/nixos/host-context.nix; bridged to
  # extraSpecialArgs via the host-context module's _module.args write.
  # See ADR-019.
  #
  # extraHomeModules is the full HM imports list for this host — capability
  # bundles plus standalone modules, per ADR-027's bundle model. Personal
  # dev box: cli tooling + dual git identity + GitHub CLI + agent CLI
  # extras + login info display + base agent CLIs + outbound SSH. Mirrors
  # nixos-vm.
  #
  # flakePath omitted — the host-context default ("/home/dbf/nix-config")
  # matches this host.
  hostContext = {
    hostName = "metis";
    extraHomeModules = [
      ../../home/shared/bundles/cli-tooling.nix
      ../../home/shared/bundles/git-multi-identity.nix
      # No stylix-targets.nix here (unlike the other hosts): on the Linux
      # desktop Noctalia owns the terminal/TUI palette (ADR-036, #385, E1).
      # Leaving the Stylix `fish` target on in particular would re-emit the
      # base16 palette via OSC on every shell, overriding Noctalia — see
      # docs/desktop/noctalia.md §Sharp edges. stylix.enable stays on (the
      # four eval-time statuslines still read the colour table).
      ../../home/nixos/bundles/desktop-env.nix
      ../../home/shared/ssh.nix
      ../../home/shared/macchina.nix
      ../../home/nixos/macchina-shell-init.nix
      ../../home/shared/agent-clis.nix
      ../../home/shared/agent-clis-extras.nix
    ];
  };
}
