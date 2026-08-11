# File manager (system side) — Nautilus (package only, no NixOS module) +
# the gvfs daemons behind it. Home side (trash timer, directory handler):
# home/nixos/file-manager.nix. Selection + rationale: docs/desktop/file-manager.md (#771).
{ pkgs, ... }:
{
  # No programs.nautilus module exists — plain package install (own thumbnailers, see doc).
  environment.systemPackages = [ pkgs.nautilus ];

  # Default full-backend build from the binary cache — rationale in the doc.
  services.gvfs.enable = true;
}
