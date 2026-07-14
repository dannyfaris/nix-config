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
#
# Polarity flips (theme dark | theme light) write the macOS appearance
# via sls-set-appearance (SkyLight private API) and do NOT invoke the
# runner directly — the dark-mode-notify watcher fires on the resulting
# AppleInterfaceThemeChangedNotification and drives the fan-out, keeping
# one code path for every polarity entry point (design-note §Design force 3).
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

  # SLS helper: ~10-line C program calling SkyLight's private API to set
  # macOS appearance live system-wide. Applies the flip, maintains the
  # AppleInterfaceStyle preference with correct semantics (key deleted
  # for light), and fires AppleInterfaceThemeChangedNotification — a
  # bare `defaults write` does none of that (see design note §De-risk evidence).
  slsSetAppearance = pkgs.runCommandCC "sls-set-appearance" { } ''
    mkdir -p $out/bin
    $CC -o $out/bin/sls-set-appearance \
      -F /System/Library/PrivateFrameworks \
      -framework SkyLight \
      ${pkgs.writeText "sls-set-appearance.c" ''
        #include <stdbool.h>
        #include <stdio.h>
        #include <string.h>
        extern void SLSSetAppearanceThemeLegacy(bool dark);
        int main(int argc, char *argv[]) {
          if (argc != 2) { fprintf(stderr, "usage: sls-set-appearance dark|light\n"); return 1; }
          if (strcmp(argv[1], "dark") == 0) { SLSSetAppearanceThemeLegacy(true); return 0; }
          if (strcmp(argv[1], "light") == 0) { SLSSetAppearanceThemeLegacy(false); return 0; }
          fprintf(stderr, "sls-set-appearance: argument must be 'dark' or 'light'\n"); return 1;
        }
      ''}
  '';

  # The switcher: validate against the baked menu, atomically repoint
  # the state symlink, repaint open Ghostty windows, then run the
  # fan-out on the new entry. coreutils is pinned because the repoint
  # depends on GNU mv's -T: without it, mv onto an existing symlink
  # DEREFERENCES it and tries to move the temp *into* the read-only
  # store dir — works once on a fresh machine, fails on every switch
  # after (caught in pre-commit review; BSD /bin/mv shares the trap).
  theme = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = [
      pkgs.coreutils
      slsSetAppearance
    ];
    text = ''
      data=${lib.escapeShellArg dataDir}
      state=${lib.escapeShellArg stateDir}

      # Read current polarity from the macOS appearance preference.
      current_polarity() {
        if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -q Dark; then
          echo "dark"
        else
          echo "light"
        fi
      }

      if [ $# -eq 0 ]; then
        current=$(readlink "$state/current" 2>/dev/null || true)
        current=''${current##*/}
        for f in ${lib.concatStringsSep " " families}; do
          if [ "$f" = "$current" ]; then echo "* $f"; else echo "  $f"; fi
        done
        echo ""
        echo "polarity: $(current_polarity)   (theme dark | theme light)"
        echo "usage: theme [<family>] [dark|light]"
        exit 0
      fi

      arg1="$1"
      arg2="''${2:-}"

      # ---------- polarity-only: theme dark | theme light ----------
      # Write the appearance via sls-set-appearance only; do NOT run the
      # runner here — dark-mode-notify fires on the resulting notification
      # and drives the fan-out (one code path, design-note §Design force 3).
      if [ "$arg1" = "dark" ] || [ "$arg1" = "light" ]; then
        current_ptr=$(readlink "$state/current" 2>/dev/null || echo "${lib.escapeShellArg schemePair.family}")
        current_name="''${current_ptr##*/}"
        sls-set-appearance "$arg1"
        echo "theme: switched to ''${current_name}/''${arg1}"
        exit 0
      fi

      # ---------- family (+ optional polarity) ----------
      new_family="$arg1"
      if [ ! -d "$data/$new_family" ]; then
        echo "theme: unknown family '$new_family' (menu: ${lib.concatStringsSep ", " families})" >&2
        exit 1
      fi

      if [ -n "$arg2" ]; then
        if [ "$arg2" != "dark" ] && [ "$arg2" != "light" ]; then
          echo "theme: polarity must be 'dark' or 'light', got '$arg2'" >&2
          exit 1
        fi
        new_polarity="$arg2"
      else
        new_polarity=$(current_polarity)
      fi

      mkdir -p "$state"
      rm -f "$state"/.current.*
      tmp=$(mktemp -u "$state/.current.XXXXXX")
      ln -s "$data/$new_family" "$tmp"
      mv -fT "$tmp" "$state/current"

      # SIGUSR2 = hard config reload; explicit PID list, not pkill (the
      # BSD ancestor exclusion — see the module header).
      ps -axo pid=,comm= \
        | awk '$2 ~ /\/Ghostty\.app\/Contents\/MacOS\/ghostty$/ {print $1}' \
        | while read -r pid; do kill -USR2 "$pid" 2>/dev/null || true; done

      # If polarity is changing, SLS write fires the notification and
      # the watcher drives the fan-out against the already-repointed
      # entry — skip the runner here to avoid double-firing. If polarity
      # is unchanged, the notification won't fire, so run the runner
      # directly to apply the family change (same path as family-only).
      old_polarity=$(current_polarity)
      if [ "$new_polarity" != "$old_polarity" ]; then
        sls-set-appearance "$new_polarity"
        echo "theme: switched to ''${new_family}/''${new_polarity}"
      else
        if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -q Dark; then
          DARKMODE=1
        else
          DARKMODE=0
        fi
        export DARKMODE
        echo "theme: switched to ''${new_family}/''${new_polarity}"
        exec ${config.appearance.runner}
      fi
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
