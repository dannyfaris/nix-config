# Single-source capability registry — one declaration per cross-platform
# interaction capability, from which every surface is generated (ADR-039).
#
# Phase 1 (#384) delivered: the three-dimension schema, the `Hyper` modifier
# constant, the niri emitter, and the eval-time collision lint. The macOS
# window-management slice (#440) added the `Ctrl+Opt` darwin base; ADR-040
# (#494) replaced the original pure-Hammerspoon realization with AeroSpace,
# then ADR-047 replaced AeroSpace with yabai + skhd, collapsing
# `platforms.darwin` to a single `skhd-exec` realization — chords in the
# registry, every command body hand-authored in home/darwin/skhd.nix — since
# skhd has no verb emitter to parallel `niri-action`. #457 adds the
# keybinds.md table emitter (the human-facing surface, generated from the
# descriptive dimension). The unified palette (#442) and the actions.json
# dataset (#437) remain later phases.
#
# Repo-decoupled by design (ADR-039 §9 — extraction-ready): this unit takes
# only { lib } and imports no repo modules, so packaging it standalone later
# stays cheap. Every darwin capability is `skhd-exec`: the registry emits
# only the chord (`skhdChords`); the command body (which needs the
# package-derived yabai path) is hand-authored in home/darwin/skhd.nix,
# mirroring how `niriBinds` emits binds the niri module composes — the
# codegen stays pure (ADR-039 §2).
#
# Consumers:
#   - home/nixos/niri.nix         → `niriBinds` (the generated bind attrset)
#   - modules/nixos/keyd.nix      → `tiers.hyper.linux` (substrate reads the
#                                    same constant — base shape is one edit, §4)
#   - home/darwin/karabiner.nix   → `tiers.hyper.darwin` (the Ctrl+Opt substrate)
#                                    + `karabinerHyperRemapKeys` (now emptied —
#                                    the chords fall through to the skhd
#                                    keymap, ADR-047; the remaps were first
#                                    retired under ADR-040)
#   - home/darwin/skhd.nix        → `skhdChords` (chord per darwin-realized
#                                    cap; the module keys its command bodies
#                                    by cap id and asserts the two sets
#                                    match, the #537 pattern)
#   - parts/checks.nix            → `collisions` + `skhdCollisions` +
#                                    `validationFailures` (mkReportCheck, #535)
#                                    + `keybindsTable` (the
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
    # Consumed by the skhd chord renderer (below) and the Karabiner
    # Ctrl+Opt substrate (home/darwin/karabiner.nix), #440 / ADR-047.
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

  # ── darwin chord rendering ─────────────────────────────────────────────────
  # The tier's base modifiers (Ctrl+Opt) plus any escalator `mods` map to the
  # darwin mod-token set (ctrl/alt/shift/cmd — Option→alt, Super→cmd), shared by
  # the skhd chord renderer below. (Hammerspoon's `hs.hotkey.bind` renderer
  # was retired with Hammerspoon itself, ADR-040.)
  darwinMod = {
    Ctrl = "ctrl";
    Alt = "alt";
    Option = "alt";
    Super = "cmd";
    Shift = "shift";
  };
  # Canonical mod order for a deterministic chord string (the dedup lint groups
  # on it). skhd treats the mods as a set, so any fixed order binds the same.
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
    chord: sortDarwinMods (map (m: darwinMod.${m}) (tiers.${chord.tier}.darwin ++ (chord.mods or [ ])));

  # ── skhd (darwin) chord rendering ──────────────────────────────────────────
  # skhd's grammar is `<mod> + <mod> - <key> : <command>`. darwinModTokens (the
  # Ctrl+Opt base plus any escalator `mods`, mapped to ctrl/alt/shift/cmd) feeds
  # this renderer directly; only the join and the key spelling are skhd's own.
  #
  # NO punctuation key has a literal spelling. skhd's `literal_keycode_str`
  # (src/tokenize.h:13-32) is entirely alphabetic, and `resolve_identifier_type` is
  # only reached from the tokenizer's `isalpha` branch — so every punctuation key
  # must be an ANSI keycode, whether or not the character is also a reserved
  # grammar token. Uppercase hex is mandatory: eat_hex accepts 0-9A-F only
  # (src/tokenize.c:55-63), so a lowercased `0x2b` truncates to `0x2` and binds a
  # different key silently. Values are the kVK_ANSI_* constants.
  #
  # Named literals are pinned to skhd's table rather than guessed (`return`, not
  # `enter`): an unmapped name tokenizes as an identifier, which the key position
  # rejects (src/parse.c:298-308), and a parse error discards the ENTIRE mode map
  # (src/parse.c:496-500) — so one wrong name costs every bind on the host, not
  # just its own.
  #
  # `skhdKey` is the sole darwin key map and the validation gate: `validDarwinKey`
  # (below) checks every darwin-realized chord key against it, because a token
  # missing from this map renders a bare `lib.toLower` identifier and takes the
  # whole keymap down while CI stays green.
  skhdKey = {
    Left = "left";
    Right = "right";
    Up = "up";
    Down = "down";
    Return = "return";
    Tab = "tab";
    Space = "space";
    Minus = "0x1B";
    Equal = "0x18";
    Semicolon = "0x29";
    Comma = "0x2B";
    Slash = "0x2C";
  };
  skhdKeyFor = k: skhdKey.${k} or (lib.toLower k);
  skhdChord =
    chord: "${lib.concatStringsSep " + " (darwinModTokens chord)} - ${skhdKeyFor chord.key}";

  # Every capability carrying a darwin realization. `skhdChords` is an attrset, so
  # consumers iterating it get alphabetical id order, not registry order — the
  # generated skhdrc is grouped by that, not by the registry's reading order. The
  # skhd.nix keys its command bodies by these ids and asserts the two
  # sets match exactly (the #537 pattern), so the registry owns every darwin
  # *chord* and a chord change moves the bind with it.
  darwinRealizedCapsFor = reg: lib.filter (c: (c.platforms.darwin.realization or null) != null) reg;
  skhdChordsFor =
    reg:
    lib.listToAttrs (map (c: lib.nameValuePair c.id (skhdChord c.chord)) (darwinRealizedCapsFor reg));
  skhdChords = skhdChordsFor registry;

  # skhd resolves duplicate chords silently, first-wins, with no diagnostic
  # (src/hashtable.h:94-97) — so a collision is invisible at runtime and this lint
  # is the only thing that can catch it.
  skhdCollisionsFor =
    reg:
    let
      entries = map (c: {
        inherit (c) id;
        chord = skhdChord c.chord;
      }) (darwinRealizedCapsFor reg);
      byChord = lib.groupBy (e: e.chord) entries;
    in
    lib.mapAttrsToList (
      chord: es: "duplicate skhd chord ${chord}: claimed by ${lib.concatMapStringsSep ", " (e: e.id) es}"
    ) (lib.filterAttrs (_c: es: lib.length es > 1) byChord);
  skhdCollisions = skhdCollisionsFor registry;

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
      # Native macOS Desktops (ADR-047) — yabai's CLI term "Space" and
      # Mission Control's "Desktop" name the same object. All nine bound
      # (operator decision, #494).
      realization = "skhd-exec";
      label = "Switch to Desktop ${toString n}";
      description = "Switch to the numbered Desktop";
      keywords = [
        "workspace"
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
      realization = "skhd-exec";
      label = "Move window to workspace ${toString n}";
      description = "Move the focused window to the numbered Desktop";
      keywords = [
        "move"
        "window"
        "workspace"
        "space"
        "send"
      ];
    };
  }) (lib.range 1 9);

  # ── darwin-only capabilities (ADR-047) ─────────────────────────────────────
  # macOS-only binds with no niri twin: app-launch, the bsp/stack layout
  # toggle, the service-mode leader, maximise (zoom-fullscreen), and
  # cycle-terminal-windows. They live in the
  # registry (not hand-authored) so the future palette/cheatsheet (ADR-039 §6,
  # registry-only dataset) can show them and the collision lint covers them.
  # `platforms.linux` is omitted (structural "linux: N/A"); the keybinds.md
  # table renders "—" for the unrealized platform.
  #
  # App-launch: skhd-exec — body hand-authored in home/darwin/skhd.nix
  # (`/usr/bin/open -a`, on the exec-and-forget default PATH, so no nix-store
  # path is needed for `open` itself), like every darwin realization now
  # (ADR-047).
  mkAppLaunch =
    {
      id,
      key,
      app,
      label,
      keywords,
    }:
    {
      inherit id label keywords;
      description = "Focus ${app}, or launch it if not running";
      chord = {
        tier = "hyper";
        inherit key;
      };
      platforms.darwin.realization = "skhd-exec";
    };
  darwinWmExtras = [
    # open-finder was folded into spawn-file-manager (below) when the freed
    # Hyper+F gave the chord exact cross-platform parity (#762).
    (mkAppLaunch {
      id = "open-messages";
      key = "M";
      app = "Messages";
      label = "Open Messages";
      keywords = [
        "messages"
        "imessage"
        "chat"
        "launch"
      ];
    })
    (mkAppLaunch {
      id = "open-outlook";
      key = "E";
      app = "Microsoft Outlook";
      label = "Open Outlook";
      keywords = [
        "outlook"
        "email"
        "mail"
        "calendar"
        "launch"
      ];
    })
    (mkAppLaunch {
      id = "open-slack";
      key = "S";
      app = "Slack";
      label = "Open Slack";
      keywords = [
        "slack"
        "chat"
        "launch"
      ];
    })
    {
      id = "layout-toggle";
      label = "Toggle bsp/stack layout";
      description = "Toggle the focused Space between bsp and stack layout";
      keywords = [
        "layout"
        "bsp"
        "stack"
        "toggle"
      ];
      chord = {
        tier = "hyper";
        key = "Comma";
      };
      platforms.darwin.realization = "skhd-exec";
    }
    {
      id = "service-mode";
      label = "Service mode";
      description = "Enter the service mode (balance / float-toggle)";
      keywords = [
        "service"
        "mode"
        "reload"
        "leader"
      ];
      chord = {
        tier = "hyper";
        mods = [ "Shift" ];
        key = "Semicolon";
      };
      platforms.darwin.realization = "skhd-exec";
    }
    {
      # skhd-exec: body hand-authored in home/darwin/skhd.nix (it shells out
      # to the yabai binary by absolute path). yabai's zoom-fullscreen is a
      # stable, reversible maximise (ADR-047) — AeroSpace had none, forcing
      # the isolate-onto-empty-workspace workaround this id name still
      # reflects; the realization no longer isolates.
      id = "maximise-by-isolation";
      label = "Maximise";
      description = "Toggle a stable, reversible maximise for the focused window (zoom-fullscreen)";
      keywords = [
        "maximize"
        "maximise"
        "isolate"
        "fullscreen"
        "expand"
      ];
      chord = {
        tier = "hyper";
        mods = [ "Shift" ];
        key = "M";
      };
      platforms.darwin.realization = "skhd-exec";
    }
    {
      # skhd-exec: body hand-authored in home/darwin/skhd.nix (it shells out
      # to the yabai binary by absolute path). Cycles focus through all
      # Ghostty windows across Desktops; from a non-Ghostty window it focuses
      # the first. Pairs with spawn-terminal (Hyper+Return = new window;
      # +Shift = cycle existing).
      id = "cycle-terminal-windows";
      label = "Cycle terminal windows";
      description = "Focus the next Ghostty window, across workspaces (wraps; from elsewhere, focuses the first)";
      keywords = [
        "terminal"
        "ghostty"
        "cycle"
        "focus"
        "window"
      ];
      chord = {
        tier = "hyper";
        mods = [ "Shift" ];
        key = "Return";
      };
      platforms.darwin.realization = "skhd-exec";
    }
  ];

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
      # skhd-exec: the edge-scroll fallthrough is a *complex* bind (it shells
      # out to the yabai binary by absolute path), so its body is
      # hand-authored in home/darwin/skhd.nix; here it contributes the
      # chord + descriptive for the palette/table/collision-lint. Darwin-
      # specific behaviour (not a faithful focus-column mirror): at the edge it
      # steps to the adjacent Space (wrapping at the ends) and lands on that
      # Space's last-focused window.
      platforms.darwin = {
        realization = "skhd-exec";
        label = "Focus window left";
        description = "Move focus left; at the left edge, step to the previous Space (wrapping from the first to the last)";
        keywords = [
          "focus"
          "navigate"
          "left"
          "window"
          "workspace"
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
      # skhd-exec (edge-scroll) — see focus-column-left. Body hand-authored
      # in home/darwin/skhd.nix.
      platforms.darwin = {
        realization = "skhd-exec";
        label = "Focus window right";
        description = "Move focus right; at the right edge, step to the next Space (wrapping from the last to the first)";
        keywords = [
          "focus"
          "navigate"
          "right"
          "window"
          "workspace"
        ];
      };
    }
    {
      id = "focus-window-up";
      label = "Focus window or workspace up";
      description = "Move focus up within the column; at the top of the column, switch to the workspace above";
      keywords = [
        "focus"
        "navigate"
        "up"
        "window"
        "stack"
        "workspace"
      ];
      chord = {
        tier = "hyper";
        key = "Up";
      };
      platforms.linux = {
        realization = "niri-action";
        # Edge behaviour here differs from darwin's; see
        # docs/desktop/keybinds.md's "Focus & navigation" note for the comparison.
        action.focus-window-or-workspace-up = { };
      };
      platforms.darwin = {
        realization = "skhd-exec";
        label = "Focus window up";
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
      label = "Focus window or workspace down";
      description = "Move focus down within the column; at the bottom of the column, switch to the workspace below";
      keywords = [
        "focus"
        "navigate"
        "down"
        "window"
        "stack"
        "workspace"
      ];
      chord = {
        tier = "hyper";
        key = "Down";
      };
      platforms.linux = {
        realization = "niri-action";
        action.focus-window-or-workspace-down = { };
      };
      platforms.darwin = {
        realization = "skhd-exec";
        label = "Focus window down";
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
        realization = "skhd-exec";
        label = "Last workspace";
        description = "Toggle to the previously-focused workspace";
        keywords = [
          "workspace"
          "back"
          "toggle"
          "previous"
        ];
      };
    }

    # Hyper+Shift — window geometry (migrated from base Hyper in #762: bare
    # Hyper = navigate/switch/launch, Hyper+Shift = act on the window; see
    # keybinds.md §The spatial model). On macOS these are structurally
    # "darwin: N/A" (no platforms.darwin): yabai auto-tiles (BSP), so
    # per-window geometry is superseded (ADR-047, continuing ADR-040's same
    # call, itself superseding ADR-039 §7's Hammerspoon geometry handlers).
    # The capability IDs + their niri
    # realization stay — the Linux side still uses them, and a future
    # Hyprland move could re-realize center/maximize (design note §Future).
    # The freed Hyper+F gives spawn-file-manager exact Finder parity with
    # the Finder launch folded into spawn-file-manager (below).
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
        mods = [ "Shift" ];
        key = "Minus";
      };
      platforms.linux = {
        realization = "niri-action";
        action.set-column-width = "-10%";
      };
      # darwin: N/A (yabai auto-tiles; ADR-047).
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
        mods = [ "Shift" ];
        key = "Equal";
      };
      platforms.linux = {
        realization = "niri-action";
        action.set-column-width = "+10%";
      };
      # darwin: N/A (yabai auto-tiles; ADR-047).
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
        mods = [ "Shift" ];
        key = "R";
      };
      platforms.linux = {
        realization = "niri-action";
        action.switch-preset-column-width = { };
      };
      # darwin: N/A — niri-ism, no yabai equivalent (ADR-047).
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
        mods = [ "Shift" ];
        key = "C";
      };
      platforms.linux = {
        realization = "niri-action";
        action.center-column = { };
      };
      # darwin: N/A — niri-ism, no yabai equivalent (ADR-047).
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
        mods = [ "Shift" ];
        key = "F";
      };
      platforms.linux = {
        realization = "niri-action";
        action.fullscreen-window = { };
      };
      # darwin: N/A — the stable, reversible equivalent is maximise-by-isolation
      # (yabai zoom-fullscreen, Hyper+Shift+M, below; ADR-047).
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
        mods = [ "Shift" ];
        key = "M";
      };
      platforms.linux = {
        realization = "niri-action";
        action.maximize-column = { };
      };
      # darwin: N/A here as an entry — but the chord now sits in exact
      # action-analogue parity with darwin's maximise-by-isolation (its own
      # Hyper+Shift+M entry below; disjoint per-platform tables). (ADR-047.)
    }
    {
      id = "toggle-window-floating";
      label = "Toggle floating";
      description = "Toggle the focused window between floating and the ribbon";
      keywords = [
        "floating"
        "float"
        "tiling"
        "toggle"
        "window"
      ];
      # Space: the i3/sway $mod+Shift+Space convention, on the act-on-the-
      # window escalator where window-state toggles live (fullscreen,
      # maximize). Companion to the open-floating rules in home/nixos/niri.nix.
      chord = {
        tier = "hyper";
        mods = [ "Shift" ];
        key = "Space";
      };
      platforms.linux = {
        realization = "niri-action";
        action.toggle-window-floating = { };
      };
      # skhd-exec: body hand-authored in home/darwin/skhd.nix (it resolves the
      # yabai binary by package-derived path). The escape hatch for the float
      # rules in modules/darwin/yabai.nix, matching what this chord already is for
      # the niri open-floating rules — without it darwin's only float toggle is
      # service mode, two keys deep inside a mode that captures the keyboard.
      platforms.darwin = {
        realization = "skhd-exec";
        label = "Toggle floating";
        description = "Toggle the focused window between floating and the bsp tree";
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
      # macOS: always spawn a *new* Ghostty window via `open -na` (a new app
      # instance per window — Ghostty exposes no scriptable single-instance
      # new-window on macOS; ADR-040 + design note §Design). Paired with
      # `quit-after-last-window-closed = true` in home/darwin/ghostty.nix so
      # instances don't linger windowless. `open` is on the exec-and-forget
      # PATH (/usr/bin), so no nix-store path needed.
      platforms.darwin = {
        realization = "skhd-exec";
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
      label = "Focus or open browser";
      description = "Focus the browser window, or open the browser";
      keywords = [
        "browser"
        "web"
        "internet"
        "default"
        "focus"
      ];
      chord = {
        tier = "hyper";
        key = "B";
      };
      # Focus-or-spawn (a fresh xdg-open opened a NEW window every press —
      # the focus half must go through the compositor). The focus target pins
      # the selected browser's app-id (firefox, ADR-029) while the spawn
      # fallback still follows the xdg default; niri-focus-or-spawn is the
      # home.packages helper in home/nixos/niri.nix, resolved via the
      # session PATH like every other bare spawn name here.
      platforms.linux = {
        realization = "niri-action";
        action.spawn = [
          "niri-focus-or-spawn"
          "firefox"
          "xdg-open"
          "https://"
        ];
      };
      # macOS: focus-or-launch Chrome via `open -a` (no `-n` — unlike the
      # terminal, this is focus-if-present, and a second Chrome instance would
      # fight over the shared profile). Prose diverges from linux's default-
      # browser behaviour. (ADR-040.)
      platforms.darwin = {
        description = "Focus Chrome, or launch it if not running";
        keywords = [
          "browser"
          "web"
          "internet"
          "chrome"
        ];
        realization = "skhd-exec";
      };
    }
    {
      id = "spawn-file-manager";
      label = "Open file manager";
      description = "Open the GUI file manager";
      keywords = [
        "files"
        "file manager"
        "nautilus"
        "explorer"
        "folders"
      ];
      # F: exact cross-platform parity (Nautilus / Finder on one chord),
      # enabled by the geometry cluster's move to Hyper+Shift (#762). See
      # docs/desktop/file-manager.md §Configuration.
      chord = {
        tier = "hyper";
        key = "F";
      };
      platforms.linux = {
        realization = "niri-action";
        action.spawn = [ "nautilus" ];
      };
      # macOS: focus-or-launch Finder (subsumed the former open-finder
      # mkAppLaunch entry). ADR-040.
      platforms.darwin = {
        realization = "skhd-exec";
        label = "Open Finder";
        description = "Focus Finder, or launch it if not running";
        keywords = [
          "finder"
          "files"
          "launch"
        ];
      };
    }
    {
      id = "spawn-claude";
      label = "Focus or open Claude";
      description = "Focus the Claude Desktop window, or launch the app";
      keywords = [
        "claude"
        "ai"
        "assistant"
        "chat"
        "focus"
      ];
      chord = {
        tier = "hyper";
        key = "C";
      };
      # Plain spawn IS focus-or-open: the app is single-instance — a re-spawn
      # makes the running instance raise + focus its window. Regression lever:
      # niri-focus-or-spawn with app-id com.anthropic.Claude. Linux-only; on
      # niri hosts without the app (#683) the chord is a silent no-op.
      platforms.linux = {
        realization = "niri-action";
        action.spawn = "claude-desktop";
      };
    }
    {
      id = "open-1password";
      label = "Open 1Password";
      description = "Focus 1Password, or launch it if not running";
      keywords = [
        "1password"
        "passwords"
        "vault"
        "launch"
        "focus"
      ];
      chord = {
        tier = "hyper";
        key = "Slash";
      };
      # Focus-or-spawn via the helper; app-id pinned lowercase from a live
      # window probe. 1Password is Electron single-instance, so the spawn
      # fallback raises the running tray instance's window when one exists.
      platforms.linux = {
        realization = "niri-action";
        action.spawn = [
          "niri-focus-or-spawn"
          "1password"
          "1password"
        ];
      };
      platforms.darwin.realization = "skhd-exec";
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
        realization = "skhd-exec";
        label = "Move window left";
        description = "Move the focused window left within the workspace";
        keywords = [
          "move"
          "window"
          "left"
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
        realization = "skhd-exec";
        label = "Move window right";
        description = "Move the focused window right within the workspace";
        keywords = [
          "move"
          "window"
          "right"
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
        realization = "skhd-exec";
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
        realization = "skhd-exec";
        description = "Move the focused window down";
        keywords = [
          "move"
          "window"
          "down"
          "reorder"
        ];
      };
    }

    # Hyper+Super — switch-workspace (the move-to-workspace family lives on the
    # Hyper+Shift "move" tier). darwin: N/A — workspace switching is
    # Hyper+1‑9 / the Hyper+←/→ edge-scroll / Hyper+Tab (ADR-047); there is no
    # up/down-relative stepping bind on macOS. The capability IDs + niri
    # realization stay for the Linux side.
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
      # darwin: N/A (ADR-047).
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
      # darwin: N/A (ADR-047).
    }
  ]
  ++ focusWorkspaces
  ++ moveToWorkspaces
  ++ darwinWmExtras;

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

  # The Karabiner Mission-Control / Space-jump remaps are gone (ADR-040, and
  # unchanged by ADR-047): Hyper+arrows / Hyper+1‑9 fall through to the skhd
  # keymap instead of native Spaces, so `karabinerHyperRemapKeys` is emptied
  # permanently and the old reserved-chord logic is dropped.
  # home/darwin/karabiner.nix still reads this attr to build its (now empty)
  # remap manipulators — #488's empty-manipulator filter drops the resulting
  # empty rules — so the attr is kept, not deleted.
  karabinerHyperRemapKeys = {
    arrows = [ ];
    numbers = [ ];
  };

  # ── Registry shape validation (#535) ───────────────────────────────────────
  # The emitters and lints above SELECT entries by matching known field values
  # (isNiriAction, skhd-exec's realization tag, …), so a malformed entry —
  # typo'd realization tag, misspelled field, unmapped key token — is an
  # *absence*, not an error: dropped from emission and invisible to the
  # collision lint (docs/reviews/engineering-review-2026-07-06.md §1). This
  # pass makes the
  # registry's shape a contract: every entry either emits exactly as declared
  # or fails eval with a named violation. Pure failure-string list (empty =
  # ok), parametrised for unit fixtures — the collisionsFor house pattern;
  # parts/checks.nix renders it via mkReportCheck.
  requiredCapFields = [
    "id"
    "label"
    "description"
    "keywords"
    "chord"
  ];
  knownCapFields = requiredCapFields ++ [ "platforms" ];
  knownChordFields = [
    "tier"
    "mods"
    "key"
  ];
  knownPlatforms = [
    "linux"
    "darwin"
  ];
  knownPlatformFields = [
    "realization"
    "action"
    "label"
    "description"
    "keywords"
  ];
  knownRealizations = {
    linux = [ "niri-action" ];
    darwin = [ "skhd-exec" ];
  };
  # The escalator tokens BOTH chord renderers can map (darwinMod's domain);
  # the niri renderer passes unknown tokens through and defers to build-time
  # `niri validate`, so this stricter cross-platform set is the gate.
  knownChordMods = lib.attrNames darwinMod;
  # A darwin-bindable key token: an explicit skhdKey name, or a single
  # letter/digit (skhdKeyFor lowercases those). Anything else would be
  # lowercased into the config and reject the WHOLE file at skhd's runtime
  # parse — this check moves that failure to eval.
  validDarwinKey = k: lib.hasAttr k skhdKey || builtins.match "[A-Za-z0-9]" k != null;

  # I1 — registry id uniqueness. skhdChordsFor/niriBindsFor both key their
  # output via lib.listToAttrs, which resolves a duplicate id last-wins with
  # no diagnostic — a duplicated id silently drops one capability's bind
  # while every emitter and every other lint stays green.
  idDuplicateFailuresFor =
    reg:
    let
      byId = lib.groupBy lib.id (lib.filter (i: i != null) (map (c: c.id or null) reg));
      dup = lib.filterAttrs (_id: matches: lib.length matches > 1) byId;
    in
    lib.mapAttrsToList (id: _matches: "duplicate capability id \"${id}\"") dup;

  # I2 — skhdKey value shape (registry-independent; evaluated unconditionally
  # over skhdKey itself). Pinned to the literal names skhd's tokenizer
  # actually maps (src/tokenize.h): an unmapped name tokenizes as an
  # identifier and discards the ENTIRE keymap at parse (src/parse.c:298-308,
  # 496-500). Non-literal values must be uppercase hex — eat_hex accepts
  # 0-9A-F only (src/tokenize.c:55-63), so a lowercased `0x2b` truncates to
  # `0x2` and binds a different key silently.
  skhdLiteralKeyNames = [
    "left"
    "right"
    "up"
    "down"
    "return"
    "tab"
    "space"
    "escape"
  ];
  skhdKeyShapeFailuresFor =
    keyMap:
    lib.concatLists (
      lib.mapAttrsToList (
        tok: v:
        lib.optional (builtins.match "0x[0-9A-F]+" v == null && !lib.elem v skhdLiteralKeyNames)
          "skhdKey.${tok} = \"${v}\" is neither uppercase hex (^0x[0-9A-F]+$) nor a pinned skhd literal name (${lib.concatStringsSep ", " skhdLiteralKeyNames})"
      ) keyMap
    );
  skhdKeyShapeFailures = skhdKeyShapeFailuresFor skhdKey;

  # I3 — rendered chord grammar. The only gate over the FULL rendered skhd
  # chord string, so it's the one that would catch a mutated darwinMod token
  # ("ctl") or a broken join — either discards the whole keymap at skhd parse
  # while every structural (pre-render) check above stays green.
  # POSIX ERE (Nix's builtins.match dialect); verified against skhdChord's
  # own live output before landing.
  #
  # The key alternative is exactly uppercase hex / all-alphabetic / a single
  # digit — not a blanket [a-z0-9]+, which would also admit lowercase-hex-
  # shaped strings ("0x2b") that truncate silently in skhd's eat_hex.
  # The `+` repeat deliberately requires ≥2 mods: tiers.hyper.darwin pins a
  # 2-mod base, so a single-mod rendering can only mean tier/renderer
  # corruption — relaxing to `*` would let that class pass.
  chordGrammar = "^((ctrl|alt|shift|cmd) \\+ )+(ctrl|alt|shift|cmd) - (0x[0-9A-F]+|[a-z]+|[0-9])$";
  # Fixture-drivable: takes id→rendered-string pairs directly (not a
  # registry), so a test can hand it a deliberately-mutated string without
  # touching the real renderer.
  renderedChordFailuresFor =
    entries:
    map (e: "${e.id}: rendered skhd chord \"${e.rendered}\" fails the skhd chord grammar") (
      lib.filter (e: builtins.match chordGrammar e.rendered == null) entries
    );
  # The live wiring: every darwin-realized capability's ACTUAL rendered chord
  # via the real skhdChord/darwinRealizedCapsFor — what validationFailuresFor
  # calls. Guarded so a fixture with an already-flagged bad tier/mods can't
  # crash this pass; that entry's own structural failure is reported instead.
  darwinChordEntriesFor =
    reg:
    map
      (c: {
        inherit (c) id;
        rendered = skhdChord c.chord;
      })
      (
        lib.filter (
          c:
          (c.platforms.darwin.realization or null) != null
          && (c.chord or { }) ? tier
          && lib.hasAttr c.chord.tier tiers
          && (tiers.${c.chord.tier} ? darwin)
          && (c.chord or { }) ? key
          && lib.subtractLists knownChordMods (c.chord.mods or [ ]) == [ ]
        ) reg
      );

  # I4 — workspace-family completeness. Guards the `lib.range 1 9` generation
  # in focusWorkspaces/moveToWorkspaces against an off-by-one or range
  # mutation that would silently shrink (or misgrow) the keymap — no emitter
  # or other lint would otherwise notice a missing family member. Asserts
  # completeness against a fixed 18-id set, so — unlike I1-I3 — it is only
  # meaningful for the whole registry; kept out of validationFailuresFor's
  # generic per-fixture pipeline (every small fixture elsewhere in the unit
  # tests would otherwise fail it) and applied instead directly to the top-
  # level `validationFailures` binding below.
  workspaceFamilyPrefixes = [
    "focus-workspace"
    "move-window-to-workspace"
  ];
  isWorkspaceFamilyId =
    id: lib.any (p: builtins.match "${p}-[0-9]+" id != null) workspaceFamilyPrefixes;
  workspaceFamilyFailuresFor =
    reg:
    let
      ids = map (c: c.id or null) reg;
      expected = lib.concatMap (
        prefix: map (n: "${prefix}-${toString n}") (lib.range 1 9)
      ) workspaceFamilyPrefixes;
      actualFamily = lib.filter isWorkspaceFamilyId (lib.filter (i: i != null) ids);
      countOf = id: lib.length (lib.filter (i: i == id) actualFamily);
      missing = lib.filter (id: countOf id == 0) expected;
      duplicated = lib.filter (id: countOf id > 1) expected;
      unexpected = lib.subtractLists expected actualFamily;
    in
    lib.optional (
      missing != [ ]
    ) "workspace family incomplete: missing ${lib.concatStringsSep ", " missing}"
    ++ lib.optional (
      duplicated != [ ]
    ) "workspace family id(s) duplicated: ${lib.concatStringsSep ", " duplicated}"
    ++ lib.optional (
      unexpected != [ ]
    ) "workspace family has unexpected id(s): ${lib.concatStringsSep ", " unexpected}";

  validationFailuresFor =
    reg:
    idDuplicateFailuresFor reg
    ++ skhdKeyShapeFailures
    ++ renderedChordFailuresFor (darwinChordEntriesFor reg)
    ++ lib.concatLists (
      lib.imap0 (
        i: c:
        let
          name = c.id or "<entry ${toString i}>";
          err = msg: "${name}: ${msg}";
          unknownIn =
            where: allowed: attrs:
            map (f: err "unknown ${where} field `${f}`") (lib.subtractLists allowed (lib.attrNames attrs));
          chord = c.chord or { };
          platforms = c.platforms or { };
          declaredPlatforms = lib.intersectLists knownPlatforms (lib.attrNames platforms);
          checkPlatform =
            p:
            let
              entry = platforms.${p};
              known = knownRealizations.${p};
              r = entry.realization or null;
            in
            unknownIn "platforms.${p}" knownPlatformFields entry
            ++ lib.optional (r == null) (err "platforms.${p} is missing `realization`")
            ++ lib.optional (r != null && !lib.isString r) (err "platforms.${p} `realization` must be a string")
            ++ lib.optional (lib.isString r && !lib.elem r known) (
              err "unknown platforms.${p} realization \"${r}\" (known: ${lib.concatStringsSep ", " known})"
            )
            ++ lib.optional (p == "linux" && r == "niri-action" && !lib.isAttrs (entry.action or null)) (
              err "niri-action requires a typed `action` attrset"
            )
            ++ lib.optional (p == "darwin" && r == "skhd-exec" && entry ? action) (
              err "skhd-exec must not carry an `action` — its body is hand-authored in home/darwin/skhd.nix"
            );
        in
        map (f: err "missing required field `${f}`") (lib.filter (f: !(lib.hasAttr f c)) requiredCapFields)
        ++ unknownIn "top-level" knownCapFields c
        ++ unknownIn "chord" knownChordFields chord
        ++ lib.optional (c ? chord && !(chord ? key)) (err "chord is missing `key`")
        ++ lib.optional (c ? chord && !(chord ? tier)) (err "chord is missing `tier`")
        ++ lib.optional (chord ? tier && !lib.hasAttr chord.tier tiers) (
          err "unknown chord tier \"${chord.tier}\" (known: ${lib.concatStringsSep ", " (lib.attrNames tiers)})"
        )
        ++ map (
          m: err "unknown chord modifier \"${m}\" (known: ${lib.concatStringsSep ", " knownChordMods})"
        ) (lib.subtractLists knownChordMods (chord.mods or [ ]))
        ++ unknownIn "platforms" knownPlatforms platforms
        ++ lib.optional (declaredPlatforms == [ ]) (
          err "declares no platform realization (needs platforms.linux and/or platforms.darwin)"
        )
        ++ lib.concatMap checkPlatform declaredPlatforms
        ++ lib.optional (platforms ? darwin && chord ? key && !validDarwinKey chord.key) (
          err "chord key \"${chord.key}\" is not a verified skhd key token (skhdKey ∪ single [A-Za-z0-9])"
        )
      ) reg
    );
  # I4 (workspace-family completeness) is whole-registry-only (see its
  # comment above) so it's combined here rather than inside
  # validationFailuresFor itself.
  validationFailures = validationFailuresFor registry ++ workspaceFamilyFailuresFor registry;

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
    Comma = ",";
    Slash = "/";
    Semicolon = ";";
  };
  displayKeyFor = k: displayKey.${k} or k;
  # A capability is "realized" on a platform when it declares a realization
  # there; the table shows "—" otherwise (linux-only geometry, darwin-only
  # app-launch). ADR-040 introduced both directions.
  realizedOn = platform: cap: (cap.platforms.${platform}.realization or null) != null;
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
        if !(realizedOn platform cap) then
          "—"
        else if digit then
          lib.replaceStrings [ cap.chord.key ] [ "N" ] l
        else
          l;
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
    skhdChord
    skhdChords
    skhdChordsFor
    skhdCollisions
    skhdCollisionsFor
    darwinRealizedCapsFor
    collisions
    collisionsFor
    validationFailures
    validationFailuresFor
    idDuplicateFailuresFor
    skhdKeyShapeFailuresFor
    renderedChordFailuresFor
    darwinChordEntriesFor
    workspaceFamilyFailuresFor
    karabinerHyperRemapKeys
    descriptiveFor
    tierChordDisplay
    keybindsTable
    keybindsTableFor
    ;
}
