# Karabiner-Elements declarative config on Darwin. The .app + DriverKit
# system extension + privileged launchd jobs are installed via the
# Homebrew cask declared in modules/darwin/homebrew.nix (ADR-031
# clause 2: pkgs.karabiner-elements cannot drive macOS's
# system-extension + privileged-pkg-installer flow from the nix store).
# This file owns ~/.config/karabiner/karabiner.json.
#
# See docs/desktop/karabiner.md for selection rationale, the
# system-extension + Input Monitoring TCC ceremony, the pkg-enclosure
# Sparkle update caveat, and verification commands. The single shipped
# rule realizes the Hyper modifier from docs/desktop/keybinds.md by
# remapping caps_lock to ⌘ + ⌃ + ⌥ + ⇧ (the macOS analogue of the
# Linux Super + Ctrl + Alt + Shift Hyper).
#
# Symlinked into the nix store and therefore read-only — edit this
# file to change the config; do not edit through the Karabiner-Elements
# Preferences UI. UI writes break the symlink and the change does not
# survive activation. Same posture as home/darwin/ghostty.nix.
_:
let
  # Caps Lock → Hyper. Sends left_shift held with left_command +
  # left_control + left_option, producing the four-modifier chord
  # Karabiner UI users know as "Hyper". modifiers.optional = ["any"]
  # lets the remap fire regardless of which other modifiers happen
  # to be held when caps_lock is pressed — defensive against future
  # chord-based extensions.
  capsLockToHyper = {
    description = "Caps Lock → Hyper (⌘⌃⌥⇧)";
    manipulators = [
      {
        type = "basic";
        from = {
          key_code = "caps_lock";
          modifiers.optional = [ "any" ];
        };
        to = [
          {
            key_code = "left_shift";
            modifiers = [
              "left_command"
              "left_control"
              "left_option"
            ];
          }
        ];
      }
    ];
  };

  karabinerConfig = {
    # Empty top-level `global` block neutralizes Karabiner-Elements'
    # first-launch config-normalization rewrite — Karabiner expects
    # this key to exist and will write a default if it's missing,
    # which fails against the read-only symlink. Same defensive
    # purpose as the `complex_modifications.parameters` block below.
    global = { };
    profiles = [
      {
        name = "Default";
        selected = true;
        # ANSI keyboard layout for the virtual HID device. Matches
        # the Magic Keyboard with Touch ID this host uses.
        virtual_hid_keyboard.keyboard_type_v2 = "ansi";
        complex_modifications = {
          # Empty parameters block; Karabiner fills in its compiled
          # defaults (basic.to_if_alone_timeout_milliseconds,
          # basic.simultaneous_threshold_milliseconds, etc.). Present
          # explicitly so that a future rule using `to_if_alone` /
          # `simultaneous` semantics has an obvious place to add
          # parameter overrides without changing the top-level shape.
          parameters = { };
          rules = [ capsLockToHyper ];
        };
      }
    ];
  };
in
{
  home.file.".config/karabiner/karabiner.json".text = builtins.toJSON karabinerConfig;
}
