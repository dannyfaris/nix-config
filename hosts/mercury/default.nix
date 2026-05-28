# Mercury — work-only headless dev host on AWS EC2 (Nitro, x86_64, t3.medium).
#
# Composes foundation + capability bundles + standalone modules directly
# (per ADR-027), no longer adopts the `headless` role. Imports the
# amazon-image module which provides EBS/NVMe initrd modules, the
# `ena` enhanced-networking driver, cloud-init for SSH-key injection
# on first boot, `boot.growPartition`, and the long NVMe I/O timeout.
#
# Bootstrap via nixos-anywhere + disko (ADR-022); per-host files follow
# the three-file convention (ADR-023). ADR-017 is superseded; ADR-018
# is amended by ADR-022 for the host-key acquisition order (host key is
# pre-generated on the operator and injected via --extra-files, not
# harvested post-boot). Operator runbook at
# docs/runbooks/headless-bootstrap.md.
{
  lib,
  modulesPath,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    inputs.disko.nixosModules.disko

    # Provides: EBS/NVMe initrd modules + ena driver + cloud-init +
    # ec2.* options (metadata service, hostname from metadata, etc.) +
    # boot.growPartition + the long NVMe I/O timeout. amazon-image's
    # fileSystems declarations are lib.mkDefault (nixpkgs #377406), so
    # disko's layout wins without lib.mkForce. Mercury intentionally
    # does NOT import boot-systemd.nix or networking-networkmanager.nix
    # — those bare-metal platform modules are subsumed by amazon-image
    # for cloud hosts.
    "${modulesPath}/virtualisation/amazon-image.nix"

    # Foundation — bundle every NixOS host imports by convention.
    ../../modules/core/nixos/foundation.nix

    # Capability bundles.
    ../../modules/core/nixos/bundles/remote-access.nix

    # Standalone system modules.
    # Rootless Docker — resolves ADR-006's deferred daemon decision.
    # Mercury opts in; the VM doesn't run containers. See ADR-021.
    ../../modules/core/nixos/docker.nix
  ];

  networking.hostName = "mercury";

  # NixOS release the bootstrap targets. lib.mkDefault as defensive
  # convention; at the pinned nixpkgs revision, neither amazon-image.nix
  # nor ec2-data.nix sets system.stateVersion, so the 25.11 default
  # applies. Operator updates this to match the nixos-anywhere installer
  # image's NixOS release if it differs.
  system.stateVersion = lib.mkDefault "25.11";

  # 4 GiB t3.medium: zram absorbs hot pressure via compression; disk
  # swap on the ext4 root provides true overflow when working set
  # exceeds RAM. Both are needed — metis's zram-only is sized for its
  # 32 GiB box. swappiness lowered from default 60 so the kernel
  # prefers zram over EBS-backed disk swap until truly under pressure.
  zramSwap.enable = true;
  # Defence-in-depth per ADR-021: random key destroys swapfile content
  # at every reboot, so EBS snapshots and post-termination volume
  # recovery can't yield swapped-out secrets. Disables hibernate,
  # irrelevant on a cloud VM. AES-NI on Nitro makes per-IO cost
  # negligible.
  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
      randomEncryption.enable = true;
    }
  ];
  boot.kernel.sysctl."vm.swappiness" = 10;

  # systemd-oomd: enableUserSlices wires user.slice with
  # ManagedOOMMemoryPressure=kill at 80 % memory-pressure (systemd
  # default duration), killing the heaviest descendant before the
  # kernel thrash-hangs. system/root slices intentionally excluded —
  # oomd would otherwise be free to kill the slice containing sshd,
  # costing a break-glass recovery via Instance Connect.
  systemd.oomd.enableUserSlices = true;

  # UEFI boot — explicit override of amazon-options.nix's default
  # (`pkgs.stdenv.hostPlatform.isAarch64`, i.e. false on x86_64).
  # disko.nix produces a UEFI-shaped layout (ESP + EF00 partition type),
  # so BIOS boot would fail. ec2.efi is marked `internal = true` in
  # nixpkgs but nixpkgs's own amazon-image.nix image-builder sets it
  # directly, so overriding it from a host config is consistent with
  # that established pattern, not a violation.
  ec2.efi = true;

  # amazon-image.nix sets PermitRootLogin = "prohibit-password" at the
  # same module-merge priority as sshd.nix's "no" (sshd.nix is reached
  # via bundles/remote-access.nix post-ADR-027), which would otherwise
  # be a hard eval conflict. mkForce here because the "no root, ever"
  # stance (CLAUDE.md "Deliberate stances") is non-negotiable; the
  # override lives on Mercury because Mercury is what brings
  # amazon-image into the module set (PRD §5.4 — overrides on the
  # diverging side; ADR-020 — divergence = choice of import).
  services.openssh.settings.PermitRootLogin = lib.mkForce "no";

  # extraHomeModules is the full HM imports list for this host —
  # capability bundles plus standalone modules, per ADR-027's bundle
  # model. Work-only: cli tooling + work-only git (no gh per the
  # mercury_push_boundary rule) + login info + base agent CLIs +
  # outbound SSH. No agent-clis-extras.
  #
  # flakePath omitted — the host-context default ("/home/dbf/nix-config")
  # matches this host.
  hostContext = {
    hostName = "mercury";
    extraHomeModules = [
      ../../home/core/shared/bundles/cli-tooling.nix
      ../../home/core/shared/bundles/git-work.nix
      ../../home/core/shared/bundles/theming.nix
      ../../home/core/shared/ssh.nix
      ../../home/core/nixos/macchina.nix
      ../../home/core/shared/agent-clis.nix
    ];
  };
}
