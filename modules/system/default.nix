# Shared system-tier NixOS modules.
#
# This file imports thematic siblings and adds nothing else.
# Each sibling owns one concern (see docs/taxonomy.md for the naming rule).
{
  imports = [
    ./boot.nix
    ./networking.nix
    ./locale.nix
    ./nix.nix
    ./ssh.nix
    ./sops.nix
    ./users.nix
    ./packages.nix
    ./mosh.nix
  ];
}
