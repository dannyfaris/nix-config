# stylix-palette — the per-host base16 palette, and the Stylix module that
# consumes it.
#
# This is the *system half* of the repo's theming wiring. Since ADR-041
# the TUI surface follows the terminal palette (the shared target
# whitelist is empty); this engine remains as the colour table the
# eval-time statuslines read and the palette source for
# lib/scheme-pair.nix. This module owns the upstream:
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
  # Selection semantics (scheme + slot-overrides per polarity, loud failure
  # on an undeclared polarity or host) are single-sourced in
  # lib/palette-for.nix (#541) — shared with the darwin twin and
  # lib/scheme-pair.nix.
  paletteFor = import ../../lib/palette-for.nix hostContext.hostName;
  active = paletteFor.select paletteFor.polarity;
in
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  stylix = {
    enable = true;
    autoEnable = false;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/${active.scheme}.yaml";
    # Per-host polarity so dark-aware apps (Firefox web content, GTK
    # file pickers, Qt platform theme) follow the host's
    # actual visual intent. Also drives the scheme selection above.
    inherit (paletteFor) polarity;
    inherit (active) override;
  };
}
