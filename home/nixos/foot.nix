# foot — fast, lightweight, Wayland-native terminal emulator.
#
# Colours come from Noctalia, not Stylix (ADR-036, #385). The Stylix `foot`
# target was removed; foot's palette lives in ~/.config/foot/themes/noctalia,
# which Noctalia writes at runtime and refreshes on a scheme/polarity change.
# We declare the `include` here rather than leaning on Noctalia's post-hook —
# it can't edit foot.ini while that's a read-only home-manager symlink, and a
# competing Stylix colour block in the same file would shadow the include
# anyway. See docs/desktop/noctalia.md §Configuration + §Sharp edges. (foot
# treats a missing include as a fatal config error, but Noctalia writes the
# file at runtime and it is present on metis; relevant only if templating is
# ever disabled.)
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
      # Noctalia's runtime-written colour theme (see header). foot expands ~.
      include = "~/.config/foot/themes/noctalia";
    };
    # Translucent background + compositor blur, matched to Ghostty's
    # background-opacity/blur on macOS for cross-terminal parity. blur needs
    # alpha < 1 and a compositor implementing ext-background-effect-v1
    # (niri ≥ 26.04). Set here in the HM-owned [colors] block, not the
    # Noctalia include, so the palette refresh doesn't clobber them.
    settings.colors = {
      alpha = "0.9";
      blur = "yes";
    };
  };
}
