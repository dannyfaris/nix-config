# Foundation — the bundle every Darwin host imports by convention.
#
# Mirrors the shape of modules/nixos/foundation.nix: structurally a
# bundle (governed by the same bundle-purity rule, ≥ 2 imports, pure
# aggregation — only an `imports` list, no inline config). Distinguished
# from other bundles only by:
#   - name "foundation.nix" (signals universal-import convention);
#   - placement at the top of modules/darwin/ rather than inside
#     bundles/ (discoverability).
#
# Contents: identity (users, sops), administration (nix-daemon kernel +
# Darwin GC interval, baseline system packages, default editor for
# system-mediated tools), security posture (ALF firewall), the
# home-manager nix-darwin-module wiring, and Stylix theming (per-host
# palette, via stylix-palette.nix).
#
# Reserved for things that aren't opt-in capabilities. A capability —
# even one every current host happens to want — belongs in a capability
# bundle, not here. See ADR-027 and PRD §3.2.
#
# Locale is deliberately omitted: NixOS's locale.nix sets
# `i18n.defaultLocale` (NixOS-only); macOS owns its own locale stack via
# NSGlobalDomain. Timezone is left to macOS unless a host explicitly
# overrides via `time.timeZone` (nix-darwin typed option).
{ ... }:
{
  imports = [
    ../shared/nix-daemon.nix
    ./nix-daemon-darwin.nix
    ./firewall.nix
    ./sops.nix
    ./users.nix
    ../shared/system-packages.nix
    ../shared/editor-defaults.nix
    ./host-context.nix
    ./home-manager.nix
    # Stylix theming: the stylix module + per-host base16 palette. Its
    # own module so foundation stays a pure imports list (bundle-purity
    # rule). Mirrors modules/nixos/stylix-palette.nix.
    ./stylix-palette.nix
  ];
}
