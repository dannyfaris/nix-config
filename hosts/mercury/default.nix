# Mercury — work-only headless dev host on AWS EC2 (Graviton, aarch64).
# Adopts the headless role (via parts/nixos.nix). Imports the
# amazon-image module which provides GRUB-on-EBS, cloud-init, EC2
# metadata fetch, and host-key generation on first boot — replacing the
# UTM VM's systemd-boot + NetworkManager choices.
#
# See ADR-017 for the bootstrap-via-AMI decision, ADR-018 for the
# secrets-via-sops-nix decision, and docs/runbooks/headless-bootstrap-aws.md
# for the operational runbook.
{ modulesPath, ... }:

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

  # Match the NixOS release the chosen AMI is built from. The user
  # selects the latest unstable-aligned AMI at provision time
  # (nixos.github.io/amis) and updates this if the AMI is on a different
  # release than the VM. Default 25.11 matches the VM; revise to the
  # AMI's release if it differs.
  system.stateVersion = "25.11";

  _module.args.hostContext = {
    hostName  = "mercury";
    flakePath = "/home/dbf/nix-config";
    # Work-only: single work identity, no GitHub CLI.
    extraHomeModules = [
      ../../home/core/nixos/git-identity-work.nix
    ];
  };
}
