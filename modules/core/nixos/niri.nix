# niri — Wayland scrollable-tiling compositor.
#
# Imports niri-flake's nixosModule (package + polkit + dconf + OpenGL +
# xdg.portal + the wayland-sessions/niri.desktop entry that greetd
# discovers) and enables programs.niri at the system layer.
#
# Binary cache: niri-flake.cache.enable defaults to true upstream, which
# would silently add `niri.cachix.org` to nix.settings.substituters —
# one implicit trust delegation per host that imports the module.
# CLAUDE.md's whitelist > blanket stance says every trust delegation
# should be deliberate. The principled shape is therefore to *own* the
# delegation here rather than let niri-flake own it implicitly:
# niri-flake.cache.enable = false so the implicit add doesn't happen,
# and nix.settings then explicitly whitelists the same cache with the
# same upstream key. The delegation is recorded in source, dated, and
# only applies on hosts that import this module (currently metis).
#
# Trust footprint: sodiboo (maintainer) on a single Cachix signing key,
# bounded to niri-stable + niri-unstable + xwayland-satellite (x86_64
# only — niri.cachix.org does not serve aarch64, which is fine here
# because no aarch64 host imports this module). See
# github.com/sodiboo/niri-flake README "Binary cache" section. Revoke
# by removing this module from any host's imports, or by deleting the
# substituter/key lines below; cache.enable = false ensures niri-flake
# does not re-add it.
#
# Without the substituter, niri rebuilds from source on every
# niri-flake bump (~10-30 min on metis-class hardware), and nixpkgs's
# Rust crate fetcher currently 403s on some crates.io paths
# (rust-lang/crates.io#13482, NixOS/nixpkgs#512735 in flight). Both
# costs disappear once the cache is trusted.
#
# Per ADR-028.
{ inputs, ... }:
{
  imports = [ inputs.niri-flake.nixosModules.niri ];

  programs.niri.enable = true;

  # Own the trust delegation explicitly in nix.settings below; do not
  # let niri-flake add `niri.cachix.org` implicitly via this module's
  # default-true behaviour.
  niri-flake.cache.enable = false;

  # Explicit whitelist (2026-05-28) — replaces the implicit
  # niri-flake.cache.enable = true. Public key sourced from upstream
  # niri-flake `flake.nix` (the same key niri-flake would have added).
  nix.settings = {
    substituters = [ "https://niri.cachix.org" ];
    trusted-public-keys = [
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
    ];
  };
}
