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
  ];

  networking.hostName = "mercury";

  # Match the NixOS release the chosen AMI is built from. Set with
  # lib.mkDefault so the amazon-image module wins if it pins a value
  # (some nixpkgs revisions set this from the image's build manifest);
  # otherwise this 25.11 default applies. The operator updates this to
  # match the chosen AMI if it ships a different release.
  system.stateVersion = lib.mkDefault "25.11";

  # PRE-FLIGHT REQUIRED for aarch64 (Graviton) instances. Older
  # amazon-image.nix revisions exposed an `ec2.efi` option that had to
  # be true on arm64 for UEFI boot; newer revisions handle this
  # automatically (auto-detected from hostPlatform). Before first
  # launch, grep the pinned nixpkgs:
  #
  #   nix eval --raw nixpkgs#path -- pkgs/nixos/modules/virtualisation/amazon-image.nix
  #
  # If `ec2.efi` is still an exposed option there, uncomment the line
  # below. If it's been removed, leave it commented — amazon-image
  # handles UEFI on its own. A misnamed option will fail eval; a
  # missing-but-required setting will fail at boot.
  #
  # ec2.efi = true;

  _module.args.hostContext = {
    hostName  = "mercury";
    flakePath = "/home/dbf/nix-config";
    # Work-only: single work identity, no GitHub CLI.
    extraHomeModules = [
      ../../home/core/nixos/git-identity-work.nix
    ];
  };
}
