# dms-home-bridge — make DMS's home-manager modules reachable from HM users.
#
# modules/core/nixos/home-manager.nix forwards only `hostContext` via
# extraSpecialArgs; `inputs` does not cross the NixOS↔HM boundary as a
# function argument. To give HM modules access to DMS's two home modules
# (homeModules.dank-material-shell for the shell itself,
# homeModules.niri for its niri-integration options like
# programs.dank-material-shell.niri.enableKeybinds), this NixOS-side
# module injects both into home-manager.sharedModules — the existing
# NixOS-side mechanism for adding HM modules to every HM user on the
# host without expanding the extraSpecialArgs contract.
#
# Per ADR-028 §Implementation slice 3.
{ inputs, ... }:
{
  home-manager.sharedModules = [
    inputs.dank-material-shell.homeModules.dank-material-shell
    inputs.dank-material-shell.homeModules.niri
  ];
}
