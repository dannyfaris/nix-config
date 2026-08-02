# NetworkManager — desktop-style network stack. Imported per-host;
# today every NixOS host is bare-metal and imports it. Kept out of
# foundation.nix so a host on a platform network stack (cloud-init +
# systemd-networkd) can decline it, as the retired cloud host did.
#
# Firewall enablement lives in modules/nixos/firewall.nix which is
# pulled in by foundation.nix — perimeter is host-network-stack-agnostic.
{ config, lib, ... }:
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

  # Persist whitelist (module-owns-its-state, docs/design/ephemeral-root.md):
  # both NM halves per the design note's baseline — saved connections
  # (Wi-Fi credentials) and the runtime half (DHCP leases, seen-BSSIDs,
  # internal state). Gated on persist.enable (adopting hosts only — see
  # modules/nixos/persist.nix).
  environment.persistence."/persist".directories = lib.mkIf config.persist.enable [
    "/etc/NetworkManager/system-connections"
    "/var/lib/NetworkManager"
  ];
}
