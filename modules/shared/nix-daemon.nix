# Nix daemon settings, garbage collection, and unfree whitelist — the
# cross-platform kernel. Platform-specific knobs live in siblings:
#   - modules/nixos/nix-daemon-nixos.nix — `programs.command-not-found`,
#     calendar-string GC syntax, and the at-write
#     `nix.settings.auto-optimise-store` (kept NixOS-only because
#     nix-darwin's matching assertion guards against race-condition
#     data-corruption bugs in older nix versions).
#   - modules/darwin/nix-daemon-darwin.nix — the launchd `nix.gc.interval`
#     submodule and `nix.optimise.automatic` (the scheduled equivalent
#     of auto-optimise-store, sidestepping the at-write assertion).
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
      "1password" # 1Password desktop GUI on metis (lib.getName of _1password-gui; #112). See docs/desktop/1password.md
      "antigravity-cli" # Google Antigravity CLI (`agy`), replaced Gemini CLI in the agent-clis extras; ADR-008 (#433)
      "claude-code"
      "claude-desktop" # Claude Desktop for Linux (Anthropic beta, repackaged) on metis. See modules/nixos/claude-desktop.nix
      "cursor"
      "cursor-cli"
      "obsidian" # Obsidian PKM / notes GUI on metis (#506). See docs/desktop/obsidian.md
    ];
}
