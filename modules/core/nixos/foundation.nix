# Foundation — the bundle every NixOS host imports by convention.
#
# Structurally a bundle (governed by the same bundle-purity rule, ≥ 2
# imports, pure aggregation — only an `imports` list, no inline config).
# Distinguished from other bundles only by:
#   - name "foundation.nix" (signals universal-import convention);
#   - placement at the top of modules/core/nixos/ rather than inside
#     bundles/ (discoverability).
#
# Contents: identity (users, sops), administration (nix-daemon, locale,
# baseline system packages), security posture (firewall), the
# home-manager NixOS-module wiring, default editor for system-mediated
# tools, and Stylix theming (per-host palette, via stylix-palette.nix).
# Reserved for things that aren't opt-in capabilities. A capability —
# even one every current host happens to want — belongs in a capability
# bundle, not here. See ADR-027 and PRD §3.2.
{ ... }:
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
    # Stylix theming: the stylix module + per-host base16 palette. Its own
    # module so foundation stays a pure imports list (the bundle-purity
    # assumption); the palette was inline here from ADR-028 until factored
    # out under #54. See ADR-027 §History.
    ./stylix-palette.nix
  ];
}
