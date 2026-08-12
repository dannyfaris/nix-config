# Unit tests for lib/capabilities.nix's real codegen logic — chord rendering
# (niri + skhd), the niri emitter, and the collision lints. A silent bug in
# any of these would mis-generate every bind or let a chord clash slip
# through CI. Evaluated via pkgs.lib.runTests, which returns a list of
# failure records ({ name; expected; result; }); parts/checks.nix renders that
# list into a CI-gated derivation. See ADR-033 and lib/tests/auto-gen-paths.nix.
{ lib }:
let
  caps = import ../capabilities.nix { inherit lib; };
  inherit (caps)
    niriChord
    niriBindsFor
    skhdChord
    skhdChordsFor
    skhdCollisionsFor
    collisionsFor
    validationFailuresFor
    descriptiveFor
    skhdKeyShapeFailuresFor
    renderedChordFailuresFor
    workspaceFamilyFailuresFor
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

  # A minimal skhd-exec capability (chord only — the body is hand-authored in
  # home/darwin/skhd.nix, ADR-047) for darwin fixtures.
  mkSkhdCap = id: chord: {
    inherit id chord;
    label = id;
    description = id;
    keywords = [ ];
    platforms.darwin.realization = "skhd-exec";
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

  # ── skhd chord rendering ────────────────────────────────────────────────────
  # skhd joins modifiers with " + " and separates the key with " - ".
  testSkhdChordBase = {
    expr = skhdChord {
      tier = "hyper";
      key = "B";
    };
    expected = "ctrl + alt - b";
  };

  testSkhdChordArrow = {
    expr = skhdChord {
      tier = "hyper";
      mods = [ "Shift" ];
      key = "Left";
    };
    expected = "ctrl + alt + shift - left";
  };

  # `return`, not AeroSpace's `enter` — skhd's own literal table.
  testSkhdChordReturn = {
    expr = skhdChord {
      tier = "hyper";
      key = "Return";
    };
    expected = "ctrl + alt - return";
  };

  # Punctuation has no literal spelling in skhd; it must render as an UPPERCASE
  # ANSI keycode. A lowercase hex digit would truncate in eat_hex and bind a
  # different key silently, so the case is asserted, not just the value.
  testSkhdChordPunctIsUppercaseHex = {
    expr = skhdChord {
      tier = "hyper";
      key = "Comma";
    };
    expected = "ctrl + alt - 0x2B";
  };

  testSkhdChordSuperEscalator = {
    expr = skhdChord {
      tier = "hyper";
      mods = [ "Super" ];
      key = "Up";
    };
    expected = "ctrl + alt + cmd - up";
  };

  # The emitter keys by capability id (not by chord — the module looks bodies up
  # by id): every darwin-realized cap is skhd-exec, so every one needs a chord
  # here regardless of how its body is authored.
  testSkhdChordsShape = {
    expr = skhdChordsFor [
      (mkSkhdCap "focus-window-up" {
        tier = "hyper";
        key = "Up";
      })
      (mkSkhdCap "maximise-by-isolation" {
        tier = "hyper";
        mods = [ "Shift" ];
        key = "M";
      })
    ];
    expected = {
      focus-window-up = "ctrl + alt - up";
      maximise-by-isolation = "ctrl + alt + shift - m";
    };
  };

  testSkhdCollisionsCleanIsEmpty = {
    expr = skhdCollisionsFor [
      (mkSkhdCap "a" {
        tier = "hyper";
        key = "A";
      })
      (mkSkhdCap "b" {
        tier = "hyper";
        key = "B";
      })
    ];
    expected = [ ];
  };

  # skhd resolves a duplicate chord silently first-wins with no diagnostic, so
  # this lint is the only thing standing between a collision and a dead bind.
  testSkhdCollisionsDuplicateFires = {
    expr = builtins.length (skhdCollisionsFor [
      (mkSkhdCap "a" {
        tier = "hyper";
        key = "A";
      })
      (mkSkhdCap "b" {
        tier = "hyper";
        key = "A";
      })
    ]);
    expected = 1;
  };

  # Declaration order of `mods` must not hide a collision: both render to the
  # same canonical string, so the lint must group them together.
  testSkhdCollisionsModOrderNormalised = {
    expr = builtins.length (skhdCollisionsFor [
      (mkSkhdCap "a" {
        tier = "hyper";
        mods = [
          "Shift"
          "Super"
        ];
        key = "A";
      })
      (mkSkhdCap "b" {
        tier = "hyper";
        mods = [
          "Super"
          "Shift"
        ];
        key = "A";
      })
    ]);
    expected = 1;
  };

  # Guard: the live darwin namespace stays collision-free (a real clash should
  # fail this in CI, not just the fixtures above).
  testLiveRegistrySkhdClean = {
    expr = caps.skhdCollisions;
    expected = [ ];
  };

  # Guard: the spawn chords are present in the live darwin output. This only
  # asserts the *chord* — the command bodies are asserted by skhd.nix's own
  # both-directions completeness throw (home/darwin/skhd.nix), not here.
  # Deliberately NOT a golden test over all live chords: chord-value drift is
  # gated by the keybinds-table CI diff (a human-visible doc change), and a
  # full golden attrset would tax every intentional remap (mutation audit A1).
  testLiveRegistryEmitsSpawnDarwinChords = {
    expr = {
      terminal = caps.skhdChords."spawn-terminal" or null;
      browser = caps.skhdChords."spawn-browser" or null;
    };
    expected = {
      terminal = "ctrl + alt - return";
      browser = "ctrl + alt - b";
    };
  };

  # The Karabiner Mission-Control / Space-jump remaps are retired (ADR-040):
  # karabinerHyperRemapKeys is emptied permanently so Hyper+arrows / Hyper+1‑9
  # fall through to the skhd keymap instead (ADR-047).
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

  # ── Registry shape validation (#535) ──────────────────────────────────────
  # A well-formed fixture produces no failures.
  testValidationCleanIsEmpty = {
    expr = validationFailuresFor [
      (mkCap "a" {
        tier = "hyper";
        key = "Left";
      } { focus-column-left = { }; })
    ];
    expected = [ ];
  };

  # The demonstrated silent-drop: a typo'd realization tag was invisible to
  # the emitters AND the collision lint; the validator names it.
  testValidationTypoRealizationFires = {
    expr = validationFailuresFor [
      (
        (mkCap "a" {
          tier = "hyper";
          key = "Left";
        } { focus-column-left = { }; })
        // {
          platforms.linux = {
            realization = "niri-actoin";
            action.focus-column-left = { };
          };
        }
      )
    ];
    expected = [ "a: unknown platforms.linux realization \"niri-actoin\" (known: niri-action)" ];
  };

  # A misspelled top-level field is caught by the whitelist (and the field it
  # displaced is caught as missing) — the `platfroms` typo class.
  testValidationUnknownTopFieldFires = {
    expr = validationFailuresFor [
      (
        builtins.removeAttrs (mkCap "a" {
          tier = "hyper";
          key = "Left";
        } { focus-column-left = { }; }) [ "platforms" ]
        // {
          platfroms.linux = {
            realization = "niri-action";
            action.focus-column-left = { };
          };
        }
      )
    ];
    expected = [
      "a: unknown top-level field `platfroms`"
      "a: declares no platform realization (needs platforms.linux and/or platforms.darwin)"
    ];
  };

  # A missing required descriptive field is reported.
  testValidationMissingFieldFires = {
    expr = builtins.length (validationFailuresFor [
      (builtins.removeAttrs (mkCap "a" {
        tier = "hyper";
        key = "Left";
      } { focus-column-left = { }; }) [ "label" ])
    ]);
    expected = 1;
  };

  # An unknown chord tier is reported.
  testValidationBadTierFires = {
    expr = builtins.length (validationFailuresFor [
      (mkCap "a" {
        tier = "hyprr";
        key = "Left";
      } { focus-column-left = { }; })
    ]);
    expected = 1;
  };

  # A chord modifier neither renderer maps is reported.
  testValidationBadModFires = {
    expr = builtins.length (validationFailuresFor [
      (mkCap "a" {
        tier = "hyper";
        mods = [ "Cmd" ];
        key = "Left";
      } { focus-column-left = { }; })
    ]);
    expected = 1;
  };

  # A darwin-realized cap with a key token skhd can't parse fails at eval —
  # not at the runtime config reload (whole-file rejection).
  testValidationDarwinKeyTokenFires = {
    expr = validationFailuresFor [
      (mkSkhdCap "a" {
        tier = "hyper";
        key = "Enter";
      })
    ];
    expected = [
      "a: chord key \"Enter\" is not a verified skhd key token (skhdKey ∪ single [A-Za-z0-9])"
    ];
  };

  # skhd-exec bodies are hand-authored; a payload here would be silently
  # ignored, so it's a violation.
  testValidationExecActionFires = {
    expr = builtins.length (validationFailuresFor [
      (
        (mkSkhdCap "a" {
          tier = "hyper";
          mods = [ "Shift" ];
          key = "M";
        })
        // {
          platforms.darwin = {
            realization = "skhd-exec";
            action = "stray";
          };
        }
      )
    ]);
    expected = 1;
  };

  # Guard: the live registry stays shape-valid — a malformed entry should
  # fail this in CI, not just the fixtures above. Wired into
  # validationFailuresFor, this now also covers I1 (id uniqueness), I2
  # (skhdKey shape) and I3 (rendered chord grammar) for the live registry.
  testLiveRegistryShapeValid = {
    expr = caps.validationFailures;
    expected = [ ];
  };

  # ── I1 — registry id uniqueness ───────────────────────────────────────────
  # lib.listToAttrs (skhdChordsFor/niriBindsFor) resolves a duplicate id
  # last-wins with no diagnostic; the validator must name the id instead of
  # letting one bind vanish invisibly.
  testValidationDuplicateIdFires = {
    expr = validationFailuresFor [
      (mkCap "dup" {
        tier = "hyper";
        key = "Left";
      } { focus-column-left = { }; })
      (mkCap "dup" {
        tier = "hyper";
        key = "Right";
      } { focus-column-right = { }; })
    ];
    expected = [ "duplicate capability id \"dup\"" ];
  };

  # ── I2 — skhdKey value shape ──────────────────────────────────────────────
  # A lowercased hex digit truncates in skhd's eat_hex and binds a different
  # key silently; an unmapped name tokenizes as an identifier and discards
  # the whole keymap at parse. Both must be caught.
  testSkhdKeyShapeBadValuesFire = {
    expr = skhdKeyShapeFailuresFor {
      Comma = "0x2b"; # lowercase hex — truncates to 0x2 in eat_hex
      Enter = "enter"; # not one of skhd's own literal_keycode_str names
    };
    expected = [
      "skhdKey.Comma = \"0x2b\" is neither uppercase hex (^0x[0-9A-F]+$) nor a pinned skhd literal name (left, right, up, down, return, tab, space, escape)"
      "skhdKey.Enter = \"enter\" is neither uppercase hex (^0x[0-9A-F]+$) nor a pinned skhd literal name (left, right, up, down, return, tab, space, escape)"
    ];
  };

  # A well-formed map (uppercase hex + pinned literals only) is clean.
  testSkhdKeyShapeCleanIsEmpty = {
    expr = skhdKeyShapeFailuresFor {
      Left = "left";
      Comma = "0x2B";
    };
    expected = [ ];
  };

  # ── I3 — rendered chord grammar ───────────────────────────────────────────
  # The only gate over the FULL rendered skhd chord string — proves it would
  # catch a mutated darwinMod token ("ctl") without touching skhdChord
  # itself (fixture hands the helper an already-rendered string directly).
  testRenderedChordGrammarMutatedModFires = {
    expr = renderedChordFailuresFor [
      {
        id = "a";
        rendered = "ctl + alt - m";
      }
    ];
    expected = [ "a: rendered skhd chord \"ctl + alt - m\" fails the skhd chord grammar" ];
  };

  # A broken join (missing the " + "/" - " separators) is caught the same way.
  testRenderedChordGrammarBrokenJoinFires = {
    expr = builtins.length (renderedChordFailuresFor [
      {
        id = "a";
        rendered = "ctrl+alt-b";
      }
    ]);
    expected = 1;
  };

  # A lowercase-hex-shaped key ("0x2b") is rejected — [a-z0-9]+ used to admit
  # it, but it truncates silently in skhd's eat_hex (only 0-9A-F is accepted).
  testRenderedChordGrammarLowercaseHexFires = {
    expr = renderedChordFailuresFor [
      {
        id = "a";
        rendered = "ctrl + alt - 0x2b";
      }
    ];
    expected = [ "a: rendered skhd chord \"ctrl + alt - 0x2b\" fails the skhd chord grammar" ];
  };

  # A correctly-rendered chord is clean.
  testRenderedChordGrammarCleanIsEmpty = {
    expr = renderedChordFailuresFor [
      {
        id = "a";
        rendered = "ctrl + alt - b";
      }
    ];
    expected = [ ];
  };

  # ── I4 — workspace-family completeness ────────────────────────────────────
  # An off-by-one range mutation (lib.range 1 8 instead of 1 9) silently
  # drops a workspace-family member; no emitter or other lint would
  # otherwise notice.
  testWorkspaceFamilyMissingMemberFires = {
    expr = workspaceFamilyFailuresFor (
      (map (
        n:
        mkCap "focus-workspace-${toString n}" {
          tier = "hyper";
          key = toString n;
        } { focus = n; }
      ) (lib.range 1 8))
      ++ (map (
        n:
        mkCap "move-window-to-workspace-${toString n}" {
          tier = "hyper";
          mods = [ "Shift" ];
          key = toString n;
        } { move = n; }
      ) (lib.range 1 9))
    );
    expected = [ "workspace family incomplete: missing focus-workspace-9" ];
  };

  # Guard: the live registry's workspace families are exactly complete (I4).
  # Not wired into validationFailuresFor itself (see its comment in
  # capabilities.nix) — this is the dedicated live test for I4.
  testLiveRegistryWorkspaceFamilyComplete = {
    expr = workspaceFamilyFailuresFor caps.registry;
    expected = [ ];
  };
}
