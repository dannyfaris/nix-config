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
{ config, lib, ... }:
{
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

  # Persist whitelist (module-owns-its-state, docs/design/ephemeral-root.md):
  # ntfy is a DynamicUser service — its real state (user.db, message cache,
  # attachments) lives under /var/lib/private/ntfy-sh, with /var/lib/ntfy-sh
  # a systemd-managed symlink. The declaration is the PARENT with systemd's
  # required 0700: impermanence would otherwise create /var/lib/private with
  # its 0755 default and systemd hard-refuses DynamicUser state under a
  # non-0700 private dir. Slightly wider than one service — any future
  # DynamicUser state rides along — accepted and recorded here. Discovered
  # by the probe's first metis inventory (2026-07-26); the design note's
  # baseline missed it. Gated on persist.enable (adopting hosts only — see
  # modules/nixos/persist.nix).
  environment.persistence."/persist".directories = lib.mkIf config.persist.enable [
    {
      directory = "/var/lib/private";
      mode = "0700";
    }
  ];
}
