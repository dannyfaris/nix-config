# NetworkManager — desktop-style network stack. Imported by bare-metal
# hosts whose network configuration is interactive (the UTM VM and
# Metis today). Cloud hosts use cloud-init + systemd-networkd via their
# platform modules (e.g. amazon-image.nix on Mercury) and do NOT
# import this.
#
# Firewall enablement lives in modules/nixos/firewall.nix which is
# pulled in by foundation.nix — perimeter is host-network-stack-agnostic.
let
  operator = import ../../lib/operator.nix;
in
{
  networking.networkmanager.enable = true;

  # Operator needs networkmanager group membership to control NM
  # (nmcli/nmtui via polkit). Co-located here, with the capability that
  # creates the group, rather than in foundation users.nix — extraGroups
  # list options merge across modules, so only NM hosts carry it (#341).
  users.users.${operator.name}.extraGroups = [ "networkmanager" ];
}
