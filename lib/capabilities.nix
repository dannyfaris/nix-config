# Single-source capability registry — one declaration per cross-platform
# interaction capability, from which every surface is generated (ADR-039).
#
# Phase 1 (#384) delivered: the three-dimension schema, the `Hyper` modifier
# constant, the niri emitter, and the eval-time collision lint. The macOS
# window-management slice (#440) added the `Ctrl+Opt` darwin base; ADR-040
# (#494) then replaced the original pure-Hammerspoon realization with AeroSpace,
# so `platforms.darwin` now carries `aerospace-action` (emitted verbatim) and
# `aerospace-exec` (hand-authored body) realizations alongside its descriptive
# overrides. #457 adds the keybinds.md table emitter (the human-facing surface,
# generated from the descriptive dimension). The unified palette (#442) and the
# actions.json dataset (#437) remain later phases.
#
# Repo-decoupled by design (ADR-039 §9 — extraction-ready): this unit takes
# only { lib } and imports no repo modules, so packaging it standalone later
# stays cheap. The AeroSpace emitter emits only pure binding *values*
# (`aerospace-action`); the `aerospace-exec` complex bodies (which need the
# package-derived `aerospace` path) are hand-authored in home/darwin/
# aerospace.nix, mirroring how `niriBinds` emits binds the niri module composes
# — the codegen stays pure (ADR-039 §2).
#
# Consumers:
#   - home/nixos/niri.nix         → `niriBinds` (the generated bind attrset)
#   - home/darwin/aerospace.nix   → `aerospaceBinds` (the emitted
#                                    mode.main.binding attrset) + `aerospaceExecCaps`
#                                    + `aerospaceChord` (the hand-authored exec
#                                    bodies are keyed by cap id and chorded from
#                                    the registry entries, #537)
#   - modules/nixos/keyd.nix      → `tiers.hyper.linux` (substrate reads the
#                                    same constant — base shape is one edit, §4)
#   - home/darwin/karabiner.nix   → `tiers.hyper.darwin` (the Ctrl+Opt substrate)
#                                    + `karabinerHyperRemapKeys` (now emptied —
#                                    the Mission-Control remaps retired, ADR-040)
#   - parts/checks.nix            → `collisions` + `darwinCollisions` +
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
    # Consumed by the AeroSpace chord renderer (below) and the Karabiner
    # Ctrl+Opt substrate (home/darwin/karabiner.nix), #440 / ADR-040.
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
  # the AeroSpace chord renderer below. (Hammerspoon's `hs.hotkey.bind` renderer
  # was retired with Hammerspoon itself, ADR-040.)
  darwinMod = {
    Ctrl = "ctrl";
    Alt = "alt";
    Option = "alt";
    Super = "cmd";
    Shift = "shift";
  };
  # Canonical mod order for a deterministic chord string (the dedup lint groups
  # on it). AeroSpace treats the mods as a set, so any fixed order binds the same.
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

  # ── AeroSpace (darwin) chord rendering ─────────────────────────────────────
  # AeroSpace's `[mode.main.binding]` keys are hyphen-joined lowercase tokens
  # (e.g. `ctrl-alt-shift-left`). The tier's base modifiers (Ctrl+Opt) plus any
  # escalator `mods` map to AeroSpace's mod tokens (same set as hs: ctrl/alt/
  # shift/cmd — Option→alt, Super→cmd); the key token maps to AeroSpace's key
  # name. The key names are verified against the pinned AeroSpace source
  # (v0.20.3-Beta, Sources/AppBundle/config/keysMap.swift): Return→`enter`,
  # arrows/comma/slash/semicolon/minus/equal/tab as below, letters/digits
  # lowercased. A wrong key name is a whole-config parse error (not a silent
  # no-op), so these are pinned to that source. AeroSpace treats the modifier
  # set order-independently; the fixed ctrl/alt/shift/cmd order (sortDarwinMods)
  # keeps the emitted string deterministic so the dedup lint groups on it.
  asKey = {
    Left = "left";
    Right = "right";
    Up = "up";
    Down = "down";
    Return = "enter";
    Tab = "tab";
    Minus = "minus";
    Equal = "equal";
    Comma = "comma";
    Slash = "slash";
    Semicolon = "semicolon";
    Space = "space";
  };
  asKeyFor = k: asKey.${k} or (lib.toLower k);
  aerospaceChord =
    chord: lib.concatStringsSep "-" (darwinModTokens chord ++ [ (asKeyFor chord.key) ]);

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
      # AeroSpace workspaces (ADR-040) — "Space" prose kept: AeroSpace's
      # workspaces are the user-facing "spaces" on macOS. All nine bound
      # (operator decision, #494) — the trial exercised 1‑4.
      realization = "aerospace-action";
      action = "workspace ${toString n}";
      label = "Switch to workspace ${toString n}";
      description = "Switch to the numbered AeroSpace workspace";
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
      realization = "aerospace-action";
      action = "move-node-to-workspace ${toString n}";
      label = "Move window to workspace ${toString n}";
      description = "Move the focused window to the numbered AeroSpace workspace";
      keywords = [
        "move"
        "window"
        "workspace"
        "space"
        "send"
      ];
    };
  }) (lib.range 1 9);

  # ── darwin-only capabilities (ADR-040) ─────────────────────────────────────
  # macOS-only binds with no niri twin: app-launch, the tiles↔accordion toggle,
  # the service-mode leader, maximise-by-isolation, and cycle-terminal-windows.
  # They live in the
  # registry (not hand-authored) so the future palette/cheatsheet (ADR-039 §6,
  # registry-only dataset) can show them and the collision lint covers them.
  # `platforms.linux` is omitted (structural "linux: N/A"); the keybinds.md
  # table renders "—" for the unrealized platform.
  #
  # App-launch: `open -a` is focus-or-launch; `/usr/bin/open` is on the
  # exec-and-forget default PATH, so no nix-store path is needed (only the
  # `aerospace` CLI itself needs the package-derived path — that's the
  # aerospace-exec binds, hand-authored in aerospace.nix).
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
      platforms.darwin = {
        realization = "aerospace-action";
        action = "exec-and-forget open -a ${lib.escapeShellArg app}";
      };
    };
  darwinWmExtras = [
    (mkAppLaunch {
      id = "open-finder";
      key = "F";
      app = "Finder";
      label = "Open Finder";
      keywords = [
        "finder"
        "files"
        "launch"
      ];
    })
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
    (mkAppLaunch {
      id = "open-1password";
      key = "Slash";
      app = "1Password";
      label = "Open 1Password";
      keywords = [
        "1password"
        "passwords"
        "vault"
        "launch"
      ];
    })
    {
      id = "layout-toggle";
      label = "Toggle tiles/accordion";
      description = "Toggle the focused workspace between tiles and accordion layout";
      keywords = [
        "layout"
        "tiles"
        "accordion"
        "toggle"
      ];
      chord = {
        tier = "hyper";
        key = "Comma";
      };
      platforms.darwin = {
        realization = "aerospace-action";
        action = "layout tiles accordion";
      };
    }
    {
      id = "service-mode";
      label = "Service mode";
      description = "Enter the AeroSpace service mode (reload / flatten-tree / float-toggle / close-others)";
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
      platforms.darwin = {
        realization = "aerospace-action";
        action = "mode service";
      };
    }
    {
      # aerospace-exec: body hand-authored in home/darwin/aerospace.nix (it
      # shells out to the `aerospace` CLI by absolute path). AeroSpace has no
      # stable maximize (`fullscreen` drops on focus-change), so this isolates
      # the focused window onto its own empty workspace instead.
      id = "maximise-by-isolation";
      label = "Maximise (isolate)";
      description = "Move the focused window to its own empty workspace (the focus-stable maximize)";
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
      platforms.darwin.realization = "aerospace-exec";
    }
    {
      # aerospace-exec: body hand-authored in home/darwin/aerospace.nix (it
      # shells out to the `aerospace` CLI by absolute path). Cycles focus
      # through all Ghostty windows across workspaces; from a non-Ghostty
      # window it focuses the first. Pairs with spawn-terminal (Hyper+Return
      # = new window; +Shift = cycle existing).
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
      platforms.darwin.realization = "aerospace-exec";
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
      # aerospace-exec: the edge-scroll fallthrough is a *complex* bind (it
      # shells out to the `aerospace` CLI by absolute path), so its body is
      # hand-authored in home/darwin/aerospace.nix; here it contributes the
      # chord + descriptive for the palette/table/collision-lint. Darwin-
      # specific behaviour (not a faithful focus-column mirror): at the edge it
      # switches workspace (wrap-around) and lands on the far column.
      platforms.darwin = {
        realization = "aerospace-exec";
        label = "Focus window left";
        description = "Move focus left; at the left edge, wrap to the previous workspace's far column";
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
      # aerospace-exec (edge-scroll) — see focus-column-left. Body hand-authored
      # in home/darwin/aerospace.nix.
      platforms.darwin = {
        realization = "aerospace-exec";
        label = "Focus window right";
        description = "Move focus right; at the right edge, wrap to the next workspace's far column";
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
        realization = "aerospace-action";
        action = "focus up";
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
        realization = "aerospace-action";
        action = "focus down";
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
        realization = "aerospace-action";
        action = "workspace-back-and-forth";
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

    # Base Hyper — window geometry. On macOS these are structurally "darwin:
    # N/A" (no platforms.darwin): AeroSpace auto-tiles, so per-window geometry
    # is superseded (ADR-040, superseding ADR-039 §7's Hammerspoon geometry
    # handlers). The capability IDs + their niri realization stay — the Linux
    # side still uses them, and a future Hyprland move could re-realize
    # center/maximize (design note §Future). Hyper+F and Hyper+M are reused on
    # darwin for app-launch (open-finder / open-messages, below).
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
      # darwin: N/A (AeroSpace auto-tiles; ADR-040).
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
      # darwin: N/A (AeroSpace auto-tiles; ADR-040).
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
      # darwin: N/A — niri-ism, no AeroSpace equivalent (ADR-040).
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
      # darwin: N/A — niri-ism, no AeroSpace equivalent (ADR-040).
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
      # darwin: N/A — AeroSpace `fullscreen` drops on focus-change; the focus-
      # stable equivalent is maximise-by-isolation (Hyper+Shift+M, below).
      # Hyper+F is reused on darwin for open-finder. (ADR-040.)
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
      # darwin: N/A — AeroSpace has no stable maximize; the equivalent is
      # maximise-by-isolation (Hyper+Shift+M, below). Hyper+M is reused on
      # darwin for open-messages. (ADR-040.)
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
        realization = "aerospace-action";
        action = "exec-and-forget open -na Ghostty.app";
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
        realization = "aerospace-action";
        action = ''exec-and-forget open -a "Google Chrome"'';
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
        realization = "aerospace-action";
        action = "move left";
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
        realization = "aerospace-action";
        action = "move right";
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
        realization = "aerospace-action";
        action = "move up";
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
        realization = "aerospace-action";
        action = "move down";
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
    # Hyper+Shift "move" tier). darwin: N/A — under AeroSpace, workspace
    # switching is Hyper+1‑9 / the Hyper+←/→ edge-scroll / Hyper+Tab, and there
    # is no Mission Control to open (ADR-040). The capability IDs + niri
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
      # darwin: N/A (ADR-040).
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
      # darwin: N/A (ADR-040).
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

  # ── AeroSpace (darwin) emitter ─────────────────────────────────────────────
  # Darwin window management is realized by AeroSpace (ADR-040, superseding
  # ADR-039 §7's pure-Hammerspoon realization). Two darwin realization types:
  #   • `aerospace-action` — a pure AeroSpace binding value the emitter writes
  #     verbatim into `[mode.main.binding]` (`focus up`, `workspace 1`, or an
  #     `exec-and-forget open …` app-launch). The payload is `platforms.darwin.
  #     action` (a string). App-launch uses bare `open` (/usr/bin/open is on the
  #     `exec-and-forget` bash default PATH — no nix profile needed).
  #   • `aerospace-exec` — a *complex* bind whose body must call the `aerospace`
  #     CLI by an absolute (package-derived) path, which this repo-decoupled unit
  #     (only `{ lib }`, ADR-039 §9) cannot form. Its body is hand-authored in
  #     home/darwin/aerospace.nix (`lib.getExe cfg.package`); here it contributes
  #     only its *chord + descriptive* so the palette/table/collision-lint see
  #     it. The emitter does NOT emit it. Today: the `Hyper+←/→` edge-scroll,
  #     `Hyper+Shift+M` maximise-by-isolation, and `Hyper+Shift+Return`
  #     cycle-terminal-windows.
  # `aerospaceBinds` is the attrset home/darwin/aerospace.nix merges into
  # `programs.aerospace.settings.mode.main.binding` (the hand-authored
  # aerospace-exec bodies are merged alongside it). Parametrised over a registry
  # so the unit tests can drive it with fixtures.
  isAerospaceAction = c: (c.platforms.darwin.realization or null) == "aerospace-action";
  isAerospaceExec = c: (c.platforms.darwin.realization or null) == "aerospace-exec";
  isAerospaceBind = c: isAerospaceAction c || isAerospaceExec c;
  aerospaceBindsFor =
    reg:
    lib.listToAttrs (
      map (c: lib.nameValuePair (aerospaceChord c.chord) c.platforms.darwin.action) (
        lib.filter isAerospaceAction reg
      )
    );
  aerospaceBinds = aerospaceBindsFor registry;
  # The exec-realized caps themselves, exported for home/darwin/aerospace.nix:
  # it keys its hand-authored bodies by these ids, renders their chords from
  # these entries, and asserts its body set matches this list exactly (#537).
  aerospaceExecCaps = lib.filter isAerospaceExec registry;

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

  # ── Collision lint — darwin (ADR-039 §8; ADR-040) ──────────────────────────
  # The macOS chord space is now owned by AeroSpace alone (Hammerspoon retired,
  # ADR-040). The lint operates on the **merged** AeroSpace namespace — every
  # darwin bind, whether the emitter writes it (`aerospace-action`) or
  # home/darwin/aerospace.nix hand-authors it (`aerospace-exec`) — so a
  # hand-authored complex bind cannot silently double-bind a chord the emitter
  # already claims (the Stage-1 requirement in #494). Because both realization
  # types are declared in *this* registry, the lint reads one source and needs
  # no cross-module knowledge of aerospace.nix. No darwin F-row rule: macOS
  # Ctrl+Opt+F1‑12 is not niri's unbindable VT switch, so that reservation is
  # Linux-only.
  #
  # The Karabiner Mission-Control / Space-jump remaps are gone (ADR-040): Hyper+
  # arrows / Hyper+1‑9 fall through to AeroSpace instead of native Spaces, so
  # `karabinerHyperRemapKeys` is emptied permanently and the old reserved-chord
  # logic is dropped. home/darwin/karabiner.nix still reads this attr to build
  # its (now empty) remap manipulators — #488's empty-manipulator filter drops
  # the resulting empty rules — so the attr is kept, not deleted.
  karabinerHyperRemapKeys = {
    arrows = [ ];
    numbers = [ ];
  };
  darwinCollisionsFor =
    reg:
    let
      entries = map (c: {
        inherit (c) id;
        chord = aerospaceChord c.chord;
      }) (lib.filter isAerospaceBind reg);
      byChord = lib.groupBy (e: e.chord) entries;
      dupFailures = lib.mapAttrsToList (
        chord: es:
        "duplicate darwin chord ${chord}: claimed by ${lib.concatMapStringsSep ", " (e: e.id) es}"
      ) (lib.filterAttrs (_chord: es: lib.length es > 1) byChord);
    in
    dupFailures;
  darwinCollisions = darwinCollisionsFor registry;

  # ── Registry shape validation (#535) ───────────────────────────────────────
  # The emitters and lints above SELECT entries by matching known field values
  # (isNiriAction, isAerospaceBind, …), so a malformed entry — typo'd
  # realization tag, misspelled field, unmapped key token — is an *absence*,
  # not an error: dropped from emission and invisible to the collision lint
  # (docs/reviews/engineering-review-2026-07-06.md §1). This pass makes the
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
    darwin = [
      "aerospace-action"
      "aerospace-exec"
    ];
  };
  # The escalator tokens BOTH chord renderers can map (darwinMod's domain);
  # the niri renderer passes unknown tokens through and defers to build-time
  # `niri validate`, so this stricter cross-platform set is the gate.
  knownChordMods = lib.attrNames darwinMod;
  # A darwin-bindable key token: an explicit asKey name, or a single
  # letter/digit (asKeyFor lowercases those). Anything else would be
  # lowercased into the config and reject the WHOLE file at AeroSpace's
  # runtime parse — this check moves that failure to eval.
  validDarwinKey = k: lib.hasAttr k asKey || builtins.match "[A-Za-z0-9]" k != null;
  validationFailuresFor =
    reg:
    lib.concatLists (
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
            ++ lib.optional (p == "darwin" && r == "aerospace-action" && !lib.isString (entry.action or null)) (
              err "aerospace-action requires a verbatim `action` string"
            )
            ++ lib.optional (p == "darwin" && r == "aerospace-exec" && entry ? action) (
              err "aerospace-exec must not carry an `action` — its body is hand-authored in home/darwin/aerospace.nix"
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
          err "chord key \"${chord.key}\" is not a verified AeroSpace key token (asKey ∪ single [A-Za-z0-9])"
        )
      ) reg
    );
  validationFailures = validationFailuresFor registry;

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
    aerospaceChord
    aerospaceBinds
    aerospaceBindsFor
    aerospaceExecCaps
    collisions
    collisionsFor
    darwinCollisions
    darwinCollisionsFor
    validationFailures
    validationFailuresFor
    karabinerHyperRemapKeys
    descriptiveFor
    tierChordDisplay
    keybindsTable
    keybindsTableFor
    ;
}
