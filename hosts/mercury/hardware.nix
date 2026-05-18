# Placeholder hardware configuration for Mercury — set just enough for
# `nix flake check` to evaluate before the first AWS instance exists.
#
# After the instance is launched and the first nixos-rebuild succeeds,
# regenerate the real version with:
#
#   sudo nixos-generate-config --show-hardware-config > hosts/mercury/hardware.nix
#
# and commit the replacement. The amazon-image module handles the bulk
# of the platform configuration (boot, EBS root, cloud-init), so the
# generated file is typically near-empty — likely just the hostPlatform
# line and an EBS-root fileSystems entry that the amazon-image module
# already sets a default for.
{ lib, ... }:

{
  # aarch64-linux for AWS Graviton. Set with lib.mkDefault so the
  # amazon-image module can override if needed.
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
