# Foundation — the bundle every NixOS host imports by convention.
#
# Structurally a bundle (governed by the same bundle-purity rule, ≥ 2
# imports, pure aggregation). Distinguished from other bundles only by:
#   - name "foundation.nix" (signals universal-import convention);
#   - placement at the top of modules/core/nixos/ rather than inside
#     bundles/ (discoverability).
#
# Contents: identity (users, sops), administration (nix-daemon, locale,
# baseline system packages), security posture (firewall), and the
# home-manager NixOS-module wiring. Reserved for things that aren't
# opt-in capabilities. A capability — even one every current host
# happens to want — belongs in a capability bundle, not here. See
# ADR-027 and PRD §3.2.
{
  imports = [
    ./locale.nix
    ./nix-daemon.nix
    ./firewall.nix
    ./sops.nix
    ./users.nix
    ../shared/system-packages.nix
    ../shared/editor-defaults.nix
    ./host-context.nix
    ./home-manager.nix
  ];
}
