# macOS keyboard shortcuts — the `com.apple.symbolichotkeys` plist domain.
#
# This module is the *authoritative* source for com.apple.symbolichotkeys
# on any Darwin host that imports it: nix-darwin writes the
# AppleSymbolicHotKeys dictionary wholesale (`defaults write` replaces the
# whole key, it does not merge), so any symbolic hotkey the operator wants
# customised must be declared here. Hotkeys *not* listed fall back to
# macOS's built-in defaults (e.g. Mission Control "Move left/right a space"
# stays at its default-enabled Ctrl+Arrow) — which is why only the entries
# we actively change appear below.
#
# Screenshots (IDs 28-31) — swapped from the macOS factory default so *copy
# to clipboard* is the accessible bare-⌘⇧ chord and *save to file* takes ⌃⌘⇧
# (the default has these the other way round). Matches the niri side, where
# the bare Mod+Shift+N chords are the clipboard captures. The save location
# (~/Pictures/Screenshots) is a separate domain — see
# modules/darwin/system-prefs.nix.
#
# Parameter triple: [ ascii-code  virtual-key-code  modifier-mask ].
# Mask bits: Shift 131072, Control 262144, Option 524288, Command 1048576
# (summed for combos). The screenshot keys 3/4 are virtual codes 20/21.
#
# `enabled` is the integer `1` — the value type the System Settings GUI
# writes for this domain; WindowServer reads symbolichotkeys strictly, so a
# CFBoolean can be ignored.
#
# Verification is on-Mac (like #282 for metis): nix can't apply or test this
# from Linux. After `darwin-rebuild switch` a re-login is needed for
# WindowServer to pick up symbolichotkeys changes. Confirm with `defaults
# read com.apple.symbolichotkeys` — and specifically re-check that the
# default Mission Control "Move left/right a space" / overview binds
# (Hyper+Left/Right/Up/Down) still work: writing AppleSymbolicHotKeys
# wholesale could drop their default-enabled entries (IDs 79/81/32/33),
# which are relied on but not declared here. See docs/desktop/keybinds.md
# §Screenshots + §Mission Control.
_:
let
  # A type=standard symbolic-hotkey entry.
  hotkey = parameters: {
    enabled = 1;
    value = {
      type = "standard";
      inherit parameters;
    };
  };
  shiftCmd = 1179648; # ⇧⌘
  ctrlShiftCmd = 1441792; # ⌃⇧⌘
in
{
  system.defaults.CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys = {
    # Screenshots — swapped: clipboard = bare ⌘⇧, file = ⌃⌘⇧.
    "28" = hotkey [
      51
      20
      ctrlShiftCmd
    ]; # screen → file (⌃⌘⇧3)
    "29" = hotkey [
      51
      20
      shiftCmd
    ]; # screen → clipboard (⌘⇧3)
    "30" = hotkey [
      52
      21
      ctrlShiftCmd
    ]; # area → file (⌃⌘⇧4)
    "31" = hotkey [
      52
      21
      shiftCmd
    ]; # area → clipboard (⌘⇧4)
  };
}
