# Unit tests for lib/capabilities.nix's real codegen logic — chord rendering
# (niri + AeroSpace), the niri + AeroSpace emitters, and the collision lints. A
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
    aerospaceChord
    aerospaceBindsFor
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

  # A minimal aerospace-action capability (emitted verbatim) for darwin fixtures.
  mkAsCap = id: chord: action: {
    inherit id chord;
    label = id;
    description = id;
    keywords = [ ];
    platforms.darwin = {
      realization = "aerospace-action";
      inherit action;
    };
  };

  # An aerospace-exec capability (hand-authored body in aerospace.nix; the
  # emitter skips it but the collision lint counts its chord — the merged
  # namespace, ADR-040 / #494).
  mkAsExecCap = id: chord: {
    inherit id chord;
    label = id;
    description = id;
    keywords = [ ];
    platforms.darwin.realization = "aerospace-exec";
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

  # ── AeroSpace chord rendering (ADR-040) ───────────────────────────────────
  # Base tier renders to the darwin mod tokens (Ctrl+Opt → ctrl-alt), hyphen-
  # joined, key lowercased.
  testAerospaceChordBase = {
    expr = aerospaceChord {
      tier = "hyper";
      key = "F";
    };
    expected = "ctrl-alt-f";
  };

  # Arrows map to AeroSpace's explicit key names.
  testAerospaceChordArrow = {
    expr = aerospaceChord {
      tier = "hyper";
      key = "Left";
    };
    expected = "ctrl-alt-left";
  };

  # Return maps to AeroSpace's `enter` (verified against the pinned
  # keysMap.swift) — a wrong key name is a whole-config parse error.
  testAerospaceChordReturn = {
    expr = aerospaceChord {
      tier = "hyper";
      key = "Return";
    };
    expected = "ctrl-alt-enter";
  };

  # Punctuation tokens map to AeroSpace's key names (not literal symbols).
  testAerospaceChordPunct = {
    expr = aerospaceChord {
      tier = "hyper";
      key = "Comma";
    };
    expected = "ctrl-alt-comma";
  };

  # The Super escalator maps to "cmd"; mods render in canonical order
  # (ctrl, alt, cmd, shift), so the set — not declaration order — fixes the string.
  testAerospaceChordSuperEscalator = {
    expr = aerospaceChord {
      tier = "hyper";
      mods = [ "Super" ];
      key = "Up";
    };
    expected = "ctrl-alt-cmd-up";
  };

  # The emitter keys each aerospace-action bind by its rendered chord and maps
  # it to the verbatim command string — exactly a mode.main.binding entry.
  testAerospaceBindsShape = {
    expr = aerospaceBindsFor [
      (mkAsCap "focus-window-up" {
        tier = "hyper";
        key = "Up";
      } "focus up")
    ];
    expected = {
      "ctrl-alt-up" = "focus up";
    };
  };

  # aerospace-exec caps are NOT emitted (their body is hand-authored in
  # aerospace.nix) — the emitter's output omits them.
  testAerospaceBindsSkipsExec = {
    expr = aerospaceBindsFor [
      (mkAsExecCap "maximise-by-isolation" {
        tier = "hyper";
        mods = [ "Shift" ];
        key = "M";
      })
    ];
    expected = { };
  };

  # A clean darwin registry produces no collision failures.
  testDarwinCollisionsCleanIsEmpty = {
    expr = darwinCollisionsFor [
      (mkAsCap "a" {
        tier = "hyper";
        key = "F";
      } "exec-and-forget open -a Finder")
      (mkAsCap "b" {
        tier = "hyper";
        key = "M";
      } "exec-and-forget open -a Messages")
    ];
    expected = [ ];
  };

  # Two aerospace-action binds resolving to one chord is reported.
  testDarwinCollisionsDuplicateFires = {
    expr = builtins.length (darwinCollisionsFor [
      (mkAsCap "a" {
        tier = "hyper";
        key = "F";
      } "exec-and-forget open -a Finder")
      (mkAsCap "b" {
        tier = "hyper";
        key = "F";
      } "focus up")
    ]);
    expected = 1;
  };

  # The MERGED namespace is linted: an emitted (aerospace-action) bind and a
  # hand-authored (aerospace-exec) bind resolving to the same chord is reported.
  # This is the Stage-1 requirement (#494) — a hand-authored complex bind can't
  # silently double-bind a chord the emitter already claims.
  testDarwinCollisionsMergedNamespaceFires = {
    expr = builtins.length (darwinCollisionsFor [
      (mkAsCap "emitted" {
        tier = "hyper";
        mods = [ "Shift" ];
        key = "M";
      } "move up")
      (mkAsExecCap "hand-authored" {
        tier = "hyper";
        mods = [ "Shift" ];
        key = "M";
      })
    ]);
    expected = 1;
  };

  # Guard: the live darwin registry stays collision-free across the merged
  # namespace — a real clash should fail this in CI.
  testLiveRegistryCleanDarwin = {
    expr = caps.darwinCollisions;
    expected = [ ];
  };

  # The spawn binds (Hyper+Return/B) are emitted as aerospace-action values, so
  # the live darwin output binds them (and darwinCollisions sees the chords).
  # Ghostty spawns a new window via `open -na`; Chrome focus-or-launches via
  # `open -a` (ADR-040).
  testLiveRegistryEmitsSpawnDarwinBinds = {
    expr = {
      ghostty = caps.aerospaceBinds."ctrl-alt-enter" or null;
      chrome = caps.aerospaceBinds."ctrl-alt-b" or null;
    };
    expected = {
      ghostty = "exec-and-forget open -na Ghostty.app";
      chrome = ''exec-and-forget open -a "Google Chrome"'';
    };
  };

  # The Karabiner Mission-Control / Space-jump remaps are retired (ADR-040):
  # karabinerHyperRemapKeys is emptied permanently so Hyper+arrows / Hyper+1‑9
  # fall through to AeroSpace. karabiner.nix still reads this (now-empty) attr.
  testKarabinerHyperRemapKeys = {
    expr = caps.karabinerHyperRemapKeys;
    expected = {
      arrows = [ ];
      numbers = [ ];
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

  # One base cap renders header + separator + a single labelled row. mkCap is
  # niri-only (no darwin realization), so the macOS column renders "—" (ADR-040
  # made the table show "—" for an unrealized platform).
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
      "| `Hyper+←` | x | — |"
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
