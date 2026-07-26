{ config, lib, ... }:
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

  # Persist whitelist (module-owns-its-state, docs/design/ephemeral-root.md):
  # node identity + auth state — losing it de-registers the host from the
  # tailnet and demands interactive re-auth, which on a headless host is the
  # break-glass path. Gated on persist.enable (adopting hosts only — see
  # modules/nixos/persist.nix).
  environment.persistence."/persist".directories = lib.mkIf config.persist.enable [
    "/var/lib/tailscale"
  ];
}
