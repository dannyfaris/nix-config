# jankyborders-hook — repaints the JankyBorders focus border on a macOS
# appearance flip or theme switch (#499, #605). The HM sibling of the
# system service in modules/darwin/jankyborders.nix: that module keeps
# the launchd agent and paints the boot default's colours at its own
# start; this hook re-applies the *active* selection's pair at runtime.
#
# Stage 2 shape: the colour pairs live pre-baked in every theme-menu
# entry dir (home/darwin/theme-menu.nix renders `borders-{dark,light}`
# as complete `borders` argv strings, same roles + 0xAARRGGBB format as
# the service module); this hook resolves the active entry — the
# $XDG_STATE_HOME pointer, else the boot-default family — and applies
# the DARKMODE half. One hook path for both gestures: the watcher fires
# it on appearance flips, the `theme` switcher after a repoint.
{
  config,
  pkgs,
  inputs,
  lib,
  hostContext,
  ...
}:
let
  schemePair = import ../../lib/scheme-pair.nix {
    inherit
      inputs
      pkgs
      lib
      hostContext
      ;
  };
in
{
  # Guarded on a running instance: `borders <args>` with no instance up
  # *becomes* the daemon (pinned src main.c) — a rogue unconfigured
  # instance that also wedges the watcher's startup run forever. Skipping
  # is safe: the system agent paints built-polarity colours at its own
  # start, and the next flip/wake run corrects. Absolute store path
  # because launchd agents get a minimal PATH (the colima-module lesson).
  # $(cat …) is deliberately unquoted — the entry file is an argv string.
  appearance.onChange.jankyborders = ''
    entry=${config.xdg.stateHome}/theme-menu/current
    [ -e "$entry" ] || entry=${config.xdg.dataHome}/theme-menu/${schemePair.family}
    if [ "$DARKMODE" = "1" ]; then half=dark; else half=light; fi
    if pgrep -xq borders; then
      ${pkgs.jankyborders}/bin/borders $(cat "$entry/borders-$half")
    fi
  '';
}
