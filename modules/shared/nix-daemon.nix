# Nix daemon settings, garbage collection, and unfree whitelist — the
# cross-platform kernel. NixOS-only knobs (`programs.command-not-found`
# and the GC calendar-string syntax) live in the platform-specific
# sibling `modules/nixos/nix-daemon-nixos.nix`. Darwin's GC scheduling
# uses the launchd `nix.gc.interval` submodule shape and lives in
# `modules/darwin/nix-daemon-darwin.nix`.
#
# Closure-identical to the pre-split single-file module (see git history)
# for every NixOS host — verified via `nix store diff-closures` empty
# across nixos-vm, mercury, and metis at the PR landing this split.
#
# On Darwin: nix-darwin owns `/etc/nix/nix.conf`; first activation
# overwrites whatever the Determinate Systems installer wrote. The flake
# is source of truth post-install. See ADR-027 + the Darwin foundation
# header.
{ lib, ... }:
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Hardlink-dedupe /nix/store on write.
    auto-optimise-store = true;

    # Active dev repos are dirty most of the time; the warning is noise.
    warn-dirty = false;

    # Whitelist > blanket: a transitive flake input's nixConfig block
    # can't silently add a substituter or change daemon settings (nix
    # prompts interactively, then accepts — this makes the answer "no" by
    # default). Symmetric with CI's runner setting in
    # .github/workflows/ci.yaml; the host is where that stance originates.
    # Also a second layer under niri.nix's explicit niri-flake.cache.enable
    # = false: that opt-out is the belt, this is the braces.
    accept-flake-config = false;
  };

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };

  # Whitelist unfree packages by name. Do NOT replace with allowUnfree = true.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
      "cursor"
      "cursor-cli"
    ];
}
