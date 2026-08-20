# JankyBorders — the focused-window border for yabai-tiled windows on celaeno
# (ADR-047; originally added for AeroSpace, ADR-040 Stage 2, #494). Neither
# window manager draws active-window chrome of its own, so a border is what
# makes the focused tile legible; it is the macOS analogue of the window
# border niri draws (home/nixos/niri.nix).
#
# Active/inactive colours source from the shared design-token roles
# (lib/theme-tokens.nix — the `{ config }` half, since this is the one
# consumer that needs a role's resolved `.hex`; the roles themselves are
# declared in lib/static-tokens.nix): active = the focus role (base0D), inactive = muted
# (base03) — so the border speaks the repo's colour vocabulary
# (visual-identity.md §Colour). (This is role-parity, not wire-parity with niri:
# niri's border colour is Noctalia-driven at runtime, not token-sourced.)
# JankyBorders wants 0xAARRGGBB; the alpha stance is defined once at
# lib/static-tokens.nix (color.borderAlpha) and re-exported through
# theme-tokens.nix.
#
# This is a nix-darwin *system* service (launchd user agent, KeepAlive), not a
# home-manager module — hence it lives here and is imported in the host's
# system `imports`, not extraHomeModules. Needs no Accessibility (or any TCC)
# grant: by design borders tracks windows through the window-server API, not the
# AX API (that's its speed advantage), and `ax_focus` — the one option that would
# opt into the slower Accessibility path — is left off. See
# docs/runbooks/darwin-bootstrap.md for the window-management bootstrap (only
# yabai itself needs an Accessibility grant).
{ config, ... }:
let
  tokens = import ../../lib/theme-tokens.nix { inherit config; };
  # RRGGBB token -> 0xAARRGGBB (the format borders expects), alpha stated per state.
  withAlpha = alpha: role: "0x${alpha}${role.hex}";
in
{
  services.jankyborders = {
    enable = true;
    active_color = withAlpha tokens.color.borderAlpha.active tokens.color.role.focus; # base0D — the tile that holds focus
    inactive_color = withAlpha tokens.color.borderAlpha.inactive tokens.color.role.muted; # base03 — inactive tiles
    # 3pt: thick enough to read at a glance, and the yabai window_gap (16,
    # Carbon spacing-05) stays > 2× it so adjacent windows' borders never touch.
    width = 3.0;
    style = "round"; # echoes the niri / M3 rounded-corner language
    hidpi = true; # celaeno is Retina — draw the border at native backing scale (crisp)
  };
}
