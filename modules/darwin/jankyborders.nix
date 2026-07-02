# JankyBorders — the focused-window border for AeroSpace-tiled windows on
# neptune (ADR-040 Stage 2, #494). AeroSpace draws no active-window chrome of
# its own, so a border is what makes the focused tile legible; it is the macOS
# analogue of the window border niri draws (home/nixos/niri.nix).
#
# Active/inactive colours source from the shared design-token roles
# (lib/theme-tokens.nix): active = the focus role (base0D), inactive = muted
# (base03) — so the border speaks the repo's colour vocabulary
# (visual-identity.md §Colour). (This is role-parity, not wire-parity with niri:
# niri's border colour is Noctalia-driven at runtime, not token-sourced.)
# JankyBorders wants 0xAARRGGBB and the tokens give RRGGBB, so each is prefixed
# with an opaque `ff` alpha (a deliberate solid border, not a format constraint).
#
# This is a nix-darwin *system* service (launchd user agent, KeepAlive), not a
# home-manager module — hence it lives here and is imported in the host's
# system `imports`, not extraHomeModules. The Accessibility grant it needs to
# read window frames is a one-time bootstrap step (docs/runbooks/darwin-bootstrap.md).
{ config, ... }:
let
  tokens = import ../../lib/theme-tokens.nix { inherit config; };
  # RRGGBB token -> 0xAARRGGBB with an opaque alpha (the format borders expects).
  opaque = role: "0xff${role.hex}";
in
{
  services.jankyborders = {
    enable = true;
    active_color = opaque tokens.color.role.focus; # base0D — the tile that holds focus
    inactive_color = opaque tokens.color.role.muted; # base03 — inactive tiles
    # 6pt: thick enough to read at a glance, and the AeroSpace inner gap (16,
    # Carbon spacing-05) stays > 2× it so adjacent windows' borders never touch.
    width = 6.0;
    style = "round"; # echoes the niri / M3 rounded-corner language
    hidpi = true; # neptune is Retina — draw the border at native backing scale (crisp)
  };
}
