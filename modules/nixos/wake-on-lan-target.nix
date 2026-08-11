# Wake-on-LAN target arming (#632). The passive half of the wake
# primitive: it makes a host's wired NIC listen for the magic packet in
# its sleep state. Reusable across the fleet — wire any host by importing
# this module and listing its wired interface(s) in `wakeOnLan.interfaces`.
#
# NM-vs-nixos decision (the load-bearing correctness call for #632):
# Alcyone runs NetworkManager, so the obvious worry is that NM re-manages
# the NIC and clears WoL. It does not — because
# `networking.interfaces.<i>.wakeOnLan` does NOT go through the network
# backend at all. NixOS compiles it to a systemd .link file
# (40-<i>.link, `WakeOnLan=magic`) that systemd-udevd applies at
# device-add via its net_setup_link builtin, independent of whoever
# manages the interface afterwards (scripted, networkd, OR NetworkManager
# — the option is explicitly backend-shared upstream). NM's own
# 802-3-ethernet.wake-on-lan property defaults to `default`, i.e. leave
# the kernel/udev setting untouched, so the .link value stands. This beats
# a hand-rolled udev+ethtool rule or an imperative NM connection property:
# one declarative source, backend-agnostic, no NM state to drift. Net
# effect on the NIC: `Wake-on: g`.
#
# Firmware dependency OUT of Nix's control: the magic packet only wakes
# the box if the BIOS/UEFI has WoL enabled (often "ErP" off / "Power On By
# PCI-E") AND the board keeps the NIC powered in its sleep state (S3/S5).
# Nix arms the OS side only; the firmware side is a one-time manual setting.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.wakeOnLan;
in
{
  options.wakeOnLan.interfaces = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = ''
      Wired interfaces to arm for Wake-on-LAN (magic-packet policy). Each
      becomes a systemd .link file applied by systemd-udevd — see the
      module header for why this survives NetworkManager.
    '';
    example = [ "enp5s0" ];
  };

  config = lib.mkIf (cfg.interfaces != [ ]) {
    networking.interfaces = lib.genAttrs cfg.interfaces (_: {
      wakeOnLan.enable = true;
    });

    # ethtool is NOT needed to arm WoL (the .link builtin uses netlink
    # directly), but it is the only way to verify it on-metal
    # (`ethtool <iface> | grep Wake-on` → `Wake-on: g`) — the runtime
    # confirmation #632 hangs on, since eval can't prove the NIC state.
    environment.systemPackages = [ pkgs.ethtool ];
  };
}
