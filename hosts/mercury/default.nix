# Mercury — work-only headless dev host on AWS EC2 (Graviton, aarch64).
# Adopts the headless role (via parts/nixos.nix). Imports the
# amazon-image module which provides GRUB-on-EBS, cloud-init, EC2
# metadata fetch, and host-key generation on first boot — replacing the
# UTM VM's systemd-boot + NetworkManager choices.
#
# See ADR-017 for the bootstrap-via-AMI decision, ADR-018 for the
# secrets-via-sops-nix decision, and docs/runbooks/headless-bootstrap-aws.md
# for the operational runbook.
{ lib, modulesPath, ... }:

{
  imports = [
    ./hardware.nix

    # Provides: GRUB-on-EBS, ec2.* options (metadata service, hostname
    # from metadata, etc.), cloud-init for SSH-key injection on first
    # boot. Mercury intentionally does NOT import the VM-side
    # boot-systemd.nix or networking-networkmanager.nix.
    "${modulesPath}/virtualisation/amazon-image.nix"

    # Rootless Docker — resolves ADR-006's deferred daemon decision.
    # Mercury-only (not in the role) because the VM doesn't run
    # containers. See ADR-021.
    ../../modules/core/nixos/docker.nix
  ];

  networking.hostName = "mercury";

  # Match the NixOS release the chosen AMI is built from. Set with
  # lib.mkDefault as defensive convention (matches what
  # nixos-generate-config emits for hardware files); at the pinned
  # nixpkgs revision, neither amazon-image.nix nor ec2-data.nix sets
  # system.stateVersion, so the 25.11 default applies. Operator
  # updates this to match the AMI's NixOS release if it differs.
  system.stateVersion = lib.mkDefault "25.11";

  # ec2.efi is auto-set by amazon-options.nix from
  # pkgs.stdenv.hostPlatform.isAarch64 (verified against the pinned
  # nixpkgs revision in flake.lock). On Graviton it defaults to true,
  # which is what we want. The option is also marked `internal = true`
  # — not for user override. Don't set it here.

  _module.args.hostContext = {
    hostName  = "mercury";
    flakePath = "/home/dbf/nix-config";
    # Work-only: single work identity, no GitHub CLI.
    extraHomeModules = [
      ../../home/core/nixos/git-identity-work.nix
    ];
  };
}
