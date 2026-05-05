# Host-specific configuration for the UTM VM (aarch64-linux).
{ ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nixos-vm";

  # Set once at install; never change, even after upgrading.
  system.stateVersion = "25.11";
}
