# jankyborders-hook — repaints the JankyBorders focus border on a
# macOS appearance flip (#499). The HM sibling of the system service in
# modules/darwin/jankyborders.nix: that module keeps the launchd agent
# and the built polarity's colours; this one contributes the runtime
# hook, because the flip is user-session behaviour and the dual colour
# pair needs the both-polarities derivation the HM layer already builds
# for the Ghostty themes (lib/scheme-pair.nix).
#
# Colour roles mirror the service module exactly: active = focus
# (base0D), inactive = muted (base03), 0xAARRGGBB with opaque alpha —
# same vocabulary, both polarities pre-baked at build time. The
# `borders` CLI recolours the running instance live, no agent restart
# (de-risked on neptune; see the design note §De-risk evidence).
{
  config,
  lib,
  pkgs,
  inputs,
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
  # Role slots from the design tokens (never restated — the #333 drift
  # class): only `.slot` is read, which is static; the config-reading
  # `.hex` is never forced, so the tokens' active-polarity limitation
  # doesn't bite here.
  tokens = import ../../lib/theme-tokens.nix { inherit config; };
  # RRGGBB -> 0xAARRGGBB with opaque alpha, per modules/darwin/jankyborders.nix.
  pair =
    colors:
    "active_color=0xff${colors.${tokens.color.role.focus.slot}} "
    + "inactive_color=0xff${colors.${tokens.color.role.muted.slot}}";
in
{
  # Guarded on a running instance: `borders <args>` with no instance up
  # *becomes* the daemon (pinned src main.c) — a rogue unconfigured
  # instance that also wedges the watcher's startup run forever. Skipping
  # is safe: the system agent paints built-polarity colours at its own
  # start, and the next flip/wake run corrects. Absolute store path
  # because launchd agents get a minimal PATH (the colima-module lesson).
  appearance.onChange.jankyborders = ''
    if pgrep -xq borders; then
      if [ "$DARKMODE" = "1" ]; then
        ${pkgs.jankyborders}/bin/borders ${pair schemePair.dark}
      else
        ${pkgs.jankyborders}/bin/borders ${pair schemePair.light}
      fi
    fi
  '';
}
