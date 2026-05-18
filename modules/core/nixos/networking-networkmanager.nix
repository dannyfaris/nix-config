# NetworkManager — desktop-style network stack. Imported by hosts whose
# network configuration is interactive (the UTM VM today). Headless
# cloud hosts use cloud-init + systemd-networkd via their platform
# modules (e.g. amazon-image.nix on Mercury) and do NOT import this.
#
# Firewall enablement lives in modules/core/nixos/firewall.nix and is
# imported by the role — perimeter is host-network-stack-agnostic.
{
  networking.networkmanager.enable = true;
}
