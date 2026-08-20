# niri user settings — keybinds (curated essential set) + window defaults.
#
# Bind composition + rationale + the three-modifier-namespace
# philosophy under which bindings are organised lives in
# docs/desktop/keybinds.md. This module is the implementation surface
# for that document; every binding here corresponds to a row in the
# doc's "Active bindings" tables.
#
# Doc-before-code: changes to bindings land first in keybinds.md,
# then here in the same PR.
#
# niri itself is enabled at the system layer
# (modules/nixos/niri.nix). niri-flake's nixosModule auto-imports
# homeModules.config (the typed settings surface) into every HM user
# when home-manager runs as a NixOS module, so this module just sets
# `programs.niri.settings.*` — there's no `programs.niri.enable` here.
# homeModules.config declares no `enable` option; setting one would
# be an undeclared-option eval failure.
#
# See #69 for the niri-only baseline close-out under which this
# curated bind set was established.
{
  config,
  lib,
  options,
  inputs,
  pkgs,
  ...
}:
let
  # Static half of the design tokens only — geometry/layout carry no colour,
  # and importing the `{ config }` half would force a Stylix eval this
  # platform no longer has (#885). See lib/static-tokens.nix.
  tokens = import ../../lib/static-tokens.nix;
  profile = import ../../lib/display-profiles.nix; # display calibration — output scale
  caps = import ../../lib/capabilities.nix { inherit lib; }; # single-source keybind registry (#384)

  # Store-pinned noctalia binary for the hardware media/volume/brightness
  # spawns below — same idiom as spawn-at-startup, so these don't depend on
  # session PATH.
  noctalia = lib.getExe config.programs.noctalia.package;

  # Deliberate lock blanks the displays too. Noctalia's DPMS is driven by the
  # idle ladder (home/nixos/noctalia.nix), and a keypress resets that timer —
  # so locking by hand would otherwise leave the panel lit for a full idle
  # timeout, longer than if you had walked away. No `|| true`: under
  # writeShellApplication's `set -e` a failed lock aborts before the blank,
  # which is the safe direction — a dark but UNLOCKED session wakes straight
  # into a live desktop.
  lockAndBlank = pkgs.writeShellApplication {
    name = "noctalia-lock-and-blank";
    runtimeInputs = [
      config.programs.noctalia.package
      pkgs.coreutils
    ];
    text = ''
      noctalia msg session lock
      # Settle covers the niri round-trip (v5's IPC has no lock-state query to
      # wait on) plus the key's own release event, which would otherwise wake
      # the display straight back up. Re-tune here if a blank-then-unblank
      # flicker shows up on metal.
      sleep 0.5
      noctalia msg dpms-off
    '';
  };

  # Focus-or-spawn helper for the registry's app binds (spawn-browser):
  # focus the first window matching the app-id, else exec the fallback
  # command. On the session PATH via home.packages below so the registry can
  # spawn it by bare name (the #360 wl-clipboard idiom); `niri` itself is
  # resolved the same way — the session that presses the bind always has it.
  focusOrSpawn = pkgs.writeShellApplication {
    name = "niri-focus-or-spawn";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      app_id="$1"
      shift
      # Prefer the focused match: niri's window list is unordered, and with
      # two matching windows a bare first-match could yank focus away from
      # the one already focused. Focused match → focus it again (no-op).
      id="$(niri msg --json windows | jq -r --arg a "$app_id" 'first(.[] | select(.app_id == $a and .is_focused).id) // first(.[] | select(.app_id == $a).id) // empty')"
      if [ -n "$id" ]; then
        exec niri msg action focus-window --id "$id"
      fi
      exec "$@"
    '';
  };

  # Merge the registry-generated binds with the hand-authored remainder,
  # asserting no hand-authored chord silently shadows a generated one via `//`
  # (right-hand wins). The registry's collision lint cannot see this file, so
  # the disjointness guarantee for the merge seam lives here (ADR-039 §8, #455).
  mergeBinds =
    generated: handAuthored:
    let
      shadowed = lib.intersectLists (lib.attrNames generated) (lib.attrNames handAuthored);
    in
    lib.throwIf (shadowed != [ ])
      "niri.nix: hand-authored bind(s) ${lib.concatStringsSep ", " shadowed} shadow registry-generated Hyper chords — declare them in lib/capabilities.nix instead (ADR-039 §8, #455)"
      (generated // handAuthored);
in
{
  # Hand niri's window-border colour to Noctalia's own native theme engine
  # at runtime (ADR-048, reversing ADR-044/#609 for Linux — #819 Epic G,
  # docs/design/noctalia-theming-delegation.md). This is a pre-declared
  # MOUNT-POINT: niri's builtin apply.sh (enabled via home/nixos/
  # noctalia.nix's template whitelist) detects the include by a
  # basename-anchored regex on `noctalia.kdl` and, finding it present,
  # writes ONLY that file — relative to niri's own config directory
  # (~/.config/niri/), never niri's HM-owned config.kdl itself (G3 spike,
  # on-metal-confirmed both directions: include present → zero mutation;
  # include absent + read-only → clean atomic EACCES abort, no
  # materialization). niri-flake's `programs.niri.config` replaces
  # `settings` wholesale and exposes no settings→KDL renderer, so we reach
  # the rendered document via the option's own *default* —
  # `settings.render cfg.settings`, which depends on `settings`, not
  # `config`, so there's no cycle — serialise it, and append a top-level
  # include. `optional=true` (niri 26.04) keeps the session up before
  # Noctalia's first theme resolve creates the target; niri's inotify watch
  # misses the write anyway (niri#2658), so the `colors_changed` repaint
  # hook (home/nixos/noctalia.nix) fires `niri msg action load-config-file`
  # explicitly on every resolve. See docs/desktop/noctalia.md §Sharp edges.
  programs.niri.config =
    inputs.niri-flake.lib.kdl.serialize.nodes options.programs.niri.config.default
    + ''

      include optional=true "noctalia.kdl"
    '';

  home.packages = [ focusOrSpawn ];

  programs.niri.settings = {
    # Capture target, set explicitly so it stays in lockstep with the
    # directory created below — niri creates only the last path component
    # and silently drops the shot when the parent is missing (niri #807).
    # See docs/desktop/keybinds.md §Screenshots.
    screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

    # Output scale from the display calibration, pinned rather than left to
    # niri's auto-detection. DP-1 is the LG UltraFine 4K. See
    # lib/display-profiles.nix.
    outputs."DP-1".scale = profile.scale;

    # Noctalia Shell v5 — spawned at session start (ADR-036; #644) THROUGH
    # the pre-spawn authoritative-key reconcile (home/nixos/noctalia.nix's
    # noctalia.guardedLaunch — design note docs/design/
    # noctalia-config-surface-overlap.md, ruling 2-bis): the wrapper corrects
    # the sidecar before the process exists, then execs the shell. Never
    # spawn the bare binary here, or the guard silently stops running.
    # getExe pins the store path, so session start doesn't depend on PATH
    # ordering.
    spawn-at-startup = [ { command = [ (lib.getExe config.noctalia.guardedLaunch) ]; } ];

    # Input — pointer focus, plus compositor-layer keyboard + mouse ergonomics
    # (#107). Device-layer DPI/buttons/onboard profiles live on the G502
    # (libratbag/ratbagd), not here. See docs/desktop/input.md.
    input = {
      # Pointer focus (#366) — hovering focuses a nearby window, but
      # max-scroll-amount caps how far niri will scroll the workspace to do
      # so (as a fraction of working-area width), so a large off-screen move
      # isn't triggered by crossing the pointer over it. 17% is tuned to the
      # 2/3 default-width geometry and pending live confirmation on the
      # desktop hosts — see docs/desktop/niri.md §Configuration.
      focus-follows-mouse = {
        enable = true;
        max-scroll-amount = "17%";
      };

      keyboard = {
        # Snappier than niri's sluggish 600ms / 25-per-second defaults.
        repeat-delay = 250;
        repeat-rate = 40;
      };

      mouse = {
        # Flat (constant) accel so compositor accel doesn't compound with the
        # G502's onboard DPI; sensitivity is owned by the mouse (accel-speed 0).
        accel-profile = "flat";
        accel-speed = 0.0;
        # Wheel direction matches macOS's natural scrolling (operator runs a Mac).
        natural-scroll = true;
      };

      # Disable niri's hardcoded XF86PowerOff-to-Suspend bind so the key
      # falls through to the configured bind below (session lock, #651);
      # logind stays out of it too via HandlePowerKey=ignore
      # (modules/nixos/power-key.nix).
      power-key-handling.enable = false;
    };

    # Layout primitives — column width, centering, border, and inter-window
    # gap in one block (one `layout` key; geometry/spacing from tokens).
    layout = {
      # Window open-width — new windows open at the 2/3 preset proportion,
      # leaving a third for a companion column. Exactly 2/3 (not ~0.66) so a
      # freshly-opened window sits on niri's switch-preset-column-width
      # cycle (Hyper+R). niri otherwise honours each client's own preferred
      # size, which is why foot (its ~80×24 default) opened narrow. This
      # overrides that for all windows. See docs/desktop/niri.md §Configuration.
      default-column-width.proportion = 2. / 3.;

      # Auto-centering (#366) — center the focused column only when it
      # doesn't fit on screen alongside the previously-focused column
      # (on-overflow), and always center a lone column rather than scroll
      # it to an edge. The manual Hyper+Shift+C center-column bind is separate.
      # See docs/desktop/niri.md §Configuration.
      center-focused-column = "on-overflow";
      always-center-single-column = true;

      # Window decorations — border on, focus-ring off (Stylix used to assert
      # both via its niri target; re-asserted here now that Noctalia's niri
      # template owns the colour via the noctalia.kdl include above). Border
      # width from the geometry token (Carbon spacing-01; crisp on 4K/2× —
      # rationale in static-tokens.nix and docs/desktop/niri.md §Window
      # decorations); the active/inactive colours come from noctalia.kdl.
      border.enable = true;
      border.width = tokens.geometry.borderWidth;
      focus-ring.enable = false;

      # Inter-window gap — explicit token (= Carbon spacing-05) rather than
      # niri's implicit default 16, so the value lives in one place. See
      # static-tokens.nix and docs/desktop/visual-identity.md §Spacing.
      gaps = tokens.layout.gap;
    };

    # No client-side decorations — niri asks clients to drop their own
    # titlebars and draws its focus-ring border instead. Titlebars are
    # wasted space when tiling; foot honours this and drops its top bar.
    prefer-no-csd = true;

    # Rounded corners on every window. The border (and focus ring, if on)
    # follow this radius; clip-to-geometry trims each client's square
    # surface to the rounded rect so corners don't poke past the border.
    # Radius from the geometry token (M3 ladder, shared with fuzzel/fnott);
    # niri's corners are float-typed, so coerce the int token with `+ 0.0`.
    window-rules = [
      {
        geometry-corner-radius =
          let
            r = tokens.geometry.cornerRadius + 0.0;
          in
          {
            top-left = r;
            top-right = r;
            bottom-right = r;
            bottom-left = r;
          };
        clip-to-geometry = true;
      }

      # Keep the capture routes that run without a human at the console (grim
      # over wlr-screencopy; niri's automatic screenshot-screen/-window actions)
      # from becoming a credential channel (#529) — the interactive screenshot
      # UI still shows the window. app-id is PROVISIONAL: pin it from
      # `niri msg windows`, since an unmatched rule is silently inert.
      # See docs/desktop/screen-capture.md §Sharp edges.
      {
        matches = [ { app-id = "^1[Pp]assword$"; } ];
        block-out-from = "screen-capture";
      }

      # Utility-palette apps float above the ribbon instead of tiling into
      # it; escape hatch is toggle-window-floating (Hyper+Shift+Space, from
      # the registry). nautilus app-id pinned from a live window; the
      # 1Password regex shares the PROVISIONAL status of the #529 rule above.
      {
        matches = [
          { app-id = "^org\\.gnome\\.Nautilus$"; }
          { app-id = "^1[Pp]assword$"; }
        ];
        open-floating = true;
      }

      # Electron 1Password restores its last-saved window bounds, which can be
      # a full-tile size if it ever ran tiled; pin its floating open size.
      # Nautilus already persists a sane size itself, so it's left alone.
      {
        matches = [ { app-id = "^1[Pp]assword$"; } ];
        default-column-width.proportion = 0.5;
        default-window-height.proportion = 0.5;
      }
    ];

    # The cross-platform Hyper layer (Ctrl+Alt base) is generated from the
    # single-source capability registry (lib/capabilities.nix, #384 / ADR-039)
    # and merged (via mergeBinds, which guards against a hand-authored chord
    # silently shadowing a generated one — #455) over the hand-authored
    # remainder below. keyd realizes Caps Lock → Hyper (Ctrl+Alt) at the evdev
    # layer (modules/nixos/keyd.nix). The remainder is the Super-namespace +
    # screenshot binds not yet in the registry — the Super layer retires under
    # #323; screenshots stay on Super+Shift. Taxonomy + inventory:
    # docs/desktop/keybinds.md.
    binds = mergeBinds caps.niriBinds {
      # Navigation — focus (arrow + vim-style mirrors). Super-namespace; retired
      # under #323 when the Super layer lands. (The Hyper focus binds — Ctrl+Alt —
      # come from the registry above.)
      "Mod+Left".action.focus-column-left = { };
      "Mod+Down".action.focus-window-down = { };
      "Mod+Up".action.focus-window-up = { };
      "Mod+Right".action.focus-column-right = { };
      "Mod+H".action.focus-column-left = { };
      "Mod+J".action.focus-window-down = { };
      "Mod+K".action.focus-window-up = { };
      "Mod+L".action.focus-column-right = { };

      # Window close. Super+W (the Cmd-position W) is the cross-platform close:
      # niri has no separate WM force-close — only graceful close-window — so this
      # is the close bind, not an interim. See docs/desktop/keybinds.md.
      "Mod+W".action.close-window = { };

      # Workspaces — focus
      "Mod+1".action.focus-workspace = 1;
      "Mod+2".action.focus-workspace = 2;
      "Mod+3".action.focus-workspace = 3;
      "Mod+4".action.focus-workspace = 4;
      "Mod+5".action.focus-workspace = 5;
      "Mod+6".action.focus-workspace = 6;
      "Mod+7".action.focus-workspace = 7;
      "Mod+8".action.focus-workspace = 8;
      "Mod+9".action.focus-workspace = 9;

      # Spawn — terminal + application launcher. The launcher is
      # Noctalia's IPC-driven app launcher (ADR-036; v5 grammar, #644):
      # `noctalia msg panel-toggle launcher`. Passed as an argv list — niri
      # spawns it directly (no shell). fuzzel was decommissioned in #385.
      "Mod+Return".action.spawn = "foot";
      "Mod+Space".action.spawn = [
        "noctalia"
        "msg"
        "panel-toggle"
        "launcher"
      ];

      # Session — quit (niri shows a confirmation dialog by default)
      "Mod+Shift+E".action.quit = { };

      # Discovery
      "Mod+O".action.toggle-overview = { };
      "Mod+Shift+Slash".action.show-hotkey-overlay = { };

      # Screenshots — niri's built-in capture, no external tool. Mirrors
      # macOS after the file/clipboard swap: bare Mod+Shift+N copies to
      # clipboard (write-to-disk=false), Mod+Ctrl+Shift+N saves to disk
      # (+ clipboard). +5 is window capture (niri has no capture-options bar).
      # Region capture is the interactive overlay, which always does both
      # disk+clipboard — so Mod+Shift+4 and Mod+Ctrl+Shift+4 are equivalent.
      # The Print family stays on niri's defaults (disk+clipboard). See
      # docs/desktop/keybinds.md §Screenshots (#100, #323).
      "Mod+Shift+3".action.screenshot-screen = {
        write-to-disk = false;
      };
      "Mod+Shift+4".action.screenshot = { };
      "Mod+Shift+5".action.screenshot-window = {
        write-to-disk = false;
      };
      "Mod+Ctrl+Shift+3".action.screenshot-screen = { };
      "Mod+Ctrl+Shift+4".action.screenshot = { };
      "Mod+Ctrl+Shift+5".action.screenshot-window = { };
      "Print".action.screenshot = { };
      "Ctrl+Print".action.screenshot-screen = { };
      "Alt+Print".action.screenshot-window = { };

      # Hardware media/volume/brightness keys — XF86* keys are their own
      # namespace (not registry chords), routed to Noctalia's IPC so its native
      # OSD owns presentation. allow-when-locked on the volume trio only.
      # Rationale: docs/desktop/audio.md.
      "XF86AudioRaiseVolume" = {
        allow-when-locked = true;
        action.spawn = [
          noctalia
          "msg"
          "volume-up"
        ];
      };
      "XF86AudioLowerVolume" = {
        allow-when-locked = true;
        action.spawn = [
          noctalia
          "msg"
          "volume-down"
        ];
      };
      "XF86AudioMute" = {
        allow-when-locked = true;
        action.spawn = [
          noctalia
          "msg"
          "volume-mute"
        ];
      };
      "XF86AudioMicMute".action.spawn = [
        noctalia
        "msg"
        "mic-mute"
      ];
      "XF86AudioPlay".action.spawn = [
        noctalia
        "msg"
        "media"
        "toggle"
      ];
      "XF86AudioNext".action.spawn = [
        noctalia
        "msg"
        "media"
        "next"
      ];
      "XF86AudioPrev".action.spawn = [
        noctalia
        "msg"
        "media"
        "previous"
      ];
      "XF86MonBrightnessUp".action.spawn = [
        noctalia
        "msg"
        "brightness-up"
      ];
      "XF86MonBrightnessDown".action.spawn = [
        noctalia
        "msg"
        "brightness-down"
      ];

      # Power key — locks the session and blanks the displays, instead of
      # niri's hardcoded suspend (#651). Requires power-key-handling.enable =
      # false above so the key falls through to this configured bind; repeat =
      # false, since a held key would otherwise spam the lock IPC.
      # allow-inhibiting = false so a focused client holding a shortcuts
      # inhibitor cannot swallow the key — locking must not be a capability an
      # application can withhold.
      "XF86PowerOff" = {
        repeat = false;
        allow-inhibiting = false;
        action.spawn = [ (lib.getExe lockAndBlank) ];
      };
    };
  };

  # Create the screenshot target so niri's save actually lands — see the
  # screenshot-path note above. Mirrors home/darwin/screenshots-dir.nix (the
  # same silent-fallback class on macOS's screencapture).
  home.activation.ensureNiriScreenshotsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p $VERBOSE_ARG "$HOME/Pictures/Screenshots"
  '';
}
