# niri — Wayland scrollable-tiling compositor.
#
# Enables nixpkgs' `programs.niri` module, which is already in NixOS's
# default module list — hence no `imports` line. That module carries the
# side effects the desktop hosts inherit rather than re-assert: the
# `wayland-sessions/niri.desktop` entry greetd discovers, `systemd.packages`
# + the `niri.service` drop-in (the #67 hardenings, now upstream), the
# xdg.portal wiring including the gnome backend screencast rides, and
# gnome-keyring. Re-verify those inheritances if the module is ever
# swapped again — several modules beside this one lean on them
# (greetd.nix, libsecret.nix, xdg-portal.nix).
#
# niri rides nixpkgs' cadence — no bespoke pin, no niri-flake input, and
# no niri.cachix.org trust delegation (dropped, not replaced). Config is
# owned by home/nixos/niri.nix as a rendered config.kdl, gated by
# `niri validate` at build time rather than by a typed option surface.
# Rationale: docs/design/niri-sourcing.md (#763).
#
# Per ADR-028.
{ pkgs, ... }:
{
  programs.niri.enable = true;

  # nixpkgs' own default, restated so the compositor's source is legible at
  # the point that matters — this is the login path, and the package is what
  # ships both the session entry and the systemd units.
  programs.niri.package = pkgs.niri;
}
