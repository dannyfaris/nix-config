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
# Two groups:
#
#   1. Screenshots (IDs 28-31) — swapped from the macOS factory default so
#      *copy to clipboard* is the accessible bare-⌘⇧ chord and *save to
#      file* takes ⌃⌘⇧ (the default has these the other way round). Matches
#      the niri side, where the bare Mod+Shift+N chords are the clipboard
#      captures. The save location (~/Pictures/Screenshots) is a separate
#      domain — see modules/darwin/system-prefs.nix.
#
#   2. Switch to Desktop N (IDs 118-121 = Desktops 1-4, 190-194 = 5-9) —
#      Ctrl+1..9, declared *enabled*. macOS leaves these disabled by
#      default; declaring them folds in what was a one-time manual
#      System-Settings step (the repo's no-manual-state stance), and is what
#      the Karabiner Hyper+N → Ctrl+N remap targets.
#
# Parameter triple: [ ascii-code  virtual-key-code  modifier-mask ].
# Mask bits: Shift 131072, Control 262144, Option 524288, Command 1048576
# (summed for combos). Number-key virtual codes: 1=18 2=19 3=20 4=21 5=23
# 6=22 7=26 8=28 9=25.
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
  ctrl = 262144;
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

    # Switch to Desktop N — Ctrl+1..9, declared enabled.
    "118" = hotkey [
      49
      18
      ctrl
    ]; # Desktop 1 (⌃1)
    "119" = hotkey [
      50
      19
      ctrl
    ]; # Desktop 2 (⌃2)
    "120" = hotkey [
      51
      20
      ctrl
    ]; # Desktop 3 (⌃3)
    "121" = hotkey [
      52
      21
      ctrl
    ]; # Desktop 4 (⌃4)
    "190" = hotkey [
      53
      23
      ctrl
    ]; # Desktop 5 (⌃5)
    "191" = hotkey [
      54
      22
      ctrl
    ]; # Desktop 6 (⌃6)
    "192" = hotkey [
      55
      26
      ctrl
    ]; # Desktop 7 (⌃7)
    "193" = hotkey [
      56
      28
      ctrl
    ]; # Desktop 8 (⌃8)
    "194" = hotkey [
      57
      25
      ctrl
    ]; # Desktop 9 (⌃9)
  };
}
