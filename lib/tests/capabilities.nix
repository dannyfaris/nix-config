# Unit tests for lib/capabilities.nix's real codegen logic — chord rendering,
# the niri emitter, and the collision lint. A silent bug in any of these would
# mis-generate every niri bind or let a chord clash slip through CI. Evaluated
# via pkgs.lib.runTests, which returns a list of failure records
# ({ name; expected; result; }); parts/checks.nix renders that list into a
# CI-gated derivation. See ADR-033 and lib/tests/auto-gen-paths.nix.
{ lib }:
let
  caps = import ../capabilities.nix { inherit lib; };
  inherit (caps)
    niriChord
    niriBindsFor
    collisionsFor
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
}
