# UTM — virtualisation platform for the nixos-vm host (and any
# future Mac-hosted VM workload). Imported per-host; currently
# only by neptune.
#
# See docs/desktop/utm.md for the full ADR-031 walk. Short version:
#
#   - MAS rejected: UTM SE on MAS (id 1564628856) is the iPad-on-Mac
#     compatibility-layer build — sandboxed, no JIT, materially
#     slower than the direct-download UTM. Community calls it the
#     "slow edition" with reason. Clause-3 disqualifier (vendor
#     distributes but the MAS variant is materially degraded).
#   - cask rejected: Homebrew's `utm` cask works and points at the
#     same UTM.dmg from GitHub releases, but UTM has no auto-updater
#     (no Sparkle, no Keystone, no in-app updater — verified against
#     the upstream cask source, which doesn't set `auto_updates`),
#     so the cask path doesn't earn its clause-2 carve-out the way
#     1Password / Chrome / Typora / Obsidian / Cursor / ChatGPT do.
#     Without a named degradation, ADR-031's nixpkgs-by-default
#     baseline applies.
#   - nixpkgs chosen: pkgs.utm on aarch64-darwin works cleanly. Its
#     installPhase puts UTM.app under $out/Applications/ — surfaced
#     via nix-darwin's system-applications mechanism at
#     /Applications/Nix Apps/UTM.app for Spotlight / Launchpad. The
#     derivation ALSO wraps every binary in UTM.app/Contents/MacOS/*
#     (including `utmctl`, the CLI control tool) into $out/bin/ via
#     makeWrapper — putting `utmctl` declaratively on PATH. The
#     operator's CLI-first usage of UTM (VM lifecycle ops scripted
#     through utmctl rather than driven through the GUI) makes the
#     bin-wrapping a load-bearing advantage of nixpkgs over the cask
#     (which doesn't add utmctl to PATH at all — it'd be reachable
#     only via /Applications/UTM.app/Contents/MacOS/utmctl).
#
# Standalone module per ADR-027 (single-package — does not satisfy
# bundle-purity; no coherent sibling yet to graduate into a bundle).
# The host opts in by importing this module.
{ pkgs, ... }:
{
  environment.systemPackages = [
    pkgs.utm # GUI + utmctl CLI; both surfaced on PATH via the
    # nixpkgs derivation's makeWrapper loop. See docs/desktop/utm.md
    # for the install-path rationale + CLI-first reasoning.
  ];
}
