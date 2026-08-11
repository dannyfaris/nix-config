# niri's config.kdl as a KDL document — the repo-owned replacement for
# niri-flake's `programs.niri.settings` rendering (docs/design/niri-sourcing.md,
# rulings 1 + 2: plain data authored as nodes, serialized by the vendored
# lib/kdl.nix).
#
# INERT: nothing imports this yet. home/nixos/niri.nix and
# home/nixos/niri-laptop.nix still generate the live document through
# niri-flake; this file is built and diffed against them first (slice A), and
# only then swapped in.
#
# Rationale for the *settings themselves* is single-sourced in the modules that
# still own them — home/nixos/niri.nix, home/nixos/niri-laptop.nix and
# home/nixos/pointer-icons.nix (the cursor block). Those comments move here when
# this file becomes the live source; duplicating them now would fork them.
# Comments below explain only what the KDL *encoding* makes non-obvious.
#
# A pure function of `lib` plus the four values that need the module system to
# resolve (see arguments), so it evaluates standalone — that is what lets the
# migration diff old-vs-new documents without a host.
{
  lib,
  # Design tokens (lib/theme-tokens.nix) — only its static geometry/layout
  # groups are read, so no Stylix eval is forced.
  tokens,
  # Cursor as home/nixos/pointer-icons.nix resolves it from stylix.cursor:
  # { theme, size }. Passed in rather than read here so the niri cursor and the
  # toolkit cursor still cannot drift.
  cursor,
  # Absolute store path of the noctalia binary (`lib.getExe`), so session start
  # and the hardware-key spawns don't depend on PATH ordering.
  noctalia,
  # alnair's fragment (home/nixos/niri-laptop.nix): built-in panel, touchpad,
  # power-key handling. Off for the desktop hosts, which have none of them.
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

  binds = mergeBinds caps.niriBindNodes (
    lib.listToAttrs [
      (bind "Mod+Left" (kdl.flag "focus-column-left"))
      (bind "Mod+Down" (kdl.flag "focus-window-down"))
      (bind "Mod+Up" (kdl.flag "focus-window-up"))
      (bind "Mod+Right" (kdl.flag "focus-column-right"))
      (bind "Mod+H" (kdl.flag "focus-column-left"))
      (bind "Mod+J" (kdl.flag "focus-window-down"))
      (bind "Mod+K" (kdl.flag "focus-window-up"))
      (bind "Mod+L" (kdl.flag "focus-column-right"))

      (bind "Mod+W" (kdl.flag "close-window"))

      (bind "Mod+1" (kdl.leaf "focus-workspace" 1))
      (bind "Mod+2" (kdl.leaf "focus-workspace" 2))
      (bind "Mod+3" (kdl.leaf "focus-workspace" 3))
      (bind "Mod+4" (kdl.leaf "focus-workspace" 4))
      (bind "Mod+5" (kdl.leaf "focus-workspace" 5))
      (bind "Mod+6" (kdl.leaf "focus-workspace" 6))
      (bind "Mod+7" (kdl.leaf "focus-workspace" 7))
      (bind "Mod+8" (kdl.leaf "focus-workspace" 8))
      (bind "Mod+9" (kdl.leaf "focus-workspace" 9))

      (bind "Mod+Return" (kdl.leaf "spawn" "foot"))
      (bind "Mod+Space" (
        kdl.leaf "spawn" [
          "noctalia"
          "msg"
          "panel-toggle"
          "launcher"
        ]
      ))

      (bind "Mod+Shift+E" (kdl.flag "quit"))

      (bind "Mod+O" (kdl.flag "toggle-overview"))
      (bind "Mod+Shift+Slash" (kdl.flag "show-hotkey-overlay"))

      # write-to-disk is an action *property*: clipboard-only capture.
      (bind "Mod+Shift+3" (kdl.leaf "screenshot-screen" { write-to-disk = false; }))
      (bind "Mod+Shift+4" (kdl.flag "screenshot"))
      (bind "Mod+Shift+5" (kdl.leaf "screenshot-window" { write-to-disk = false; }))
      (bind "Mod+Ctrl+Shift+3" (kdl.flag "screenshot-screen"))
      (bind "Mod+Ctrl+Shift+4" (kdl.flag "screenshot"))
      (bind "Mod+Ctrl+Shift+5" (kdl.flag "screenshot-window"))
      (bind "Print" (kdl.flag "screenshot"))
      (bind "Ctrl+Print" (kdl.flag "screenshot-screen"))
      (bind "Alt+Print" (kdl.flag "screenshot-window"))

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

  inputChildren = [
    (kdl.plain "keyboard" [
      (kdl.leaf "repeat-delay" 250)
      (kdl.leaf "repeat-rate" 40)
    ])
  ]
  ++ lib.optional laptop (
    kdl.plain "touchpad" [
      (kdl.flag "dwt")
      (kdl.flag "natural-scroll")
      (kdl.leaf "accel-speed" 0.0)
      (kdl.leaf "click-method" "clickfinger")
      # tap-to-click stays off, which in KDL is the flag's *absence* — there is
      # no `tap false`.
    ]
  )
  ++ [
    (kdl.plain "mouse" [
      (kdl.flag "natural-scroll")
      (kdl.leaf "accel-speed" 0.0)
      (kdl.leaf "accel-profile" "flat")
    ])
    # focus-follows-mouse carries its cap as a property and has no children.
    (kdl.leaf "focus-follows-mouse" { max-scroll-amount = "17%"; })
  ]
  # Disabling niri's power-key handling is a positively-named sibling flag,
  # not a `power-key-handling` node.
  ++ lib.optional laptop (kdl.flag "disable-power-key-handling");

  windowRules =
    let
      # niri types corner radii as float; the geometry token is an int, so
      # coerce it or the document emits `12` where niri expects `12.000000`.
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
      (kdl.plain "window-rule" [
        onePassword
        (kdl.leaf "block-out-from" "screen-capture")
      ])
      (kdl.plain "window-rule" [
        # Repeated `match` nodes are OR, one per matcher.
        (kdl.leaf "match" { app-id = "^org\\.gnome\\.Nautilus$"; })
        onePassword
        (kdl.leaf "open-floating" true)
      ])
      (kdl.plain "window-rule" [
        onePassword
        (kdl.plain "default-column-width" [ (kdl.leaf "proportion" 0.5) ])
        (kdl.plain "default-window-height" [ (kdl.leaf "proportion" 0.5) ])
      ])
    ];

  # Node order at top level is not semantic to niri, but it mirrors what
  # niri-flake renders today so the migration diff stays readable.
  document = [
    (kdl.plain "input" inputChildren)
    (kdl.node "output" [ "DP-1" ] [ (kdl.leaf "scale" profile.scale) ])
  ]
  ++ lib.optional laptop (kdl.node "output" [ "eDP-1" ] [ (kdl.leaf "scale" profile.scale) ])
  ++ [
    (kdl.leaf "screenshot-path" "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png")
    (kdl.flag "prefer-no-csd")
    (kdl.plain "layout" [
      (kdl.leaf "gaps" tokens.layout.gap)
      # `enable = false` for the focus ring is an `off` child flag, not an
      # omitted node — niri's own default has it on.
      (kdl.plain "focus-ring" [ (kdl.flag "off") ])
      (kdl.plain "border" [ (kdl.leaf "width" tokens.geometry.borderWidth) ])
      (kdl.plain "default-column-width" [ (kdl.leaf "proportion" (2. / 3.)) ])
      (kdl.leaf "center-focused-column" "on-overflow")
      (kdl.flag "always-center-single-column")
    ])
    (kdl.plain "cursor" [
      (kdl.leaf "xcursor-theme" cursor.theme)
      (kdl.leaf "xcursor-size" cursor.size)
    ])
    (kdl.plain "binds" (lib.attrValues binds))
    (kdl.leaf "spawn-at-startup" [ noctalia ])
  ]
  ++ windowRules
  ++ [
    # The theme-menu conductor's runtime include, last in the document
    # (ADR-044, #609). optional=true (niri 26.04) keeps the session up before
    # the seed first creates the target.
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

  # …and rendered, for xdg.configFile and for the old-vs-new migration diff.
  # Trailing newline so the file matches what niri-flake writes today.
  text = kdl.serialize.nodes document + "\n";
}
