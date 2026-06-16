# Noctalia Shell — cohesive Wayland desktop shell on the Linux desktop
# (ADR-036, #385). v4 Quickshell line via the flake's home-manager module
# (`inputs.noctalia`, pinned to `legacy-v4`).
#
# Non-destructive bring-up (PR-1): enable the shell + install its binary,
# spawned from niri (`spawn-at-startup` in home/nixos/niri.nix). Theming
# (Rose Pine predefined scheme + user-templates), the foot-font re-home, and
# the launcher-keybind cutover land in later slices; waybar/fuzzel/fnott/
# swaylock keep running until decommissioned.
#
# Two upstream quirks the wiring depends on (verified against legacy-v4):
#   - the HM module installs the binary only when `package` is set
#     (`home.packages = lib.optional (cfg.package != null) cfg.package`), so
#     the package is wired explicitly from the flake input here;
#   - the module ships an opt-in systemd unit (deprecated upstream) — left
#     off; the compositor spawns the shell instead.
{ inputs, pkgs, ... }:
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia-shell = {
    enable = true;
    package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
  };
}
