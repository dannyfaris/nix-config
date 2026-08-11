# niri's config.kdl as a KDL document — the repo-owned replacement for
# niri-flake's `programs.niri.settings` rendering (docs/design/niri-sourcing.md,
# rulings 1 + 2: plain data authored as nodes, serialized by the vendored
# lib/kdl.nix).
#
# This file is the single source for niri's settings AND for why each one is
# what it is; home/nixos/niri.nix renders it, gates it on `niri validate` and
# places it at ~/.config/niri/config.kdl. Comments starting "Encoding:" explain
# what the KDL shape — as opposed to the setting — makes non-obvious.
#
# Bind taxonomy and the modifier-namespace philosophy are single-sourced in
# docs/desktop/keybinds.md; the binds below are its implementation surface
# (doc-before-code: keybinds.md changes first, in the same PR).
#
# A pure function of `lib` plus the four values that need the module system to
# resolve (see arguments), so it evaluates standalone — which is what lets
# parts/checks.nix force both host shapes to render without a host.
{
  lib,
  # Design tokens (lib/theme-tokens.nix) — only its static geometry/layout
  # groups are read, so no Stylix eval is forced.
  tokens,
  # Cursor as home/nixos/niri.nix reads it back out of stylix.cursor, which
  # home/nixos/pointer-icons.nix owns: { theme, size }. Passed in rather than
  # resolved here so the niri cursor and the toolkit cursor cannot drift.
  cursor,
  # Absolute store path of the noctalia binary (`lib.getExe`), so session start
  # and the hardware-key spawns don't depend on PATH ordering.
  noctalia,
  # alnair's fragment: built-in panel, touchpad, power-key handling. Off for the
  # desktop hosts, which have none of them (#636 — the placement call this
  # `laptop` flag inherits from the retired home/nixos/niri-laptop.nix).
  laptop ? false,
}:
let
  kdl = import ./kdl.nix { inherit lib; };
  profile = import ./display-profiles.nix; # active display profile — output scale
  caps = import ./capabilities.nix { inherit lib; }; # single-source keybind registry (#384)

  bind = chord: action: lib.nameValuePair chord (kdl.node chord [ ] [ action ]);
  # allow-when-locked is a property of the *bind* node, not of the action.
  lockedBind =
    chord: action:
    lib.nameValuePair chord (kdl.node chord [ { allow-when-locked = true; } ] [ action ]);
  noctaliaMsg =
    args:
    kdl.leaf "spawn" (
      [
        noctalia
        "msg"
      ]
      ++ args
    );

  # Merge the registry-generated bind nodes over the hand-authored remainder,
  # asserting no hand-authored chord silently shadows a generated one. Both
  # sides are chord-keyed attrsets rather than node lists precisely so this
  # check survives the port — a bare `++` would emit duplicate bind nodes that
  # niri accepts silently (ADR-039 §8, #455).
  mergeBinds =
    generated: handAuthored:
    let
      shadowed = lib.intersectLists (lib.attrNames generated) (lib.attrNames handAuthored);
    in
    lib.throwIf (shadowed != [ ])
      "niri-config.nix: hand-authored bind(s) ${lib.concatStringsSep ", " shadowed} shadow registry-generated Hyper chords — declare them in lib/capabilities.nix instead (ADR-039 §8, #455)"
      (generated // handAuthored);

  # The cross-platform Hyper layer (Ctrl+Alt base) is generated from the
  # single-source capability registry (#384 / ADR-039) and merged over the
  # hand-authored remainder below. keyd realizes Caps Lock → Hyper at the evdev
  # layer (modules/nixos/keyd.nix). The remainder is the Super-namespace +
  # screenshot binds not yet in the registry — the Super layer retires under
  # #323; screenshots stay on Super+Shift. Niri does NOT merge a user bind set
  # with its 60+ defaults, it replaces them wholesale, which is why this set is
  # curated rather than additive (docs/desktop/niri.md §Sharp edges).
  binds = mergeBinds caps.niriBindNodes (
    lib.listToAttrs [
      # Navigation — focus (arrow + vim-style mirrors). Super-namespace; retired
      # under #323 when the Super layer lands. (The Hyper focus binds — Ctrl+Alt —
      # come from the registry above.)
      (bind "Mod+Left" (kdl.flag "focus-column-left"))
      (bind "Mod+Down" (kdl.flag "focus-window-down"))
      (bind "Mod+Up" (kdl.flag "focus-window-up"))
      (bind "Mod+Right" (kdl.flag "focus-column-right"))
      (bind "Mod+H" (kdl.flag "focus-column-left"))
      (bind "Mod+J" (kdl.flag "focus-window-down"))
      (bind "Mod+K" (kdl.flag "focus-window-up"))
      (bind "Mod+L" (kdl.flag "focus-column-right"))

      # Window close. Super+W (the Cmd-position W) is the cross-platform close:
      # niri has no separate WM force-close — only graceful close-window — so this
      # is the close bind, not an interim. See docs/desktop/keybinds.md.
      (bind "Mod+W" (kdl.flag "close-window"))

      # Workspaces — focus
      (bind "Mod+1" (kdl.leaf "focus-workspace" 1))
      (bind "Mod+2" (kdl.leaf "focus-workspace" 2))
      (bind "Mod+3" (kdl.leaf "focus-workspace" 3))
      (bind "Mod+4" (kdl.leaf "focus-workspace" 4))
      (bind "Mod+5" (kdl.leaf "focus-workspace" 5))
      (bind "Mod+6" (kdl.leaf "focus-workspace" 6))
      (bind "Mod+7" (kdl.leaf "focus-workspace" 7))
      (bind "Mod+8" (kdl.leaf "focus-workspace" 8))
      (bind "Mod+9" (kdl.leaf "focus-workspace" 9))

      # Spawn — terminal + application launcher. The launcher is Noctalia's
      # IPC-driven app launcher (ADR-036; v5 grammar, #644). Passed as an argv
      # list — niri spawns it directly (no shell). fuzzel was decommissioned in
      # #385.
      (bind "Mod+Return" (kdl.leaf "spawn" "foot"))
      (bind "Mod+Space" (
        kdl.leaf "spawn" [
          "noctalia"
          "msg"
          "panel-toggle"
          "launcher"
        ]
      ))

      # Session — quit (niri shows a confirmation dialog by default)
      (bind "Mod+Shift+E" (kdl.flag "quit"))

      # Discovery
      (bind "Mod+O" (kdl.flag "toggle-overview"))
      (bind "Mod+Shift+Slash" (kdl.flag "show-hotkey-overlay"))

      # Screenshots — niri's built-in capture, no external tool. Mirrors macOS
      # after the file/clipboard swap: bare Mod+Shift+N copies to clipboard
      # (write-to-disk=false), Mod+Ctrl+Shift+N saves to disk (+ clipboard). +5
      # is window capture (niri has no capture-options bar). Region capture is
      # the interactive overlay, which always does both disk+clipboard — so
      # Mod+Shift+4 and Mod+Ctrl+Shift+4 are equivalent. The Print family stays
      # on niri's defaults (disk+clipboard). See docs/desktop/keybinds.md
      # §Screenshots (#100, #323).
      #
      # Encoding: write-to-disk is an action *property*, hence a leaf's payload.
      (bind "Mod+Shift+3" (kdl.leaf "screenshot-screen" { write-to-disk = false; }))
      (bind "Mod+Shift+4" (kdl.flag "screenshot"))
      (bind "Mod+Shift+5" (kdl.leaf "screenshot-window" { write-to-disk = false; }))
      (bind "Mod+Ctrl+Shift+3" (kdl.flag "screenshot-screen"))
      (bind "Mod+Ctrl+Shift+4" (kdl.flag "screenshot"))
      (bind "Mod+Ctrl+Shift+5" (kdl.flag "screenshot-window"))
      (bind "Print" (kdl.flag "screenshot"))
      (bind "Ctrl+Print" (kdl.flag "screenshot-screen"))
      (bind "Alt+Print" (kdl.flag "screenshot-window"))

      # Hardware media/volume/brightness keys — XF86* keys are their own
      # namespace (not registry chords), routed to Noctalia's IPC so its native
      # OSD owns presentation. allow-when-locked on the volume trio only.
      # Rationale: docs/desktop/audio.md.
      (lockedBind "XF86AudioRaiseVolume" (noctaliaMsg [ "volume-up" ]))
      (lockedBind "XF86AudioLowerVolume" (noctaliaMsg [ "volume-down" ]))
      (lockedBind "XF86AudioMute" (noctaliaMsg [ "volume-mute" ]))
      (bind "XF86AudioMicMute" (noctaliaMsg [ "mic-mute" ]))
      (bind "XF86AudioPlay" (noctaliaMsg [
        "media"
        "toggle"
      ]))
      (bind "XF86AudioNext" (noctaliaMsg [
        "media"
        "next"
      ]))
      (bind "XF86AudioPrev" (noctaliaMsg [
        "media"
        "previous"
      ]))
      (bind "XF86MonBrightnessUp" (noctaliaMsg [ "brightness-up" ]))
      (bind "XF86MonBrightnessDown" (noctaliaMsg [ "brightness-down" ]))
    ]
  );

  # Input — pointer focus, plus compositor-layer keyboard/mouse (and, on the
  # laptop, touchpad) ergonomics (#107). Device-layer DPI/buttons/onboard
  # profiles live on the G502 (libratbag/ratbagd), not here. niri configures
  # input by device *category*, not by device name. See docs/desktop/input.md.
  inputChildren = [
    (kdl.plain "keyboard" [
      # Snappier than niri's sluggish 600ms / 25-per-second defaults.
      (kdl.leaf "repeat-delay" 250)
      (kdl.leaf "repeat-rate" 40)
    ])
  ]
  # Touchpad — mirrors the operator's MacBook Air feel. Behavioural translation,
  # not a settings import; full table in #636.
  ++ lib.optional laptop (
    kdl.plain "touchpad" [
      (kdl.flag "dwt") # disable-while-typing — macOS does this implicitly
      (kdl.flag "natural-scroll") # macOS default (natural)
      (kdl.leaf "accel-speed" 0.0) # honest starting point; the one value expected to tune on-metal
      (kdl.leaf "click-method" "clickfinger") # the Mac-defining setting — two-finger = right-click
      # Tap-to-click stays off (Clicking=0 on the Air — physical click only).
      # Encoding: that is the flag's *absence*; there is no `tap false`.
    ]
  )
  ++ [
    (kdl.plain "mouse" [
      # Wheel direction matches macOS's natural scrolling (operator runs a Mac).
      (kdl.flag "natural-scroll")
      # Flat (constant) accel so compositor accel doesn't compound with the
      # G502's onboard DPI; sensitivity is owned by the mouse (accel-speed 0).
      (kdl.leaf "accel-speed" 0.0)
      (kdl.leaf "accel-profile" "flat")
    ])
    # Pointer focus (#366) — hovering focuses a nearby window, but
    # max-scroll-amount caps how far niri will scroll the workspace to do so (as
    # a fraction of working-area width), so a large off-screen move isn't
    # triggered by crossing the pointer over it. 17% is tuned to the 2/3
    # default-width geometry and pending live confirmation on the desktop hosts
    # — see docs/desktop/niri.md §Configuration.
    #
    # Encoding: the cap is a property and the node has no children, so this is a
    # leaf rather than a `focus-follows-mouse { … }` block.
    (kdl.leaf "focus-follows-mouse" { max-scroll-amount = "17%"; })
  ]
  # niri hard-binds XF86PowerOff → Suspend by default; the wake press is
  # redelivered to niri after resume and key-repeats into a suspend storm — the
  # un-wakeable-laptop loop (#636 on-metal finding). Single owner: logind (the
  # mobility bundle pins HandlePowerKey=ignore alongside this).
  #
  # Encoding: disabling it is a positively-named sibling flag, not a
  # `power-key-handling` node.
  ++ lib.optional laptop (kdl.flag "disable-power-key-handling");

  windowRules =
    let
      # Rounded corners on every window. The border (and focus ring, if on)
      # follow this radius; clip-to-geometry trims each client's square surface
      # to the rounded rect so corners don't poke past the border. Radius from
      # the geometry token (M3 ladder). Encoding: niri types corner radii as
      # float, so coerce the int token or the document emits `12` where niri
      # expects a float.
      r = tokens.geometry.cornerRadius + 0.0;
      onePassword = kdl.leaf "match" { app-id = "^1[Pp]assword$"; };
    in
    [
      # Rule order is semantic — niri applies rules in document order and later
      # rules win.
      (kdl.plain "window-rule" [
        (kdl.leaf "geometry-corner-radius" [
          r
          r
          r
          r
        ])
        (kdl.leaf "clip-to-geometry" true)
      ])

      # Keep the capture routes that run without a human at the console (grim
      # over wlr-screencopy; niri's automatic screenshot-screen/-window actions)
      # from becoming a credential channel (#529) — the interactive screenshot
      # UI still shows the window. app-id is PROVISIONAL: pin it from
      # `niri msg windows`, since an unmatched rule is silently inert.
      # See docs/desktop/screen-capture.md §Sharp edges.
      (kdl.plain "window-rule" [
        onePassword
        (kdl.leaf "block-out-from" "screen-capture")
      ])

      # Utility-palette apps float above the ribbon instead of tiling into it;
      # escape hatch is toggle-window-floating (Hyper+Shift+Space, from the
      # registry). nautilus app-id pinned from a live window; the 1Password
      # regex shares the PROVISIONAL status of the #529 rule above.
      #
      # Encoding: repeated `match` nodes are OR, one per matcher.
      (kdl.plain "window-rule" [
        (kdl.leaf "match" { app-id = "^org\\.gnome\\.Nautilus$"; })
        onePassword
        (kdl.leaf "open-floating" true)
      ])

      # Electron 1Password restores its last-saved window bounds, which can be a
      # full-tile size if it ever ran tiled; pin its floating open size. Nautilus
      # already persists a sane size itself, so it's left alone.
      (kdl.plain "window-rule" [
        onePassword
        (kdl.plain "default-column-width" [ (kdl.leaf "proportion" 0.5) ])
        (kdl.plain "default-window-height" [ (kdl.leaf "proportion" 0.5) ])
      ])
    ];

  # Node order at top level is not semantic to niri, but it mirrors what
  # niri-flake rendered before #763 so the migration diff stays readable.
  document = [
    (kdl.plain "input" inputChildren)

    # Output scale from the active display profile, pinned rather than left to
    # niri's auto-detection. DP-1 is the LG UltraFine 4K. See
    # lib/display-profiles.nix.
    (kdl.node "output" [ "DP-1" ] [ (kdl.leaf "scale" profile.scale) ])
  ]
  # eDP-1 is alnair's built-in panel (2496×1664 3:2, ~201 PPI — the fleet's
  # first built-in HiDPI). It rides the fleet display profile so
  # scale/fonts/geometry stay in lockstep (the whole point of
  # display-profiles.nix). Open question: whether this panel wants its OWN
  # profile (e.g. 1.5× while desktops run 2.0×) is the on-metal tuning call and
  # would force per-host profiles — see #636.
  ++ lib.optional laptop (kdl.node "output" [ "eDP-1" ] [ (kdl.leaf "scale" profile.scale) ])
  ++ [
    # Capture target, set explicitly so it stays in lockstep with the directory
    # home/nixos/niri.nix creates — niri creates only the last path component
    # and silently drops the shot when the parent is missing (niri #807). See
    # docs/desktop/keybinds.md §Screenshots.
    (kdl.leaf "screenshot-path" "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png")

    # No client-side decorations — niri asks clients to drop their own titlebars
    # and draws its border instead. Titlebars are wasted space when tiling; foot
    # honours this and drops its top bar.
    (kdl.flag "prefer-no-csd")

    # Layout primitives — column width, centering, decorations, and inter-window
    # gap in one block (geometry/spacing from tokens).
    (kdl.plain "layout" [
      # Inter-window gap — explicit token (= Carbon spacing-05) rather than
      # niri's implicit default 16, so the value lives in one place. See
      # theme-tokens.nix and docs/desktop/visual-identity.md §Spacing.
      (kdl.leaf "gaps" tokens.layout.gap)

      # Window decorations — border on, focus-ring off; the active/inactive
      # colours come from the theme-menu conductor's niri.kdl (the include
      # below), not from here. Border width from the geometry token (Carbon
      # spacing-01; crisp on 4K/2× — rationale in theme-tokens.nix and
      # docs/desktop/niri.md §Window decorations).
      #
      # Encoding: turning the focus ring off is an `off` child flag, not an
      # omitted node — niri's own default has it on.
      (kdl.plain "focus-ring" [ (kdl.flag "off") ])
      (kdl.plain "border" [ (kdl.leaf "width" tokens.geometry.borderWidth) ])

      # Window open-width — new windows open at the 2/3 preset proportion,
      # leaving a third for a companion column. Exactly 2/3 (not ~0.66) so a
      # freshly-opened window sits on niri's switch-preset-column-width cycle
      # (Hyper+R). niri otherwise honours each client's own preferred size,
      # which is why foot (its ~80×24 default) opened narrow. This overrides
      # that for all windows. See docs/desktop/niri.md §Configuration.
      (kdl.plain "default-column-width" [ (kdl.leaf "proportion" (2. / 3.)) ])

      # Auto-centering (#366) — center the focused column only when it doesn't
      # fit on screen alongside the previously-focused column (on-overflow), and
      # always center a lone column rather than scroll it to an edge. The manual
      # Hyper+Shift+C center-column bind is separate. See
      # docs/desktop/niri.md §Configuration.
      (kdl.leaf "center-focused-column" "on-overflow")
      (kdl.flag "always-center-single-column")
    ])

    # Compositor cursor. The values are stylix's, threaded in by
    # home/nixos/niri.nix, so the compositor layer and the toolkit layer cannot
    # drift — see docs/desktop/pointer-icons.md.
    (kdl.plain "cursor" [
      (kdl.leaf "xcursor-theme" cursor.theme)
      (kdl.leaf "xcursor-size" cursor.size)
    ])

    (kdl.plain "binds" (lib.attrValues binds))

    # Noctalia Shell v5 — spawned at session start (ADR-036; #644). The store
    # path is pinned, so session start doesn't depend on PATH ordering.
    (kdl.leaf "spawn-at-startup" [ noctalia ])
  ]
  ++ windowRules
  ++ [
    # Hand niri's window-border colour to the theme-menu conductor at runtime
    # (ADR-044, #609 — replacing the Noctalia-owned noctalia.kdl per ADR-036).
    # Last in the document so it wins. `optional=true` (niri 26.04) keeps the
    # session up before the seed first creates the target symlink.
    (kdl.node "include"
      [
        "~/.local/state/theme-menu/niri.kdl"
        { optional = true; }
      ]
      [ ]
    )
  ];
in
{
  # The document as nodes, for tests and for callers that want to extend it.
  nodes = document;

  # …and rendered, for home/nixos/niri.nix's validate-and-place derivation.
  # Trailing newline so the file ends the way a text file should.
  text = kdl.serialize.nodes document + "\n";
}
