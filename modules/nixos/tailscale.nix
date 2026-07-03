{
  services.tailscale.enable = true;
  # Opens UDP 41641 for direct WireGuard peer connections.
  # Without this, all traffic routes through Tailscale's DERP relays
  # (higher latency, breaks if DERP is unreachable).
  services.tailscale.openFirewall = true;
  # Trust the tunnel interface. Belt-and-suspenders only: tailscale's own
  # ts-input chain accepts all tailscale0 input ahead of the NixOS firewall,
  # so the real tailnet gate is tailnet ACLs, not firewall rules here — see
  # #336 (investigated; per-host port whitelisting judged not worthwhile).
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
