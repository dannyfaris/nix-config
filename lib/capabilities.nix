# Single-source capability registry — one declaration per cross-platform
# interaction capability, from which every surface is generated (ADR-039).
#
# Phase 1 (#384, walking skeleton) delivers: the three-dimension schema, the
# `Hyper` modifier constant, the niri emitter, and the eval-time collision
# lint. macOS emitters, the unified palette (#442), the actions.json dataset
# (#437), and the generated keybinds.md table are later phases — so the macOS
# descriptive metadata is authored here but no emitter consumes it yet
# (`platforms.darwin` carries descriptive only, no realization).
#
# Repo-decoupled by design (ADR-039 §9 — extraction-ready): this unit takes
# only { lib } and imports no repo modules, so packaging it standalone later
# stays cheap.
#
# Consumers:
#   - home/nixos/niri.nix        → `niriBinds` (the generated bind attrset)
#   - modules/nixos/keyd.nix     → `tiers.hyper.linux` (substrate reads the
#                                   same constant — base shape is one edit, §4)
#   - parts/checks.nix           → `collisions` (mkReportCheck) + the unit
#                                   tests in lib/tests/capabilities.nix
#
# Taxonomy + the human-facing bind inventory: docs/desktop/keybinds.md.
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
    # Parity record for the macOS phase (#440); no darwin emitter yet.
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
      mods = [ "Super" ];
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

    # Base Hyper — window geometry (niri-only; no macOS analogue per
    # keybinds.md §Window geometry, so each is a divergent leaf — correct, not
    # a gap — and carries no platforms.darwin).
    {
      id = "shrink-column";
      label = "Shrink column";
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
    }
    {
      id = "grow-column";
      label = "Grow column";
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
      platforms.darwin = {
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

    # Hyper+Super — workspace-level switch (move-to-workspace family is
    # generated above). The ↑/↓ pair is the showcase action divergence: niri
    # switches workspace, macOS opens Mission Control / exposé — so label,
    # description, and keywords all override. macOS values are provisional
    # pending the #440 macOS realization.
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
in
{
  inherit
    tiers
    registry
    niriChord
    niriBinds
    niriBindsFor
    collisions
    collisionsFor
    descriptiveFor
    ;
}
