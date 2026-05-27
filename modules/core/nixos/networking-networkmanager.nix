# NetworkManager — desktop-style network stack. Imported by bare-metal
# hosts whose network configuration is interactive (the UTM VM and
# Metis today). Cloud hosts use cloud-init + systemd-networkd via their
# platform modules (e.g. amazon-image.nix on Mercury) and do NOT
# import this.
#
# Firewall enablement lives in modules/core/nixos/firewall.nix which is
# pulled in by foundation.nix — perimeter is host-network-stack-agnostic.
{
  networking.networkmanager.enable = true;
}
