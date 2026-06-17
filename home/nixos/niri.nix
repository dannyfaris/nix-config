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
  ...
}:
let
  tokens = import ../../lib/theme-tokens.nix { inherit config; };
  profile = import ../../lib/display-profiles.nix; # active display profile — output scale
in
{
  # Hand niri's window-border colour to Noctalia at runtime (ADR-036, #385).
  # niri-flake's `programs.niri.config` replaces `settings` wholesale and
  # exposes no settings→KDL renderer, so we reach the rendered document via the
  # option's own *default* — `settings.render cfg.settings`, which depends on
  # `settings`, not `config`, so there's no cycle — serialise it, and append a
  # top-level include. `optional=true` (niri 26.04) keeps the session up before
  # Noctalia first writes noctalia.kdl; niri watches the file and live-reloads,
  # so the border follows Noctalia's scheme/polarity. Noctalia's own niri
  # post-hook can't do this injection itself — it can't write the read-only
  # config.kdl symlink. See docs/desktop/noctalia.md §Sharp edges.
  programs.niri.config =
    inputs.niri-flake.lib.kdl.serialize.nodes options.programs.niri.config.default
    + ''

      include optional=true "~/.config/niri/noctalia.kdl"
    '';

  programs.niri.settings = {
    # Capture target, set explicitly so it stays in lockstep with the
    # directory created below — niri creates only the last path component
    # and silently drops the shot when the parent is missing (niri #807).
    # See docs/desktop/keybinds.md §Screenshots.
    screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

    # Output scale from the active display profile (metis runs 2×, overriding
    # niri's auto-detected 1.5×). DP-1 is the LG UltraFine 4K. See
    # lib/display-profiles.nix.
    outputs."DP-1".scale = profile.scale;

    # Noctalia Shell — spawned at session start (ADR-036, #385). The binary
    # is `noctalia-shell` (a wrapper over Quickshell's qs). Non-destructive
    # bring-up: runs alongside the existing bar/launcher until the cutover.
    spawn-at-startup = [ { command = [ "noctalia-shell" ]; } ];

    # Layout primitives — column width, border, and inter-window gap in one
    # block (one `layout` key; the geometry/spacing values come from tokens).
    layout = {
      # Window open-width — new windows open at two-thirds of the workspace
      # (a niri preset proportion), leaving a third for a companion column.
      # niri otherwise honours each client's own preferred size, which is
      # why foot (its ~80×24 default) opened narrow. This overrides that
      # for all windows. See docs/desktop/niri.md §Configuration.
      default-column-width.proportion = 0.66;

      # Window decorations — border on, focus-ring off (Stylix used to assert
      # both via its niri target; re-asserted here now that Noctalia owns the
      # colour via the runtime include above). Border width from the geometry
      # token (Carbon spacing-01; crisp on 4K/2× — rationale in theme-tokens.nix
      # and docs/desktop/niri.md §Window decorations); the active/inactive
      # colours come from Noctalia's noctalia.kdl.
      border.enable = true;
      border.width = tokens.geometry.borderWidth;
      focus-ring.enable = false;

      # Inter-window gap — explicit token (= Carbon spacing-05) rather than
      # niri's implicit default 16, so the value lives in one place. See
      # theme-tokens.nix and docs/desktop/visual-identity.md §Spacing.
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
    ];

    binds = {
      # Navigation — focus (arrow + vim-style mirrors)
      "Mod+Left".action.focus-column-left = { };
      "Mod+Down".action.focus-window-down = { };
      "Mod+Up".action.focus-window-up = { };
      "Mod+Right".action.focus-column-right = { };
      "Mod+H".action.focus-column-left = { };
      "Mod+J".action.focus-window-down = { };
      "Mod+K".action.focus-window-up = { };
      "Mod+L".action.focus-column-right = { };

      # Navigation — move (arrow + vim-style mirrors)
      "Mod+Ctrl+Left".action.move-column-left = { };
      "Mod+Ctrl+Down".action.move-window-down = { };
      "Mod+Ctrl+Up".action.move-window-up = { };
      "Mod+Ctrl+Right".action.move-column-right = { };
      "Mod+Ctrl+H".action.move-column-left = { };
      "Mod+Ctrl+J".action.move-window-down = { };
      "Mod+Ctrl+K".action.move-window-up = { };
      "Mod+Ctrl+L".action.move-column-right = { };

      # Window management — interim binding; philosophical target is
      # Super+Hyper+W. See docs/desktop/keybinds.md §Implementation status.
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

      # Workspaces — move window to. On Mod+Ctrl (the move modifier, paired
      # with the Mod+Ctrl move-column binds above) rather than Mod+Shift,
      # which is freed for the macOS-style clipboard screenshot chords
      # below. See docs/desktop/keybinds.md §Workspaces / §Screenshots (#323).
      "Mod+Ctrl+1".action.move-window-to-workspace = 1;
      "Mod+Ctrl+2".action.move-window-to-workspace = 2;
      "Mod+Ctrl+3".action.move-window-to-workspace = 3;
      "Mod+Ctrl+4".action.move-window-to-workspace = 4;
      "Mod+Ctrl+5".action.move-window-to-workspace = 5;
      "Mod+Ctrl+6".action.move-window-to-workspace = 6;
      "Mod+Ctrl+7".action.move-window-to-workspace = 7;
      "Mod+Ctrl+8".action.move-window-to-workspace = 8;
      "Mod+Ctrl+9".action.move-window-to-workspace = 9;

      # Spawn — terminal + application launcher. The launcher is
      # Noctalia's IPC-driven app launcher (ADR-036, #385): `noctalia-shell
      # ipc call launcher toggle`. Passed as an argv list — niri spawns it
      # directly (no shell). fuzzel was decommissioned in #385.
      "Mod+Return".action.spawn = "foot";
      "Mod+Space".action.spawn = [
        "noctalia-shell"
        "ipc"
        "call"
        "launcher"
        "toggle"
      ];

      # Hyper — the cross-platform layer (nav/spawn/system; see keybinds.md).
      # keyd realizes Caps Lock → Hyper
      # (Super+Ctrl+Alt+Shift) at the evdev layer; see modules/nixos/keyd.nix
      # and docs/desktop/keyd.md. Binds are written with all four modifiers;
      # niri's exact-modifier matching keeps them clear of the Mod / Mod+Ctrl
      # / Mod+Shift binds above. Each mirrors the analogous macOS action so
      # muscle memory transfers (docs/desktop/keybinds.md §Cross-platform
      # Hyper mapping). The Super-namespace originals above are retained
      # alongside during the migration, then retired once it settles.
      "Mod+Ctrl+Alt+Shift+Left".action.focus-column-left = { };
      "Mod+Ctrl+Alt+Shift+Right".action.focus-column-right = { };
      "Mod+Ctrl+Alt+Shift+Up".action.toggle-overview = { };
      "Mod+Ctrl+Alt+Shift+1".action.focus-workspace = 1;
      "Mod+Ctrl+Alt+Shift+2".action.focus-workspace = 2;
      "Mod+Ctrl+Alt+Shift+3".action.focus-workspace = 3;
      "Mod+Ctrl+Alt+Shift+4".action.focus-workspace = 4;
      "Mod+Ctrl+Alt+Shift+5".action.focus-workspace = 5;
      "Mod+Ctrl+Alt+Shift+6".action.focus-workspace = 6;
      "Mod+Ctrl+Alt+Shift+7".action.focus-workspace = 7;
      "Mod+Ctrl+Alt+Shift+8".action.focus-workspace = 8;
      "Mod+Ctrl+Alt+Shift+9".action.focus-workspace = 9;
      "Mod+Ctrl+Alt+Shift+Space".action.spawn = [
        "noctalia-shell"
        "ipc"
        "call"
        "launcher"
        "toggle"
      ];
      # Hyper+Return → foot, mirroring the mac's Hyper+Return → Ghostty.
      "Mod+Ctrl+Alt+Shift+Return".action.spawn = "foot";
      # Hyper+B → the system default browser. A neutral https URL resolves
      # through xdg-open to whatever is the registered default handler, so the
      # bind follows the default rather than pinning a browser. See
      # docs/desktop/keybinds.md §Hyper for the Firefox/#127 provenance.
      "Mod+Ctrl+Alt+Shift+B".action.spawn = [
        "xdg-open"
        "https://"
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
    };
  };

  # Create the screenshot target so niri's save actually lands — see the
  # screenshot-path note above. Mirrors home/darwin/screenshots-dir.nix (the
  # same silent-fallback class on macOS's screencapture).
  home.activation.ensureNiriScreenshotsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p $VERBOSE_ARG "$HOME/Pictures/Screenshots"
  '';
}
