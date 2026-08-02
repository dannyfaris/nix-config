# Wake-on-LAN emitter (#632). The active half of the wake primitive:
# Electra is always-on and shares Alcyone's /24 (192.168.1.0/24), so a
# broadcast magic packet from here reaches Alcyone's sleeping NIC. The
# target side (arming `Wake-on: g`) is modules/nixos/wake-on-lan-target.nix.
#
# ADR-042: this is Electra SOURCING a LAN UDP broadcast (port 9), not an
# outbound SSH edge — no host key is involved, so it does not disturb
# Electra's pure-sink posture. The `just wake-alcyone` recipe SSHes INTO
# Electra (Electra as sink) and runs `wake-alcyone` locally here.
{ pkgs, ... }:
let
  # Alcyone's wired NIC (enp5s0) MAC, verified on-metal (#632) — confirmed
  # a second way from electra's ARP table (192.168.1.78 dev eno1 lladdr
  # 74:56:3c:70:50:15). Inline for the single-target case; promote to
  # lib/wol-targets.nix when #650 lands and a second wakeable host makes a
  # shared table worth its while.
  alcyoneMac = "74:56:3c:70:50:15";

  # Alcyone's /24 directed broadcast — reaches its NIC without knowing the
  # host's (sleeping, hence possibly lease-less) unicast IP. Verified to
  # egress electra's wired eno1, not tailscale0 (`ip route get`). Update
  # alongside the MAC if the LAN is ever renumbered.
  lanBroadcast = "192.168.1.255";

  wakeAlcyone = pkgs.writeShellApplication {
    name = "wake-alcyone";
    runtimeInputs = [ pkgs.wakeonlan ];
    # UDP broadcast to port 9 — unprivileged, so no root is needed.
    text = ''
      wakeonlan -i ${lanBroadcast} ${alcyoneMac}
    '';
  };
in
{
  environment.systemPackages = [ wakeAlcyone ];
}
