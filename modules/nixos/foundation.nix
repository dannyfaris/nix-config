# Foundation — the bundle every NixOS host imports by convention.
#
# Structurally a bundle (governed by the same bundle-purity rule, ≥ 2
# imports, pure aggregation — only an `imports` list, no inline config).
# Distinguished from other bundles only by:
#   - name "foundation.nix" (signals universal-import convention);
#   - placement at the top of modules/nixos/ rather than inside
#     bundles/ (discoverability).
#
# Contents: identity (users, sops), administration (nix-daemon, locale,
# baseline system packages), security posture (firewall), the
# home-manager NixOS-module wiring, and the default editor for
# system-mediated tools. No theming: the per-host Stylix palette lived
# here from ADR-028 until #885 took Stylix off the NixOS side entirely
# (see ADR-028 §History) — colour on Linux is Noctalia's, at runtime.
# Reserved for things that aren't opt-in capabilities. A capability —
# even one every current host happens to want — belongs in a capability
# bundle, not here. See ADR-027 and PRD §3.2.
{ ... }:
{
  imports = [
    ./locale.nix
    ../shared/nix-daemon.nix
    ./nix-daemon-nixos.nix
    ./firewall.nix
    ./sops.nix
    ./users.nix
    ../shared/system-packages.nix
    ../shared/editor-defaults.nix
    # Fleet host keys pinned system-wide — cross-host SSH without TOFU (#517).
    ../shared/ssh-known-hosts.nix
    ./host-context.nix
    ./home-manager.nix
  ];
}
