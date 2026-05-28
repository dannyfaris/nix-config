# niri — Wayland scrollable-tiling compositor.
#
# Imports niri-flake's nixosModule (package + polkit + dconf + OpenGL +
# xdg.portal + the wayland-sessions/niri.desktop entry that greetd
# discovers) and enables programs.niri at the system layer.
#
# niri-flake.cache.enable is upstream-default true, which silently adds
# `niri.cachix.org` to nix.settings.substituters. Per CLAUDE.md's
# whitelist > blanket stance, every trust delegation should be
# deliberate — opted out here so no substituter slips into the trust
# chain implicitly. Cost: niri rebuilds from source on every
# niri-flake bump (~10-30 min on metis-class hardware), triggered at
# most weekly by the existing flake-lock cron. If that cost becomes
# painful, the repo may run its own niri binary cache (cachix or
# similar) rather than re-enabling the upstream one.
#
# Per ADR-028.
{ inputs, ... }:
{
  imports = [ inputs.niri-flake.nixosModules.niri ];

  programs.niri.enable = true;

  niri-flake.cache.enable = false;
}
