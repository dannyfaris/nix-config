# Nix daemon settings, garbage collection, and unfree whitelist.
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
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Flakes don't generate programs.sqlite; leaving this on silently fails.
  programs.command-not-found.enable = false;

  # Whitelist unfree packages by name. Do NOT replace with allowUnfree = true.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
      "cursor-cli"
    ];
}
