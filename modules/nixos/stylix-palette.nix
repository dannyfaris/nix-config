# stylix-palette — the per-host base16 palette, and the Stylix module that
# consumes it.
#
# This is the *system half* of the repo's theming wiring; the home half
# is split across home/shared/stylix-targets.nix (cross-platform TUI
# targets) and home/nixos/stylix-targets-desktop.nix (desktop-only
# targets, picked up via the desktop-env bundle). This module owns the
# upstream:
#   - imports inputs.stylix.nixosModules.stylix (the engine), and
#   - sets the per-host base16 scheme that every Stylix target downstream
#     reads from.
#
# Per-host palette comes from lib/host-palettes.nix keyed on
# hostContext.hostName (the field name set by ADR-019). Missing-host
# lookups fail loudly at eval — `attr.X` on a missing X throws.
#
# autoEnable = false is the whitelist stance per CLAUDE.md "Deliberate
# stances" — every Stylix target is enabled deliberately, not auto-
# detected. The HM-side target enables live in the two files above
# (TUI in shared, desktop in nixos).
#
# No font configuration here — there is no universal font intent. Headless
# hosts (mercury, nixos-vm) don't render fonts; SSH clients use their own.
# Desktop-side font selections + install wiring live in
# modules/nixos/desktop-fonts.nix. See docs/desktop/fonts.md.
#
# Factored out of foundation.nix per #54 (P5.1 groundwork): foundation is
# a pure imports-list aggregator (the bundle-purity assumption), so its
# lone inline config block — the stylix palette, added by ADR-028 — moves
# here, the same way locale/firewall/users each live in their own module.
# See ADR-027 §History and ADR-028 §History for the rationale.
#
# Imported by foundation.nix, so every NixOS host gets a palette. ADR-028
# (Stylix in foundation), amended by ADR-029.
{
  inputs,
  pkgs,
  hostContext,
  ...
}:
let
  palettes = import ../../lib/host-palettes.nix;
  palette = palettes.${hostContext.hostName};
  # Polarity drives scheme selection — a single host-side toggle flips
  # both the base16 palette and the cross-app dark/light signal,
  # eliminating the lockstep-by-convention coupling the previous
  # interim shape (#123 / #141) carried. Fails loudly with a clear
  # message if a host's polarity is set to a variant it hasn't declared
  # (e.g., a dark-only host flipped to light).
  scheme =
    palette.schemes.${palette.polarity}
      or (throw "host-palettes: ${hostContext.hostName} has no `${palette.polarity}` scheme declared");
in
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  stylix = {
    enable = true;
    autoEnable = false;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/${scheme}.yaml";
    # Per-host polarity so dark-aware apps (Firefox web content, Zen
    # chrome, GTK file pickers, Qt platform theme) follow the host's
    # actual visual intent. Also drives the scheme selection above.
    inherit (palette) polarity;
    # Per-host slot corrections for ports that violate base16 slot
    # intents, merged over the scheme by base16.nix. Empty for
    # conformant hosts. See ADR-028 §History (2026-06-10, #331).
    override = palette.overrides.${palette.polarity} or { };
  };
}
