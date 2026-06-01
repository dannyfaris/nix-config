# Mosh on Darwin — SSH session resilience over UDP. Same role as
# modules/nixos/mosh.nix; pairs with zellij for cross-reboot persistence.
# See docs/decisions/ADR-011-remote-dev-qol.md.
#
# Unlike NixOS, nix-darwin does NOT ship a `programs.mosh.enable`
# option (verified absent at the pinned rev). Install via
# `environment.systemPackages` instead — that's enough: mosh-server
# is a signed nixpkgs binary that ALF passes implicitly under
# `networking.applicationFirewall.allowSigned = true` (the default
# when ALF is enabled). If a host adopts the stealth posture
# (`enableStealthMode = true`), an explicit `allowSignedApp` toggle
# may be needed at that point.
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.mosh ];
}
