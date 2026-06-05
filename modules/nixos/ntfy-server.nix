# Self-hosted ntfy receiver for fleet unit-failure notifications (#199).
# Companion to modules/nixos/unit-failure-notifier.nix (the senders).
#
# ntfy binds all interfaces, but the firewall default-denies everything
# except tailscale0 (trusted via modules/nixos/tailscale.nix), so the
# endpoint is reachable from tailnet peers and nowhere else — no LAN, no
# public exposure. That tailnet boundary IS the auth: ntfy keeps its
# default anonymous read-write access, introducing no token/secret (#199).
#
# Imported by metis only — the chosen always-on receiver. The operator
# subscribes the ntfy phone/desktop app to
#   http://metis:8090/fleet-failures
# over Tailscale.
_: {
  services.ntfy-sh = {
    enable = true;
    settings = {
      # base-url must match what clients use, including the port, or ntfy
      # rejects publish/subscribe with a host mismatch.
      base-url = "http://metis:8090";
      # All-interfaces bind; the firewall (tailscale0-only) is what scopes
      # reachability to the tailnet — see the header note.
      listen-http = ":8090";
    };
  };
}
