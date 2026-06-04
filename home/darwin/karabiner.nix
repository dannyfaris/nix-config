# Karabiner-Elements declarative config on Darwin. The .app + DriverKit
# system extension + privileged launchd jobs are installed via the
# Homebrew cask declared in modules/darwin/homebrew.nix (ADR-031
# clause 2: pkgs.karabiner-elements cannot drive macOS's
# system-extension + privileged-pkg-installer flow from the nix store).
# This file owns ~/.config/karabiner/karabiner.json.
#
# See docs/desktop/karabiner.md for selection rationale, the
# system-extension + Input Monitoring TCC ceremony, the pkg-enclosure
# Sparkle update caveat, and verification commands. The shipped rules
# are enumerated in docs/desktop/keybinds.md §"Active bindings —
# macOS clients"; this file's job is to realize them as
# complex_modifications. The foundational rule is caps_lock → Hyper
# (⌘⌃⌥⇧), the macOS analogue of the Linux Super + Ctrl + Alt + Shift.
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

  # Helper: build the `from` half of a "Hyper + key" mandatory match.
  # All four modifiers must be held (Karabiner consumes them on
  # match, so the emitted `to` event carries only the modifiers we
  # explicitly list there). The four-modifier state is produced by
  # the capsLockToHyper rule above: emitting key_code = "left_shift"
  # with cmd + ctrl + option as modifiers puts shift down on the
  # active modifier state, satisfying the four-mandatory match.
  fromHyper = keyCode: {
    key_code = keyCode;
    modifiers.mandatory = [
      "left_command"
      "left_control"
      "left_option"
      "left_shift"
    ];
  };

  # Hyper + Arrow → Ctrl + Arrow, for macOS's Mission Control family:
  #
  #   left/right  →  "Move to space left/right" (symbolichotkey IDs 79/81)
  #   up          →  "Mission Control" overview (ID 32)
  #   down        →  "Application windows" exposé (ID 33)
  #
  # `mandatory` modifiers are consumed by the rule, so the emitted
  # event is a clean Ctrl+Arrow — macOS sees its own shortcut and
  # runs the native handler. This piggybacks on the OS keybindings
  # at System Settings → Keyboard → Keyboard Shortcuts → Mission
  # Control; disabling any of those rows there makes the
  # corresponding arrow a no-op. All four are enabled by macOS
  # default. See docs/desktop/keybinds.md §Mission Control for the
  # bind-manifest entries.
  hyperArrowMissionControl = {
    description = "Hyper + Arrow → Ctrl + Arrow (Mission Control family)";
    manipulators =
      builtins.map
        (arrow: {
          type = "basic";
          from = fromHyper "${arrow}_arrow";
          to = [
            {
              key_code = "${arrow}_arrow";
              modifiers = [ "left_control" ];
            }
          ];
        })
        [
          "left"
          "right"
          "up"
          "down"
        ];
  };

  # Hyper + N → Ctrl + N, for macOS Mission Control's native "Switch
  # to Desktop N" (N = 1..9). Same remap mechanism as the arrow rule
  # above — `mandatory` modifiers are consumed and the emitted event
  # is a clean Ctrl+N. Piggybacks on System Settings → Keyboard →
  # Keyboard Shortcuts → Mission Control → "Switch to Desktop N";
  # the operator must check those boxes for each N they want
  # navigable (the macOS defaults disable them out of the box, and
  # only expose slots for as many Spaces as currently exist).
  # Mirrors the niri-side `Mod+1` … `Mod+9` focus-workspace binds.
  # See docs/desktop/keybinds.md §Mission Control.
  hyperNumberSpaceJump = {
    description = "Hyper + N → Ctrl + N (Mission Control Spaces 1-9)";
    manipulators =
      builtins.map
        (
          n:
          let
            k = toString n;
          in
          {
            type = "basic";
            from = fromHyper k;
            to = [
              {
                key_code = k;
                modifiers = [ "left_control" ];
              }
            ];
          }
        )
        [
          1
          2
          3
          4
          5
          6
          7
          8
          9
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
          rules = [
            capsLockToHyper
            hyperArrowMissionControl
            hyperNumberSpaceJump
          ];
        };
      }
    ];
  };
in
{
  home.file.".config/karabiner/karabiner.json".text = builtins.toJSON karabinerConfig;
}
