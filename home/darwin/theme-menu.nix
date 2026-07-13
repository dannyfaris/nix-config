# theme-menu — the runtime named-theme menu on macOS (#605; stage 2 of
# docs/design/macos-live-theme-switching.md). Renders one entry dir per
# declared family (lib/theme-families.nix, resolved via
# lib/scheme-pair.nix's `menu`) into the HM generation, owns the
# active-theme pointer convention, and ships the `theme` switcher CLI.
#
# Entry-dir contract (consumed by the appearance.onChange hooks and the
# Ghostty include): ghostty.conf = the family's dual-theme selector
# line; borders-{dark,light} = the full `borders` argv recolouring the
# running instance; wallpapers-{dark,light}/ = the scheme's declared
# pool as indexed symlinks (empty when a scheme declares no pool).
#
# The pointer is $XDG_STATE_HOME/theme-menu/current -> one entry's
# *stable* $XDG_DATA_HOME/theme-menu/<family> path. HM repoints the data
# path at every rebuild (entries stay GC-rooted via the generation), so
# a selection survives both reboot and rebuild; an absent or dangling
# pointer means every consumer falls back to the boot default, so a
# fresh build lands on the declared look with no pointer-seeding step
# (design-note force 4).
#
# The switcher repaints open Ghostty windows with SIGUSR2 — a hard
# config reload from disk, re-resolving the config-file include;
# source-verified at the installed 1.3.1 (design note §De-risk
# evidence) — then fires the same runner the watcher uses with DARKMODE
# computed from the appearance preference: one hook code path for every
# gesture. Signals go to an explicit PID list because BSD pkill/pgrep
# exclude ancestor processes — a pkill would skip the very window the
# operator typed the command in (probed on neptune, 2026-07-13).
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
  paletteFor = import ../../lib/palette-for.nix hostContext.hostName;
  pools = import ../../lib/theme-wallpapers.nix;
  tokens = import ../../lib/theme-tokens.nix { inherit config; };

  dataDir = "${config.xdg.dataHome}/theme-menu";
  stateDir = "${config.xdg.stateHome}/theme-menu";

  # borders argv per resolved scheme: the same roles and 0xAARRGGBB
  # format as modules/darwin/jankyborders.nix (only the static `.slot`
  # field is read, so there is no active-polarity coupling).
  bordersArgs =
    colors:
    "active_color=0xff${colors.${tokens.color.role.focus.slot}} "
    + "inactive_color=0xff${colors.${tokens.color.role.muted.slot}}";

  # A scheme's wallpaper pool as an indexed link farm — index names give
  # the deterministic order the activation default relies on; an
  # undeclared pool renders an empty dir (opt-in per scheme, unchanged).
  poolFarm =
    scheme:
    pkgs.linkFarm "wallpapers-${scheme}" (
      lib.imap0 (i: w: {
        name = toString i;
        path = pkgs.fetchurl { inherit (w) url sha256; };
      }) (pools.${scheme} or [ ])
    );

  entryFor =
    name: couplet:
    pkgs.runCommand "theme-menu-${name}" { } ''
      mkdir $out
      cp ${pkgs.writeText "ghostty-conf-${name}" ''
        theme = light:${name}-light,dark:${name}-dark
      ''} $out/ghostty.conf
      cp ${pkgs.writeText "borders-dark-${name}" (bordersArgs couplet.dark)} $out/borders-dark
      cp ${pkgs.writeText "borders-light-${name}" (bordersArgs couplet.light)} $out/borders-light
      ln -s ${poolFarm paletteFor.menu.${name}.dark.scheme} $out/wallpapers-dark
      ln -s ${poolFarm paletteFor.menu.${name}.light.scheme} $out/wallpapers-light
    '';

  families = lib.attrNames schemePair.menu;

  # The switcher: validate against the baked menu, atomically repoint
  # the state symlink, repaint open Ghostty windows, then run the
  # fan-out on the new entry. coreutils is pinned because the repoint
  # depends on GNU mv's -T: without it, mv onto an existing symlink
  # DEREFERENCES it and tries to move the temp *into* the read-only
  # store dir — works once on a fresh machine, fails on every switch
  # after (caught in pre-commit review; BSD /bin/mv shares the trap).
  theme = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      data=${lib.escapeShellArg dataDir}
      state=${lib.escapeShellArg stateDir}

      if [ $# -eq 0 ]; then
        current=$(readlink "$state/current" 2>/dev/null || true)
        current=''${current##*/}
        for f in ${toString families}; do
          if [ "$f" = "$current" ]; then echo "* $f"; else echo "  $f"; fi
        done
        exit 0
      fi

      family=$1
      if [ ! -d "$data/$family" ]; then
        echo "theme: unknown family '$family' (menu: ${lib.concatStringsSep ", " families})" >&2
        exit 1
      fi

      mkdir -p "$state"
      rm -f "$state"/.current.*
      tmp=$(mktemp -u "$state/.current.XXXXXX")
      ln -s "$data/$family" "$tmp"
      mv -fT "$tmp" "$state/current"

      # SIGUSR2 = hard config reload; explicit PID list, not pkill (the
      # BSD ancestor exclusion — see the module header).
      ps -axo pid=,comm= \
        | awk '$2 ~ /\/Ghostty\.app\/Contents\/MacOS\/ghostty$/ {print $1}' \
        | while read -r pid; do kill -USR2 "$pid" 2>/dev/null || true; done

      # Fire the appearance fan-out (borders, wallpaper) on the new
      # entry. DARKMODE mirrors the watcher's contract; the key is
      # absent in light mode (stage-1 de-risked semantics).
      if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -q Dark; then
        DARKMODE=1
      else
        DARKMODE=0
      fi
      export DARKMODE
      exec ${config.appearance.runner}
    '';
  };
in
{
  # One stable data path per family; HM owns the symlink, the store owns
  # the content.
  xdg.dataFile = lib.mapAttrs' (
    name: couplet: lib.nameValuePair "theme-menu/${name}" { source = entryFor name couplet; }
  ) schemePair.menu;

  home.packages = [ theme ];
}
