# Single-source capability registry — one declaration per cross-platform
# interaction capability, from which every surface is generated (ADR-039).
#
# Phase 1 (#384) delivered: the three-dimension schema, the `Hyper` modifier
# constant, the niri emitter, and the eval-time collision lint. The macOS
# window-management slice (#440) adds the Hammerspoon emitter + the `Ctrl+Opt`
# darwin base, so `platforms.darwin` now carries typed `hammerspoon-handler`
# realizations alongside its descriptive overrides. #457 adds the keybinds.md
# table emitter (the human-facing surface, generated from the descriptive
# dimension). The unified palette (#442) and the actions.json dataset (#437)
# remain later phases.
#
# Repo-decoupled by design (ADR-039 §9 — extraction-ready): this unit takes
# only { lib } and imports no repo modules, so packaging it standalone later
# stays cheap. The Hammerspoon emitter emits only the `hs.hotkey.bind` calls
# (referencing handler names); the Lua handler bodies are hand-authored in
# home/darwin/hammerspoon.nix, mirroring how `niriBinds` emits binds the niri
# module composes — the codegen stays pure (ADR-039 §2, the Lua-handler split).
#
# Consumers:
#   - home/nixos/niri.nix         → `niriBinds` (the generated bind attrset)
#   - home/darwin/hammerspoon.nix → `hammerspoonBinds` (generated hs.hotkey.bind
#                                    lines) + the named handler bodies it owns
#   - modules/nixos/keyd.nix      → `tiers.hyper.linux` (substrate reads the
#                                    same constant — base shape is one edit, §4)
#   - home/darwin/karabiner.nix   → `tiers.hyper.darwin` (the Ctrl+Opt substrate)
#                                    + `karabinerHyperRemapKeys` (the remap key
#                                    set the darwin lint also reserves, #455)
#   - parts/checks.nix            → `collisions` + `darwinCollisions`
#                                    (mkReportCheck) + `keybindsTable` (the
#                                    fragment package + the generate-and-diff
#                                    check) + the unit tests in
#                                    lib/tests/capabilities.nix
#   - scripts/gen-keybinds-table.sh → `keybindsTable` (splices it into the doc)
#
# Taxonomy + the human-facing bind inventory: docs/desktop/keybinds.md (its
# Hyper table is generated from `keybindsTable`, #457).
{ lib }:
let
  # ── Tiers — the single-sourced Hyper constant (ADR-039 §3/§4) ──────────────
  # Canonical modifier tokens; each emitter maps them to its own dialect (niri:
  # Super→Mod; keyd: Ctrl→C …). Bare Ctrl+Alt is the known-good base
  # (hyper-layer-redesign §5); the optional AltGr padding is gated on the on-box
  # delivery verify (§12) and is deliberately not applied here.
  tiers = {
    hyper.linux = [
      "Ctrl"
      "Alt"
    ];
    # Consumed by the Hammerspoon emitter (chord rendering, below) and the
    # Karabiner Ctrl+Opt substrate (home/darwin/karabiner.nix), #440.
    hyper.darwin = [
      "Ctrl"
      "Option"
    ];
  };

  # ── niri chord rendering ───────────────────────────────────────────────────
  # niri writes Super as "Mod"; Ctrl/Alt/Shift are literal. A chord renders as
  # the tier's base modifiers, then any escalator `mods`, then the key — joined
  # with "+". This keeps the emitted attribute name identical to a hand-authored
  # niri bind, so niri-flake's typing (and build-time `niri validate`) still apply.
  niriMod = m: if m == "Super" then "Mod" else m;
  # Canonical modifier order so the emitted chord string is deterministic: two
  # caps with the same modifier SET render identically regardless of declaration
  # order (the dedup lint groups on this string), and the output matches niri's
  # conventional Mod+Ctrl+Alt+Shift order. niri matches modifier sets
  # order-independently, so any fixed order binds the same.
  modRank = {
    Mod = 0;
    Ctrl = 1;
    Alt = 2;
    Shift = 3;
  };
  sortMods = lib.sort (
    a: b:
    let
      ra = modRank.${a} or 99;
      rb = modRank.${b} or 99;
    in
    if ra == rb then a < b else ra < rb
  );
  niriChord =
    chord:
    lib.concatStringsSep "+" (
      sortMods (tiers.${chord.tier}.linux ++ map niriMod (chord.mods or [ ])) ++ [ chord.key ]
    );

  # ── Hammerspoon (darwin) chord rendering ───────────────────────────────────
  # hs.hotkey.bind takes a Lua mods table + a key string. The tier's base
  # modifiers (Ctrl+Opt) plus any escalator `mods` map to Hammerspoon's mod
  # tokens; the key token maps to hs's key name (lowercase letters, the literal
  # symbol for punctuation, explicit names for arrows/return/…). Two renderers:
  # `darwinChord` → a canonical string (the lint dedups on it); the emitter
  # below → the Lua `hs.hotkey.bind(...)` call.
  hsMod = {
    Ctrl = "ctrl";
    Alt = "alt";
    Option = "alt";
    Super = "cmd";
    Shift = "shift";
  };
  # Key token → Hammerspoon key string. Defaults to lib.toLower (covers letters
  # F→f and digits, which pass through unchanged); the table holds the rest.
  hsKey = {
    Left = "left";
    Right = "right";
    Up = "up";
    Down = "down";
    Return = "return";
    Tab = "tab";
    Escape = "escape";
    Space = "space";
    Minus = "-";
    Equal = "=";
  };
  hsKeyFor = k: hsKey.${k} or (lib.toLower k);
  # Canonical mod order for a deterministic chord string (the dedup lint groups
  # on it). hs treats the mods table as a set, so any fixed order binds the same.
  darwinModRank = {
    ctrl = 0;
    alt = 1;
    cmd = 2;
    shift = 3;
  };
  sortDarwinMods = lib.sort (
    a: b:
    let
      ra = darwinModRank.${a} or 99;
      rb = darwinModRank.${b} or 99;
    in
    if ra == rb then a < b else ra < rb
  );
  darwinModTokens =
    chord: sortDarwinMods (map (m: hsMod.${m}) (tiers.${chord.tier}.darwin ++ (chord.mods or [ ])));
  darwinChord = chord: lib.concatStringsSep "+" (darwinModTokens chord ++ [ (hsKeyFor chord.key) ]);

  # ── Workspace families — generated, not hand-listed (one per workspace 1–9) ─
  focusWorkspaces = map (n: {
    id = "focus-workspace-${toString n}";
    label = "Focus workspace ${toString n}";
    description = "Switch focus to the numbered workspace";
    keywords = [
      "workspace"
      "desktop"
      "switch"
      "space"
    ];
    chord = {
      tier = "hyper";
      key = toString n;
    };
    platforms.linux = {
      realization = "niri-action";
      action.focus-workspace = n;
    };
    platforms.darwin = {
      label = "Switch to Space ${toString n}";
      description = "Switch to the numbered Space";
      keywords = [
        "space"
        "desktop"
        "switch"
      ];
    };
  }) (lib.range 1 9);

  # On the Hyper+Shift "move" tier (not Hyper+Super): "Shift = move" is the
  # universal mnemonic — on-screen moves and send-to-workspace both live here,
  # aligning with the dominant i3/sway `$mod+Shift+N` convention. See
  # docs/desktop/keybinds.md §"The two move tiers".
  moveToWorkspaces = map (n: {
    id = "move-window-to-workspace-${toString n}";
    label = "Move window to workspace ${toString n}";
    description = "Move the focused window to the numbered workspace";
    keywords = [
      "move"
      "window"
      "workspace"
      "send"
    ];
    chord = {
      tier = "hyper";
      mods = [ "Shift" ];
      key = toString n;
    };
    platforms.linux = {
      realization = "niri-action";
      action.move-window-to-workspace = n;
    };
    platforms.darwin = {
      label = "Move window to Space ${toString n}";
      description = "Move the focused window to the numbered Space";
      keywords = [
        "move"
        "window"
        "space"
        "send"
      ];
    };
  }) (lib.range 1 9);

  # ── The registry — three dimensions per capability (ADR-039 §2) ────────────
  # chord (tier + escalator mods + key tokens) · realization (per-platform,
  # typed; the niri payload is the typed action attrset) · descriptive (shared
  # default `label`/`description`/`keywords`, with `platforms.<p>` overriding
  # where the prose genuinely diverges — column↔window vocabulary, or a chord
  # whose action differs per platform). niri is the shared default; macOS
  # follows (docs/desktop/keybinds.md §spatial model).
  registry = [
    # Base Hyper (Ctrl+Alt) — focus
    {
      id = "focus-column-left";
      label = "Focus column left";
      description = "Move focus to the column on the left";
      keywords = [
        "focus"
        "navigate"
        "left"
        "column"
      ];
      chord = {
        tier = "hyper";
        key = "Left";
      };
      platforms.linux = {
        realization = "niri-action";
        action.focus-column-left = { };
      };
      platforms.darwin = {
        label = "Focus window left";
        description = "Move focus to the window on the left; at the left edge, focus the previous Space";
        keywords = [
          "focus"
          "navigate"
          "left"
          "window"
          "space"
        ];
      };
    }
    {
      id = "focus-column-right";
      label = "Focus column right";
      description = "Move focus to the column on the right";
      keywords = [
        "focus"
        "navigate"
        "right"
        "column"
      ];
      chord = {
        tier = "hyper";
        key = "Right";
      };
      platforms.linux = {
        realization = "niri-action";
        action.focus-column-right = { };
      };
      platforms.darwin = {
        label = "Focus window right";
        description = "Move focus to the window on the right; at the right edge, focus the next Space";
        keywords = [
          "focus"
          "navigate"
          "right"
          "window"
          "space"
        ];
      };
    }
    {
      id = "focus-window-up";
      label = "Focus window up";
      description = "Move focus up within the current column";
      keywords = [
        "focus"
        "navigate"
        "up"
        "window"
        "stack"
      ];
      chord = {
        tier = "hyper";
        key = "Up";
      };
      platforms.linux = {
        realization = "niri-action";
        action.focus-window-up = { };
      };
      platforms.darwin = {
        description = "Move focus to the window above";
        keywords = [
          "focus"
          "navigate"
          "up"
          "window"
        ];
      };
    }
    {
      id = "focus-window-down";
      label = "Focus window down";
      description = "Move focus down within the current column";
      keywords = [
        "focus"
        "navigate"
        "down"
        "window"
        "stack"
      ];
      chord = {
        tier = "hyper";
        key = "Down";
      };
      platforms.linux = {
        realization = "niri-action";
        action.focus-window-down = { };
      };
      platforms.darwin = {
        description = "Move focus to the window below";
        keywords = [
          "focus"
          "navigate"
          "down"
          "window"
        ];
      };
    }
    {
      id = "overview";
      label = "Overview";
      description = "Open the workspace overview";
      keywords = [
        "overview"
        "expose"
        "mission control"
        "spaces"
      ];
      chord = {
        tier = "hyper";
        key = "Tab";
      };
      platforms.linux = {
        realization = "niri-action";
        action.toggle-overview = { };
      };
      platforms.darwin = {
        description = "Open Mission Control";
      };
    }

    # Base Hyper — window geometry. macOS realizes each as a stateless
    # Hammerspoon handler on the focused window (#440); the handler bodies live
    # in home/darwin/hammerspoon.nix and the emitter binds them. niri's column
    # vocabulary becomes macOS window vocabulary via the descriptive overrides.
    # See docs/desktop/macos-window-management.md + keybinds.md §Window geometry.
    {
      id = "shrink-column";
      label = "Shrink column width";
      description = "Decrease the focused column's width by 10%";
      keywords = [
        "resize"
        "shrink"
        "narrower"
        "width"
      ];
      chord = {
        tier = "hyper";
        key = "Minus";
      };
      platforms.linux = {
        realization = "niri-action";
        action.set-column-width = "-10%";
      };
      platforms.darwin = {
        label = "Shrink window width";
        description = "Decrease the focused window's width";
        realization = "hammerspoon-handler";
        handler = "shrinkWindow";
      };
    }
    {
      id = "grow-column";
      label = "Grow column width";
      description = "Increase the focused column's width by 10%";
      keywords = [
        "resize"
        "grow"
        "wider"
        "width"
      ];
      chord = {
        tier = "hyper";
        key = "Equal";
      };
      platforms.linux = {
        realization = "niri-action";
        action.set-column-width = "+10%";
      };
      platforms.darwin = {
        label = "Grow window width";
        description = "Increase the focused window's width";
        realization = "hammerspoon-handler";
        handler = "growWindow";
      };
    }
    {
      id = "cycle-column-width";
      label = "Cycle column width";
      description = "Cycle the focused column through preset widths";
      keywords = [
        "resize"
        "preset"
        "width"
        "cycle"
      ];
      chord = {
        tier = "hyper";
        key = "R";
      };
      platforms.linux = {
        realization = "niri-action";
        action.switch-preset-column-width = { };
      };
      platforms.darwin = {
        label = "Cycle window width";
        description = "Cycle the focused window through preset widths";
        keywords = [
          "resize"
          "preset"
          "width"
          "cycle"
        ];
        realization = "hammerspoon-handler";
        handler = "snapPresetWidth";
      };
    }
    {
      id = "center-column";
      label = "Center column";
      description = "Center the focused column on screen";
      keywords = [
        "center"
        "column"
        "layout"
      ];
      chord = {
        tier = "hyper";
        key = "C";
      };
      platforms.linux = {
        realization = "niri-action";
        action.center-column = { };
      };
      platforms.darwin = {
        label = "Center window";
        description = "Center the focused window on screen";
        keywords = [
          "center"
          "window"
          "layout"
        ];
        realization = "hammerspoon-handler";
        handler = "centerWindow";
      };
    }
    {
      id = "fullscreen-window";
      label = "Fullscreen window";
      description = "Toggle fullscreen for the focused window";
      keywords = [
        "fullscreen"
        "maximize"
        "zoom"
      ];
      chord = {
        tier = "hyper";
        key = "F";
      };
      platforms.linux = {
        realization = "niri-action";
        action.fullscreen-window = { };
      };
      platforms.darwin = {
        description = "Enter native fullscreen — the window moves to its own Space";
        realization = "hammerspoon-handler";
        handler = "fullscreenWindow";
      };
    }
    {
      id = "maximize-column";
      label = "Maximize column";
      description = "Toggle maximize for the focused column";
      keywords = [
        "maximize"
        "column"
        "expand"
      ];
      chord = {
        tier = "hyper";
        key = "M";
      };
      platforms.linux = {
        realization = "niri-action";
        action.maximize-column = { };
      };
      platforms.darwin = {
        label = "Maximize window";
        description = "Maximize the focused window to the screen's visible frame";
        keywords = [
          "maximize"
          "window"
          "expand"
        ];
        realization = "hammerspoon-handler";
        handler = "maximizeToFrame";
      };
    }

    # Base Hyper — spawn
    {
      id = "spawn-terminal";
      label = "Open terminal";
      description = "Open a terminal window";
      keywords = [
        "terminal"
        "shell"
        "console"
        "foot"
      ];
      chord = {
        tier = "hyper";
        key = "Return";
      };
      platforms.linux = {
        realization = "niri-action";
        action.spawn = "foot";
      };
      # Routed through the Hammerspoon emitter (handler body hand-authored in
      # home/darwin/hammerspoon.nix) so the chord is covered by the darwin
      # collision lint, #455 — not just bound by hand outside the registry.
      platforms.darwin = {
        realization = "hammerspoon-handler";
        handler = "ghosttyNewWindow";
        keywords = [
          "terminal"
          "shell"
          "console"
          "ghostty"
        ];
      };
    }
    {
      id = "spawn-browser";
      label = "Open browser";
      description = "Open the default web browser";
      keywords = [
        "browser"
        "web"
        "internet"
        "default"
      ];
      chord = {
        tier = "hyper";
        key = "B";
      };
      # A neutral https URL resolves through xdg-open to the registered default
      # handler, so the bind follows the default rather than pinning a browser.
      platforms.linux = {
        realization = "niri-action";
        action.spawn = [
          "xdg-open"
          "https://"
        ];
      };
      # macOS realizes this as Chrome focus-or-spawn (the handler body is
      # hand-authored in home/darwin/hammerspoon.nix); routed through the
      # emitter so the chord is covered by the darwin collision lint, #455.
      # The prose genuinely diverges from linux's default-browser behaviour.
      platforms.darwin = {
        description = "Focus the most-recent Chrome window, or open a new one";
        keywords = [
          "browser"
          "web"
          "internet"
          "chrome"
        ];
        realization = "hammerspoon-handler";
        handler = "chromeFocusOrNew";
      };
    }

    # Hyper+Shift — on-screen move (move-column + move-window-in-column)
    {
      id = "move-column-left";
      label = "Move column left";
      description = "Move the focused column to the left";
      keywords = [
        "move"
        "column"
        "left"
        "rearrange"
      ];
      chord = {
        tier = "hyper";
        mods = [ "Shift" ];
        key = "Left";
      };
      platforms.linux = {
        realization = "niri-action";
        action.move-column-left = { };
      };
      platforms.darwin = {
        label = "Move window left";
        description = "Move the focused window left; at the left edge, move it to the previous Space";
        keywords = [
          "move"
          "window"
          "left"
          "space"
          "rearrange"
        ];
      };
    }
    {
      id = "move-column-right";
      label = "Move column right";
      description = "Move the focused column to the right";
      keywords = [
        "move"
        "column"
        "right"
        "rearrange"
      ];
      chord = {
        tier = "hyper";
        mods = [ "Shift" ];
        key = "Right";
      };
      platforms.linux = {
        realization = "niri-action";
        action.move-column-right = { };
      };
      platforms.darwin = {
        label = "Move window right";
        description = "Move the focused window right; at the right edge, move it to the next Space";
        keywords = [
          "move"
          "window"
          "right"
          "space"
          "rearrange"
        ];
      };
    }
    {
      id = "move-window-up";
      label = "Move window up";
      description = "Move the focused window up within its column";
      keywords = [
        "move"
        "window"
        "up"
        "stack"
        "reorder"
      ];
      chord = {
        tier = "hyper";
        mods = [ "Shift" ];
        key = "Up";
      };
      platforms.linux = {
        realization = "niri-action";
        action.move-window-up = { };
      };
      platforms.darwin = {
        description = "Move the focused window up";
        keywords = [
          "move"
          "window"
          "up"
          "reorder"
        ];
      };
    }
    {
      id = "move-window-down";
      label = "Move window down";
      description = "Move the focused window down within its column";
      keywords = [
        "move"
        "window"
        "down"
        "stack"
        "reorder"
      ];
      chord = {
        tier = "hyper";
        mods = [ "Shift" ];
        key = "Down";
      };
      platforms.linux = {
        realization = "niri-action";
        action.move-window-down = { };
      };
      platforms.darwin = {
        description = "Move the focused window down";
        keywords = [
          "move"
          "window"
          "down"
          "reorder"
        ];
      };
    }

    # Hyper+Super — switch-workspace (the move-to-workspace family moved to the
    # Hyper+Shift "move" tier; Hyper+Super now carries only the ↑/↓ switch). The
    # ↑/↓ pair is the showcase action divergence: niri switches workspace, macOS
    # opens Mission Control / exposé — so label, description, and keywords all
    # override. macOS values are provisional pending the #440 macOS realization.
    {
      id = "switch-workspace-up";
      label = "Switch workspace up";
      description = "Switch to the workspace above";
      keywords = [
        "workspace"
        "switch"
        "up"
        "previous"
      ];
      chord = {
        tier = "hyper";
        mods = [ "Super" ];
        key = "Up";
      };
      platforms.linux = {
        realization = "niri-action";
        action.focus-workspace-up = { };
      };
      platforms.darwin = {
        label = "Mission Control";
        description = "Open Mission Control";
        keywords = [
          "exposé"
          "mission control"
          "overview"
          "spaces"
        ];
      };
    }
    {
      id = "switch-workspace-down";
      label = "Switch workspace down";
      description = "Switch to the workspace below";
      keywords = [
        "workspace"
        "switch"
        "down"
        "next"
      ];
      chord = {
        tier = "hyper";
        mods = [ "Super" ];
        key = "Down";
      };
      platforms.linux = {
        realization = "niri-action";
        action.focus-workspace-down = { };
      };
      platforms.darwin = {
        label = "App Exposé";
        description = "Show all windows of the active app (exposé)";
        keywords = [
          "exposé"
          "windows"
          "mission control"
          "app"
        ];
      };
    }
  ]
  ++ focusWorkspaces
  ++ moveToWorkspaces;

  # ── niri emitter ───────────────────────────────────────────────────────────
  # Parametrised over a registry so the unit tests can drive it with fixtures;
  # `niriBinds` applies it to the real registry. Each linux niri-action becomes
  # one `{ "<chord>" = { action = <payload>; }; }` entry — a plain attrset for
  # programs.niri.settings.binds (niri-flake type-checks it like a hand bind).
  isNiriAction = c: (c.platforms.linux.realization or null) == "niri-action";
  niriBindsFor =
    reg:
    lib.listToAttrs (
      map (c: lib.nameValuePair (niriChord c.chord) { action = c.platforms.linux.action; }) (
        lib.filter isNiriAction reg
      )
    );
  niriBinds = niriBindsFor registry;

  # ── Hammerspoon (darwin) emitter ───────────────────────────────────────────
  # Each darwin hammerspoon-handler capability becomes one `hs.hotkey.bind(mods,
  # key, handler)` line — the handler is referenced by *name*; its Lua body is
  # hand-authored in home/darwin/hammerspoon.nix, which concatenates this output
  # after the handler library (ADR-039 §2, the Lua-handler split). Pure string
  # codegen, parametrised over a registry so the unit tests can drive it.
  isHsHandler = c: (c.platforms.darwin.realization or null) == "hammerspoon-handler";
  luaModsTable =
    chord: "{ " + lib.concatMapStringsSep ", " (m: ''"${m}"'') (darwinModTokens chord) + " }";
  hsBindLine =
    c:
    ''hs.hotkey.bind(${luaModsTable c.chord}, "${hsKeyFor c.chord.key}", ${c.platforms.darwin.handler})'';
  hammerspoonBindsFor = reg: lib.concatMapStringsSep "\n" hsBindLine (lib.filter isHsHandler reg);
  hammerspoonBinds = hammerspoonBindsFor registry;

  # ── Collision lint (ADR-039 §8) ────────────────────────────────────────────
  # Pure: returns a list of human-legible failure strings (empty = ok), which
  # parts/checks.nix renders into a CI-gated derivation via mkReportCheck.
  # Two checks from day one: no two linux capabilities claim one chord, and the
  # bare Ctrl+Alt base never binds the F-row (niri's unbindable VT switch — an
  # escalated chord like Ctrl+Alt+Shift+F2 is bindable and not reserved). The
  # broader availability lint is deferred (§8). Parametrised so the unit tests
  # can prove it fires on a deliberate clash without tripping the live check.
  fRowKeys = map (n: "F${toString n}") (lib.range 1 12);
  hasCtrlAltBase =
    tier:
    let
      m = tiers.${tier}.linux;
    in
    lib.elem "Ctrl" m && lib.elem "Alt" m;
  collisionsFor =
    reg:
    let
      entries = map (c: {
        inherit (c) id;
        chord = niriChord c.chord;
        key = c.chord.key;
        tier = c.chord.tier;
        mods = c.chord.mods or [ ];
      }) (lib.filter isNiriAction reg);
      byChord = lib.groupBy (e: e.chord) entries;
      dupFailures = lib.mapAttrsToList (
        chord: es: "duplicate chord ${chord}: claimed by ${lib.concatMapStringsSep ", " (e: e.id) es}"
      ) (lib.filterAttrs (_chord: es: lib.length es > 1) byChord);
      fRowFailures = map (
        e:
        "F-row reservation: ${e.id} binds ${e.chord} — the bare Ctrl+Alt base must never bind the F-row (niri's unbindable VT switch; ADR-039 §8)"
      ) (lib.filter (e: hasCtrlAltBase e.tier && e.mods == [ ] && lib.elem e.key fRowKeys) entries);
    in
    dupFailures ++ fRowFailures;
  collisions = collisionsFor registry;

  # ── Collision lint — darwin (ADR-039 §8) ───────────────────────────────────
  # The macOS chord space is co-owned by two emitters: Hammerspoon handlers
  # (this registry) and the hand-authored Karabiner substrate remaps
  # (home/darwin/karabiner.nix — the Ctrl+Opt+arrow Mission-Control family and
  # the Ctrl+Opt+1‑9 Space jumps). The registry does not *own* those remaps
  # (§4 — Karabiner production stays substrate, not a chord→action realization
  # yet), but the lint must treat them as occupied so a future handler (e.g.
  # directional focus on the arrows) cannot silently double-bind a chord the
  # substrate already consumes. No darwin F-row rule: macOS Ctrl+Opt+F1‑12 is
  # not niri's unbindable VT switch, so that reservation is Linux-only.
  # The Hyper+key chords the hand-authored Karabiner substrate consumes as
  # remaps (Hyper+key → Ctrl+key): arrows drive the Mission-Control family, 1‑9
  # the Space jumps. Declared here ONCE so the Karabiner production
  # (home/darwin/karabiner.nix generates its manipulators from these keys) and
  # the darwin collision lint (darwinReservedChords, below) read one list and
  # cannot drift (#455). The registry does not yet own these as karabiner-remap
  # realizations (ADR-039 §4) — this is the single-source bridge until it does
  # (tracked on #428).
  karabinerHyperRemapKeys = {
    arrows = [
      "Left"
      "Right"
      "Up"
      "Down"
    ];
    numbers = map toString (lib.range 1 9);
  };
  darwinReservedChords = map (
    key:
    darwinChord {
      tier = "hyper";
      inherit key;
    }
  ) (karabinerHyperRemapKeys.arrows ++ karabinerHyperRemapKeys.numbers);
  darwinCollisionsFor =
    reg:
    let
      entries = map (c: {
        inherit (c) id;
        chord = darwinChord c.chord;
      }) (lib.filter isHsHandler reg);
      byChord = lib.groupBy (e: e.chord) entries;
      dupFailures = lib.mapAttrsToList (
        chord: es:
        "duplicate darwin chord ${chord}: claimed by ${lib.concatMapStringsSep ", " (e: e.id) es}"
      ) (lib.filterAttrs (_chord: es: lib.length es > 1) byChord);
      reservedFailures = map (
        e:
        "darwin chord ${e.chord} (${e.id}) collides with a Karabiner substrate-reserved chord (Mission-Control arrow / Space-jump remap; home/darwin/karabiner.nix, ADR-039 §4/§8)"
      ) (lib.filter (e: lib.elem e.chord darwinReservedChords) entries);
    in
    dupFailures ++ reservedFailures;
  darwinCollisions = darwinCollisionsFor registry;

  # ── Descriptive resolution (per-platform override → shared default) ─────────
  # The contract for the future palette/doc consumers (#442/#437): a platform's
  # effective descriptive is its override field falling back to the shared default.
  descriptiveFor =
    platform: cap:
    let
      o = cap.platforms.${platform} or { };
    in
    {
      label = o.label or cap.label;
      description = o.description or cap.description;
      keywords = o.keywords or cap.keywords;
    };

  # ── keybinds.md table emitter (ADR-039 §Impl step 3; #457) ──────────────────
  # Renders the cross-platform Hyper mapping table that docs/desktop/keybinds.md
  # carries as a generated region, so the human-facing reference can no longer
  # drift from what the registry binds. The chord is the friendly *tier* form
  # (Hyper+←), not the niriChord/darwinChord literal that feeds the real configs —
  # the doc names by tier (keybinds.md principle 6). Cells are the short per-
  # platform `label` (descriptiveFor); the longer descriptions + the deferred-
  # slice caveats stay in the doc's Living prose. The numeric 1‑9 families
  # collapse to one row each. Parametrised over a registry for unit testing; the
  # writer (scripts/gen-keybinds-table.sh) splices `keybindsTable` between the
  # doc's markers and parts/checks.nix diffs the committed region against it.
  tierDisplay = {
    hyper = "Hyper";
  };
  # Key token → friendly doc glyph: arrows become arrows, punctuation the literal
  # sign; letters / digits / Tab / Return pass through. "1‑9" (the collapsed
  # range token) also passes through unchanged.
  displayKey = {
    Left = "←";
    Right = "→";
    Up = "↑";
    Down = "↓";
    Minus = "−";
    Equal = "=";
  };
  displayKeyFor = k: displayKey.${k} or k;
  # Hyper + escalators (Shift / Super, in declaration order) + key, joined "+".
  tierChordDisplay =
    chord:
    lib.concatStringsSep "+" (
      [ tierDisplay.${chord.tier} ] ++ (chord.mods or [ ]) ++ [ (displayKeyFor chord.key) ]
    );
  digitKeys = map toString (lib.range 1 9);
  isDigitKey = k: lib.elem k digitKeys;
  # One markdown row. Digit-keyed caps render as a single 1‑9 range row: the chord
  # key becomes "1‑9" and the per-platform label's numeral becomes "N".
  keybindsRow =
    cap:
    let
      digit = isDigitKey cap.chord.key;
      chordDisp = tierChordDisplay (if digit then cap.chord // { key = "1‑9"; } else cap.chord);
      labelFor =
        platform:
        let
          l = (descriptiveFor platform cap).label;
        in
        if digit then lib.replaceStrings [ cap.chord.key ] [ "N" ] l else l;
    in
    "| `${chordDisp}` | ${labelFor "linux"} | ${labelFor "darwin"} |";
  keybindsTableFor =
    reg:
    let
      hyperCaps = lib.filter (c: c.chord.tier == "hyper") reg;
      # A digit family shares one signature (its escalator set), so it emits once;
      # every other cap is unique by id. The fold preserves registry order.
      sig =
        c:
        if isDigitKey c.chord.key then
          "range:" + lib.concatStringsSep "," (c.chord.mods or [ ])
        else
          "cap:" + c.id;
      folded =
        lib.foldl'
          (
            acc: c:
            let
              s = sig c;
            in
            if lib.elem s acc.seen then
              acc
            else
              {
                seen = acc.seen ++ [ s ];
                rows = acc.rows ++ [ (keybindsRow c) ];
              }
          )
          {
            seen = [ ];
            rows = [ ];
          }
          hyperCaps;
    in
    lib.concatStringsSep "\n" (
      [
        "| Chord | niri | macOS |"
        "|---|---|---|"
      ]
      ++ folded.rows
    );
  keybindsTable = keybindsTableFor registry;
in
{
  inherit
    tiers
    registry
    niriChord
    niriBinds
    niriBindsFor
    darwinChord
    hammerspoonBinds
    hammerspoonBindsFor
    collisions
    collisionsFor
    darwinCollisions
    darwinCollisionsFor
    karabinerHyperRemapKeys
    descriptiveFor
    tierChordDisplay
    keybindsTable
    keybindsTableFor
    ;
}
