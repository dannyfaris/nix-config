# foot — fast, lightweight, Wayland-native terminal emulator.
#
# Colours come from the theme-menu conductor, not Noctalia (ADR-044, #609).
# foot's palette include is the per-target resolved symlink managed by
# home/nixos/theme-menu.nix's activation seed + the `theme` CLI. We declare
# the `include` here rather than relying on any runtime hook — it can't edit
# foot.ini while it's a read-only home-manager symlink. (foot treats a missing
# include as a fatal config error exit 230 — the seed activation guarantees the
# path exists before any foot window can spawn; see theme-menu.nix.)
#
# R4 guard: NEVER set initial-color-theme anywhere in foot's config. The
# theme-menu renders BOTH polarities under [colors-dark] section headers (foot's
# active mode never flips; the conductor swaps file content). Setting
# initial-color-theme=light would invert the [colors-dark]-header convention and
# render the wrong polarity's colours. See docs/desktop/foot.md.
#
# Font + dpi-aware are set here because Noctalia's templating is colour-only:
# the face is the `monospace` fontconfig generic, resolved by the conductor
# (so a user ~/.config/fontconfig override remaps it live — docs/desktop/
# fonts.md), size from the active display profile (lib/display-profiles.nix).
# foot's `dpi-aware = "no"` honours pt-based font sizing but disables
# per-monitor DPI scaling — kept so the profile's pt sizes render as calibrated.
#
# Lives under nixos/ because foot is Wayland-only and doesn't compile
# off Linux — there is no cross-platform variant to share. macOS hosts
# get Ghostty instead (home/darwin/ghostty.nix + the `ghostty` cask in
# modules/darwin/homebrew.nix); the server-side terminfo for
# Ghostty (xterm-ghostty) lives at modules/nixos/ghostty-terminfo.nix
# and ships on every NixOS host so SSH'ing into any NixOS host from a
# Ghostty-on-Mac terminal renders cleanly. (NixOS-only because
# `pkgs.ghostty` doesn't ship on aarch64-darwin; Darwin SSH targets
# rely on Ghostty's shell-integration ssh-terminfo push instead.)
#
# Per ADR-028 (Implementation amendment — terminal swapped from Ghostty
# to Foot, 2026-05-28); theming moved to Noctalia per ADR-036.
_:
let
  profile = import ../../lib/display-profiles.nix; # active display profile — terminal size
in
{
  programs.foot = {
    enable = true;
    settings.main = {
      font = "monospace:size=${toString profile.fonts.terminal}";
      "dpi-aware" = "no";
      # theme-menu conductor's per-target resolved symlink (see header). foot expands ~.
      include = "~/.local/state/theme-menu/foot.ini";
    };
    # Translucent background + compositor blur, matched to Ghostty's
    # background-opacity/blur on macOS for cross-terminal parity. blur needs
    # alpha < 1 and a compositor implementing ext-background-effect-v1
    # (niri ≥ 26.04). Set here in the HM-owned [colors-dark] block, not the
    # Noctalia include, so the palette refresh doesn't clobber them.
    settings."colors-dark" = {
      alpha = "0.9";
      blur = "yes";
    };
  };
}
