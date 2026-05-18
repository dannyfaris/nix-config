# Headless role — a NixOS machine without a graphical environment, accessed
# remotely. Optimised for development work via SSH. Instances include VPS
# dev boxes, bare-metal Linux servers, and VMs used for transient
# development environments (PRD §3.3).
#
# Pure composition: imports only. Per PRD §8.1 rule 4 (role-purity), every
# entry resolves to a path under modules/core/ or home/core/, or to another
# role. No inline option setting, no mkDefault, no _module.args.
#
# Order preserved from the pre-refactor modules/system/default.nix for
# diff-debugging hygiene. Host-specific platform modules (boot loader,
# networking stack) are imported by each host, not by the role — the VM
# uses systemd-boot + NetworkManager, AWS hosts use amazon-image's GRUB +
# cloud-init/networkd.
{
  imports = [
    ../modules/core/nixos/locale.nix
    ../modules/core/nixos/nix-daemon.nix
    ../modules/core/nixos/sshd.nix
    ../modules/core/nixos/firewall.nix
    ../modules/core/nixos/sops.nix
    ../modules/core/nixos/users.nix
    ../modules/core/nixos/system-packages.nix
    ../modules/core/nixos/mosh.nix
    ../modules/core/nixos/home-manager.nix
  ];
}
