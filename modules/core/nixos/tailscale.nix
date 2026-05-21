{
  services.tailscale.enable = true;
  # Opens UDP 41641 for direct WireGuard peer connections.
  # Without this, all traffic routes through Tailscale's DERP relays
  # (higher latency, breaks if DERP is unreachable).
  services.tailscale.openFirewall = true;
  # Trust the tunnel interface so the firewall allows all inbound
  # traffic from Tailscale peers without per-port rules.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
