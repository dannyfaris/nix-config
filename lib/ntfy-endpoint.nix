# Single source of truth for the fleet's self-hosted ntfy endpoint.
# Imported via Nix `let`-binding (not a NixOS option) — plain data needed
# at any phase, same rationale as lib/operator.nix.
#
# Consumed by (today):
#   - modules/nixos/ntfy-server.nix          — host/port -> base-url,
#                                              listen-http
#   - modules/nixos/unit-failure-notifier.nix — failuresUrl
#   - modules/darwin/launchd-failure-notifier.nix — failuresUrl
#   - modules/nixos/ephemeral-root.nix        — stateUrl (probe option default)
#
# host/port are stated once here and every URL below is derived from them,
# so no consumer — and no field in this file — re-concatenates or restates
# the pair (docs/reviews/engineering-review-2026-07-06.md §5).
let
  host = "electra";
  port = 8090;
  baseUrl = "http://${host}:${toString port}";

  # Topic names, not full URLs — ntfy-server.nix wants the bare base;
  # the per-topic consumers get the derived URLs below.
  topics = {
    failures = "fleet-failures";
    state = "fleet-state";
  };
in
{
  inherit
    host
    port
    baseUrl
    topics
    ;
  failuresUrl = "${baseUrl}/${topics.failures}";
  stateUrl = "${baseUrl}/${topics.state}";
}
