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
# (Ctrl+Opt), the macOS analogue of the Linux Ctrl+Alt — both read the
# single-sourced `tiers.hyper` constant from lib/capabilities.nix so the
# base shape is one edit (ADR-039 §4).
#
# Written via `xdg.configFile."karabiner/karabiner.json"` with
# `force = true`: home-manager unconditionally overwrites the file
# on every activation, clobbering any runtime writes from the
# Karabiner-Elements first-launch normalizer (or, defensively, from
# a future Karabiner release that seeds a new top-level key beyond
# `global` / `complex_modifications.parameters`). Without force,
# two distinct failure modes apply: (a) at runtime, Karabiner's
# write attempt EACCES against the read-only symlink and the
# normalizer may degrade or quit; (b) on next activation,
# home-manager's pre-link collision check refuses to clobber the
# non-HM file karabiner has produced and aborts with "Existing
# file '...' would be clobbered". force=true skips (b) — and the
# scaffolding below addresses (a) belt-and-braces. UI / Preferences
# edits do not survive activation — edit this file to change the
# config, not the Karabiner-Elements Preferences UI.
#
# `xdg.configFile` is the idiomatic home-manager path for
# `~/.config/<name>` writes; it resolves to the same on-disk
# location as a `home.file.".config/<name>"` write but threads
# through xdg.configHome (which home-manager defaults to ~/.config
# on both Linux and Darwin). The two were interchangeable here
# pre-conversion; the change is for shape-consistency with
# home/darwin/macchina-shell-init.nix and home/shared/* modules.
{ lib, ... }:
let
  caps = import ../../lib/capabilities.nix { inherit lib; };

  # The Hyper base modifiers, single-sourced from the registry
  # (tiers.hyper.darwin = [ "Ctrl" "Option" ]; ADR-039 §4). Mapped to
  # Karabiner's left-side modifier codes. The base-shape change (e.g. adding
  # an AltGr pad) is one edit in lib/capabilities.nix, mirrored on the niri
  # side by modules/nixos/keyd.nix reading tiers.hyper.linux.
  karabinerMod = {
    Ctrl = "left_control";
    Option = "left_option";
    Super = "left_command";
    Shift = "left_shift";
  };
  hyperModifiers = map (m: karabinerMod.${m}) caps.tiers.hyper.darwin; # [ left_control left_option ]

  # Caps Lock → Hyper (Ctrl+Opt). Holds the first Hyper modifier as the `to`
  # key_code and the rest as its modifiers, so caps_lock-held presents the
  # full Ctrl+Opt modifier state (same shape as the previous four-mod rule,
  # which held left_shift as key_code + cmd/ctrl/option as modifiers).
  # modifiers.optional = ["any"] lets the remap fire regardless of which other
  # modifiers happen to be held — defensive against future chord extensions.
  capsLockToHyper = {
    description = "Caps Lock → Hyper (Ctrl+Opt)";
    manipulators = [
      {
        type = "basic";
        from = {
          key_code = "caps_lock";
          modifiers.optional = [ "any" ];
        };
        to = [
          {
            key_code = lib.head hyperModifiers;
            modifiers = lib.tail hyperModifiers;
          }
        ];
      }
    ];
  };

  # Helper: build the `from` half of a "Hyper + key" mandatory match. Both
  # Hyper modifiers (Ctrl+Opt) must be held; Karabiner consumes them on match,
  # so the emitted `to` event carries only the modifiers we list there. This
  # relies on Karabiner counting the key_code-as-modifier (left_control,
  # emitted by capsLockToHyper) toward a `mandatory` match the same way it
  # counted the previous rule's left_shift — verify at the neptune keyboard
  # (it cannot be exercised from Linux).
  fromHyper = keyCode: {
    key_code = keyCode;
    modifiers.mandatory = hyperModifiers;
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
  # The arrow key set is single-sourced from the registry
  # (caps.karabinerHyperRemapKeys.arrows) so this production and the darwin
  # collision lint that reserves these chords cannot drift (#455). Tokens are
  # the registry's chord-key form ("Left"); the key_code is the lowercased
  # "<arrow>_arrow".
  hyperArrowMissionControl = {
    description = "Hyper + Arrow → Ctrl + Arrow (Mission Control family)";
    manipulators = builtins.map (
      arrow:
      let
        k = "${lib.toLower arrow}_arrow";
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
    ) caps.karabinerHyperRemapKeys.arrows;
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
  # The number key set is single-sourced from the registry
  # (caps.karabinerHyperRemapKeys.numbers, the strings "1"–"9") so this
  # production and the darwin collision lint cannot drift (#455).
  hyperNumberSpaceJump = {
    description = "Hyper + N → Ctrl + N (Mission Control Spaces 1-9)";
    manipulators = builtins.map (k: {
      type = "basic";
      from = fromHyper k;
      to = [
        {
          key_code = k;
          modifiers = [ "left_control" ];
        }
      ];
    }) caps.karabinerHyperRemapKeys.numbers;
  };

  karabinerConfig = {
    # Pre-populate the `global` key Karabiner-Elements expects at
    # first-launch normalization. Belt-and-braces with `force = true`
    # on the xdg.configFile entry below: force=true keeps the *next*
    # activation succeeding after Karabiner has clobbered the file,
    # but this scaffolding closes the user-visible gap in between —
    # without it, Karabiner's rewrite would strip the caps_lock →
    # Hyper rule (and every other manipulator we ship), silently
    # disabling the operator's keybinds until the next `nh darwin
    # switch`. Same defensive purpose as the
    # `complex_modifications.parameters` block below.
    global = {
      # Hide the menu-bar status item (Karabiner default is true). The
      # shipped manipulators run headless — caps_lock → Hyper and the
      # Mission Control remaps need no menu interaction — so the icon is
      # pure clutter. See docs/desktop/karabiner.md §Configuration.
      show_in_menu_bar = false;
    };
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
  xdg.configFile."karabiner/karabiner.json" = {
    text = builtins.toJSON karabinerConfig;
    force = true;
  };
}
