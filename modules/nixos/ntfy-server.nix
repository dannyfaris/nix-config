# Self-hosted ntfy receiver for fleet unit-failure notifications (#199).
# Companion to modules/nixos/unit-failure-notifier.nix (the senders).
#
# ntfy binds all interfaces, but the firewall opens :8090 only on
# tailscale0 (the allowedTCPPorts entry below — no blanket interface
# trust, per #336), so the endpoint is reachable from tailnet peers and
# nowhere else — no LAN, no public exposure. That tailnet boundary IS the
# auth: ntfy keeps its default anonymous read-write access, introducing no
# token/secret (#199).
#
# Imported by metis only — the chosen always-on receiver. The operator
# subscribes the ntfy phone/desktop app to
#   http://metis:8090/fleet-failures
# over Tailscale.
_: {
  # Whitelist :8090 on the tailnet interface only — this is what scopes the
  # all-interfaces ntfy bind to tailnet peers (see the header note). (#336)
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8090 ];

  services.ntfy-sh = {
    enable = true;
    settings = {
      # base-url must match what clients use, including the port, or ntfy
      # rejects publish/subscribe with a host mismatch.
      base-url = "http://metis:8090";
      # All-interfaces bind; the per-port allow on tailscale0 (above) is
      # what scopes reachability to the tailnet — see the header note.
      listen-http = ":8090";
    };
  };
}
