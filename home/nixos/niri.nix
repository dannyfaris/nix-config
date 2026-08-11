# niri user config — renders lib/niri-config.nix, gates it on `niri validate`,
# and places it at ~/.config/niri/config.kdl.
#
# There is no typed settings surface to set: niri comes from nixpkgs, whose
# module carries no config interface, so the document is plain data this repo
# owns (docs/design/niri-sourcing.md, rulings 1 + 2). This module's whole job is
# to resolve the values that need the module system — theme tokens, the stylix
# cursor, the noctalia store path, the per-host laptop flag — hand them to
# lib/niri-config.nix, and place the validated result. The settings themselves,
# and why each is what it is, live beside the nodes in lib/niri-config.nix.
#
# niri itself is enabled at the system layer (modules/nixos/niri.nix).
#
# See #69 for the niri-only baseline close-out under which the curated bind set
# in lib/niri-config.nix was established, and docs/desktop/keybinds.md for the
# bind taxonomy it implements.
{
  config,
  lib,
  pkgs,
  hostContext,
  ...
}:
let
  tokens = import ../../lib/theme-tokens.nix { inherit config; };

  # Store-pinned noctalia binary for session start and the hardware
  # media/volume/brightness spawns, so neither depends on session PATH.
  noctalia = lib.getExe config.programs.noctalia.package;

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

  niriConfig = import ../../lib/niri-config.nix {
    inherit lib tokens noctalia;

    # home/nixos/pointer-icons.nix owns stylix.cursor; reading it back out of
    # `config` here (rather than restating the values) is what keeps the
    # compositor cursor and the toolkit cursor from drifting. Note the rename:
    # stylix's `name` is niri's cursor *theme*.
    cursor = {
      theme = config.stylix.cursor.name;
      size = config.stylix.cursor.size;
    };

    # alnair's built-in-panel + touchpad + power-key fragment (#636); the
    # desktop hosts have none of that hardware and default to false.
    inherit (hostContext) laptop;
  };

  # `niri validate` in a derivation the home files depend on is what replaces
  # the typed option surface niri-flake gave (docs/design/niri-sourcing.md,
  # force 5): xdg.configFile's source below IS this derivation, so a config niri
  # rejects fails the build rather than the session. pkgs.niri is the same
  # derivation the system installs — home-manager runs with useGlobalPkgs — so
  # this validates against the binary that will read the file.
  validatedConfig =
    pkgs.runCommand "niri-config.kdl"
      {
        configText = niriConfig.text;
        passAsFile = [ "configText" ];
        nativeBuildInputs = [ pkgs.niri ];
      }
      ''
        # Validate a meaningfully-named copy: niri's diagnostics cite whatever
        # path they were handed, and passAsFile's is an opaque `.attr-<hash>`.
        cp "$configTextPath" config.kdl
        niri validate --config config.kdl
        cp config.kdl "$out"
      '';
in
{
  home.packages = [ focusOrSpawn ];

  # niri's inotify watch misses symlink swaps (niri#2658), so a rebuild does not
  # hot-reload this file; the running session keeps the old config until relogin
  # or an explicit `niri msg action load-config-file`, which the `theme` CLI
  # fires on every switch (home/nixos/theme-menu.nix).
  xdg.configFile."niri/config.kdl".source = validatedConfig;

  # Create the screenshot target so niri's save actually lands — see the
  # screenshot-path node in lib/niri-config.nix. Mirrors
  # home/darwin/screenshots-dir.nix (the same silent-fallback class on macOS's
  # screencapture).
  home.activation.ensureNiriScreenshotsDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p $VERBOSE_ARG "$HOME/Pictures/Screenshots"
  '';
}
