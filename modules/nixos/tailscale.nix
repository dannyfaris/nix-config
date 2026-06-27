{
  services.tailscale.enable = true;
  # Opens UDP 41641 for direct WireGuard peer connections.
  # Without this, all traffic routes through Tailscale's DERP relays
  # (higher latency, breaks if DERP is unreachable).
  services.tailscale.openFirewall = true;
  # No blanket `trustedInterfaces = [ "tailscale0" ]` — that opened every
  # port to every tailnet peer, against whitelist > blanket (worst on
  # mercury, the work box). Each tailnet-reachable service opens its own
  # port on tailscale0, co-located with the service (e.g. ntfy-server.nix).
  # SSH is unaffected: services.openssh.openFirewall opens :22 directly. (#336)
}
