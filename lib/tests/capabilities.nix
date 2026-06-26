# Unit tests for lib/capabilities.nix's real codegen logic — chord rendering
# (niri + darwin), the niri + Hammerspoon emitters, and the collision lints. A
# silent bug in any of these would mis-generate every bind or let a chord clash
# slip through CI. Evaluated via pkgs.lib.runTests, which returns a list of
# failure records ({ name; expected; result; }); parts/checks.nix renders that
# list into a CI-gated derivation. See ADR-033 and lib/tests/auto-gen-paths.nix.
{ lib }:
let
  caps = import ../capabilities.nix { inherit lib; };
  inherit (caps)
    niriChord
    niriBindsFor
    darwinChord
    hammerspoonBindsFor
    collisionsFor
    darwinCollisionsFor
    descriptiveFor
    ;

  # A minimal niri-action capability for fixtures.
  mkCap = id: chord: action: {
    inherit id chord;
    label = id;
    description = id;
    keywords = [ ];
    platforms.linux = {
      realization = "niri-action";
      inherit action;
    };
  };

  # A minimal hammerspoon-handler capability for darwin fixtures.
  mkHsCap = id: chord: handler: {
    inherit id chord;
    label = id;
    description = id;
    keywords = [ ];
    platforms.darwin = {
      realization = "hammerspoon-handler";
      inherit handler;
    };
  };
in
lib.runTests {
  # Base tier renders to just the tier's modifiers plus the key.
  testNiriChordBase = {
    expr = niriChord {
      tier = "hyper";
      key = "Left";
    };
    expected = "Ctrl+Alt+Left";
  };

  # The Super escalator maps to niri's "Mod"; modifiers render in canonical order
  # (Mod, Ctrl, Alt, Shift), so the set — not declaration order — fixes the string.
  testNiriChordSuperEscalator = {
    expr = niriChord {
      tier = "hyper";
      mods = [ "Super" ];
      key = "Left";
    };
    expected = "Mod+Ctrl+Alt+Left";
  };

  # The Shift escalator stays literal.
  testNiriChordShiftEscalator = {
    expr = niriChord {
      tier = "hyper";
      mods = [ "Shift" ];
      key = "Up";
    };
    expected = "Ctrl+Alt+Shift+Up";
  };

  # The emitter keys each bind by its rendered chord and wraps the typed action
  # attrset under `action` — exactly a hand-authored niri bind's shape.
  testNiriBindsShape = {
    expr = niriBindsFor [
      (mkCap "focus-column-left" {
        tier = "hyper";
        key = "Left";
      } { focus-column-left = { }; })
    ];
    expected = {
      "Ctrl+Alt+Left".action.focus-column-left = { };
    };
  };

  # A clean registry produces no collision failures.
  testCollisionsCleanIsEmpty = {
    expr = collisionsFor [
      (mkCap "a" {
        tier = "hyper";
        key = "Left";
      } { focus-column-left = { }; })
      (mkCap "b" {
        tier = "hyper";
        key = "Right";
      } { focus-column-right = { }; })
    ];
    expected = [ ];
  };

  # Two capabilities resolving to one chord is reported (the round-trip proof:
  # the lint fires on a deliberate clash).
  testCollisionsDuplicateFires = {
    expr = builtins.length (collisionsFor [
      (mkCap "a" {
        tier = "hyper";
        key = "X";
      } { foo = { }; })
      (mkCap "b" {
        tier = "hyper";
        key = "X";
      } { bar = { }; })
    ]);
    expected = 1;
  };

  # The bare Ctrl+Alt base binding the F-row is reported (ADR-039 §8 reservation).
  testCollisionsFRowFires = {
    expr = builtins.length (collisionsFor [
      (mkCap "vt" {
        tier = "hyper";
        key = "F1";
      } { foo = { }; })
    ]);
    expected = 1;
  };

  # An *escalated* F-row chord (Ctrl+Alt+Shift+F1) is bindable — not the bare VT
  # switch — so it must NOT trip the reservation.
  testCollisionsFRowEscalatedOk = {
    expr = collisionsFor [
      (mkCap "esc" {
        tier = "hyper";
        mods = [ "Shift" ];
        key = "F1";
      } { foo = { }; })
    ];
    expected = [ ];
  };

  # Two caps with the same modifier SET in different declaration order resolve to
  # one chord and are reported (the canonical-sort dedup guarantee).
  testCollisionsModOrderDedup = {
    expr = builtins.length (collisionsFor [
      (mkCap "a" {
        tier = "hyper";
        mods = [
          "Shift"
          "Super"
        ];
        key = "Z";
      } { foo = { }; })
      (mkCap "b" {
        tier = "hyper";
        mods = [
          "Super"
          "Shift"
        ];
        key = "Z";
      } { bar = { }; })
    ]);
    expected = 1;
  };

  # Per-platform override wins for the fields it sets; the rest fall back to the
  # shared default.
  testDescriptiveOverride = {
    expr = descriptiveFor "darwin" {
      id = "x";
      label = "L";
      description = "D";
      keywords = [ "k" ];
      platforms.darwin.description = "DD";
    };
    expected = {
      label = "L";
      description = "DD";
      keywords = [ "k" ];
    };
  };

  # A platform with no override falls back entirely to the shared default.
  testDescriptiveFallback = {
    expr = descriptiveFor "linux" {
      id = "x";
      label = "L";
      description = "D";
      keywords = [ "k" ];
      platforms.darwin.description = "DD";
    };
    expected = {
      label = "L";
      description = "D";
      keywords = [ "k" ];
    };
  };

  # Guard: the live registry stays collision-free (a real clash should fail this
  # in CI, not just the fixture above).
  testLiveRegistryClean = {
    expr = caps.collisions;
    expected = [ ];
  };

  # ── darwin chord rendering (Hammerspoon) ──────────────────────────────────
  # Base tier renders to the hs mod tokens (Ctrl+Opt → ctrl+alt) plus the key,
  # letters lowercased.
  testDarwinChordBase = {
    expr = darwinChord {
      tier = "hyper";
      key = "F";
    };
    expected = "ctrl+alt+f";
  };

  # Arrows map to hs's explicit key names.
  testDarwinChordArrow = {
    expr = darwinChord {
      tier = "hyper";
      key = "Left";
    };
    expected = "ctrl+alt+left";
  };

  # Punctuation tokens map to the literal hs symbol.
  testDarwinChordPunct = {
    expr = darwinChord {
      tier = "hyper";
      key = "Minus";
    };
    expected = "ctrl+alt+-";
  };

  # The Super escalator maps to hs "cmd"; mods render in canonical order
  # (ctrl, alt, cmd, shift), so the set — not declaration order — fixes the string.
  testDarwinChordSuperEscalator = {
    expr = darwinChord {
      tier = "hyper";
      mods = [ "Super" ];
      key = "Up";
    };
    expected = "ctrl+alt+cmd+up";
  };

  # The emitter renders each hammerspoon-handler cap to one hs.hotkey.bind line:
  # a Lua mods table, the key string, and the bare handler name.
  testHammerspoonBindsShape = {
    expr = hammerspoonBindsFor [
      (mkHsCap "fullscreen-window" {
        tier = "hyper";
        key = "F";
      } "fullscreenWindow")
    ];
    expected = ''hs.hotkey.bind({ "ctrl", "alt" }, "f", fullscreenWindow)'';
  };

  # A clean darwin registry produces no collision failures.
  testDarwinCollisionsCleanIsEmpty = {
    expr = darwinCollisionsFor [
      (mkHsCap "a" {
        tier = "hyper";
        key = "F";
      } "fullscreenWindow")
      (mkHsCap "b" {
        tier = "hyper";
        key = "M";
      } "maximizeToFrame")
    ];
    expected = [ ];
  };

  # Two hammerspoon-handlers resolving to one chord is reported.
  testDarwinCollisionsDuplicateFires = {
    expr = builtins.length (darwinCollisionsFor [
      (mkHsCap "a" {
        tier = "hyper";
        key = "F";
      } "fullscreenWindow")
      (mkHsCap "b" {
        tier = "hyper";
        key = "F";
      } "other")
    ]);
    expected = 1;
  };

  # A handler landing on a Karabiner substrate-reserved chord (Ctrl+Opt+arrow /
  # Ctrl+Opt+number) is reported — the cross-emitter guard (ADR-039 §4/§8) that
  # protects the deferred directional-focus slice from silently double-binding.
  testDarwinReservedArrowFires = {
    expr = builtins.length (darwinCollisionsFor [
      (mkHsCap "focus-left" {
        tier = "hyper";
        key = "Left";
      } "focusWindowWest")
    ]);
    expected = 1;
  };

  testDarwinReservedNumberFires = {
    expr = builtins.length (darwinCollisionsFor [
      (mkHsCap "geo-1" {
        tier = "hyper";
        key = "1";
      } "someHandler")
    ]);
    expected = 1;
  };

  # An *escalated* chord on a reserved key (Ctrl+Opt+Shift+Left) is NOT the
  # bare reserved chord, so it must not trip the reservation.
  testDarwinReservedEscalatedOk = {
    expr = darwinCollisionsFor [
      (mkHsCap "esc" {
        tier = "hyper";
        mods = [ "Shift" ];
        key = "Left";
      } "someHandler")
    ];
    expected = [ ];
  };

  # Guard: the live darwin registry stays collision-free (and clear of the
  # Karabiner-reserved chords) — a real clash should fail this in CI.
  testLiveRegistryCleanDarwin = {
    expr = caps.darwinCollisions;
    expected = [ ];
  };

  # The spawn binds (Hyper+Return/B) are now routed through the Hammerspoon
  # emitter (#455), so the live darwin output binds them by handler name — proof
  # the chords are emitted (and therefore seen by darwinCollisions), not bound
  # by hand outside the lint's view.
  testLiveRegistryEmitsSpawnDarwinBinds = {
    expr = lib.all (s: lib.hasInfix s caps.hammerspoonBinds) [
      ''"return", ghosttyNewWindow''
      ''"b", chromeFocusOrNew''
    ];
    expected = true;
  };

  # The Karabiner substrate-reserved key set is exported for karabiner.nix to
  # generate its remaps from — the single-source bridge (#455). Guards the
  # contract shape karabiner.nix depends on; the darwin lint reserves the same
  # chords from this list, so the two cannot drift.
  testKarabinerHyperRemapKeys = {
    expr = caps.karabinerHyperRemapKeys;
    expected = {
      arrows = [
        "Left"
        "Right"
        "Up"
        "Down"
      ];
      numbers = [
        "1"
        "2"
        "3"
        "4"
        "5"
        "6"
        "7"
        "8"
        "9"
      ];
    };
  };

  # ── keybinds.md table emitter (#457) ──────────────────────────────────────
  # The friendly tier-form chord (Hyper+key), the doc's vocabulary — distinct
  # from the niri/darwin literals that feed the configs. Arrows become glyphs.
  testTierChordDisplayBase = {
    expr = caps.tierChordDisplay {
      tier = "hyper";
      key = "Left";
    };
    expected = "Hyper+←";
  };

  # The Shift escalator is the "move" tier; renders before the key.
  testTierChordDisplayShift = {
    expr = caps.tierChordDisplay {
      tier = "hyper";
      mods = [ "Shift" ];
      key = "Right";
    };
    expected = "Hyper+Shift+→";
  };

  # The Super escalator stays literal (the doc's term), not niri's "Mod".
  testTierChordDisplaySuper = {
    expr = caps.tierChordDisplay {
      tier = "hyper";
      mods = [ "Super" ];
      key = "Up";
    };
    expected = "Hyper+Super+↑";
  };

  # One base cap renders header + separator + a single labelled row, using the
  # per-platform label (mkCap sets both to the id).
  testKeybindsTableBaseRow = {
    expr = caps.keybindsTableFor [
      (mkCap "x" {
        tier = "hyper";
        key = "Left";
      } { a = { }; })
    ];
    expected = lib.concatStringsSep "\n" [
      "| Chord | niri | macOS |"
      "|---|---|---|"
      "| `Hyper+←` | x | x |"
    ];
  };

  # A 1‑9 digit family collapses to ONE row (header + separator + one row = 3
  # lines), not nine — the generated-range rule.
  testKeybindsTableDigitCollapsesToOneRow = {
    expr = builtins.length (
      lib.splitString "\n" (
        caps.keybindsTableFor (
          map (
            n:
            mkCap "focus-workspace-${toString n}" {
              tier = "hyper";
              key = toString n;
            } { focus = n; }
          ) (lib.range 1 9)
        )
      )
    );
    expected = 3;
  };

  # The collapsed row's label substitutes the numeral with "N".
  testKeybindsTableDigitLabelGetsN = {
    expr = lib.hasInfix "focus-workspace-N" (
      caps.keybindsTableFor (
        map (
          n:
          mkCap "focus-workspace-${toString n}" {
            tier = "hyper";
            key = toString n;
          } { focus = n; }
        ) (lib.range 1 9)
      )
    );
    expected = true;
  };

  # Guard the live re-bind (#457): move-to-workspace sits on the Hyper+Shift
  # "move" tier, never on Hyper+Super.
  testLiveKeybindsTableMoveToWorkspaceOnShift = {
    expr = {
      onShift = lib.hasInfix "Hyper+Shift+1" caps.keybindsTable;
      onSuper = lib.hasInfix "Hyper+Super+1" caps.keybindsTable;
    };
    expected = {
      onShift = true;
      onSuper = false;
    };
  };
}
