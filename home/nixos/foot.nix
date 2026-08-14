# foot — fast, lightweight, Wayland-native terminal emulator.
#
# Colours come from Noctalia's own native theme engine, not a Nix-rendered
# palette (ADR-048, reversing ADR-044/#609 for Linux — #819 Epic G,
# docs/design/noctalia-theming-delegation.md). This is a pre-declared
# MOUNT-POINT, not a runtime-hook edit: foot's builtin apply.sh (enabled via
# home/nixos/noctalia.nix's template whitelist) detects this include by a
# loose `grep 'include.*noctalia'` against foot.ini and, finding it present,
# writes ONLY its own theme file — never foot.ini itself (G3 spike,
# on-metal-confirmed both directions: include present → zero mutation;
# include absent → silent symlink materialization at the next `nh os
# switch`). foot treats a missing include as a fatal config error (exit
# 230); the target only exists once Noctalia has resolved a theme at least
# once — see docs/desktop/noctalia.md §Sharp edges for the state-between-
# `nh os switch`-and-Noctalia-restart hazard this opens.
#
# R4 guard: NEVER set initial-color-theme anywhere in foot's config. Noctalia's
# foot template renders BOTH polarities under a [colors-dark] section header
# (foot's active section never flips; Noctalia's own apply.sh rewrites the
# file's content in place on every resolve — same convention the retired
# conductor used). Setting initial-color-theme=light would invert that
# convention and render the wrong polarity's colours. See docs/desktop/foot.md.
#
# Font + dpi-aware are set here because Noctalia's templating is colour-only:
# the face is the `monospace` fontconfig generic, resolved by the conductor
# (so a user ~/.config/fontconfig override remaps it live — docs/desktop/
# fonts.md), size from the display calibration (lib/display-profiles.nix).
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
  profile = import ../../lib/display-profiles.nix; # display calibration — terminal size
in
{
  programs.foot = {
    enable = true;
    settings.main = {
      font = "monospace:size=${toString profile.fonts.terminal}";
      "dpi-aware" = "no";
      # Noctalia's foot builtin template output_path (see header). foot expands ~.
      include = "~/.config/foot/themes/noctalia";
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
