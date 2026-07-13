# wallpapers — theme-following desktop wallpaper on macOS (#499).
# Consumes the pools declared in lib/theme-wallpapers.nix (scheme-keyed,
# pure data), fetches every image into the store at build time, and
# drives the desktop through two paths:
#
#   1. home.activation — applies the built polarity's pool
#      deterministically (first entry) on rebuild, so a fresh build is
#      complete without the watcher ever firing (survey §2.8 pattern).
#   2. appearance.onChange hook — on a polarity flip, picks randomly
#      from the newly-active scheme's pool (variety is the point of a
#      pool; a pool of one degrades to stable).
#
# desktoppr sets all displays by default (verified against its README);
# absolute store path for the launchd-context PATH reason documented in
# jankyborders-hook.nix. Empty pools no-op everywhere — the module is
# inert until lib/theme-wallpapers.nix declares entries for the host's
# schemes. See docs/design/macos-live-theme-switching.md §Design.
{
  lib,
  pkgs,
  hostContext,
  ...
}:
let
  pools = import ../../lib/theme-wallpapers.nix;
  # Scheme names for the host's boot-default couplet, via the shared
  # selection seam (#541) rather than a raw catalogue read.
  paletteFor = import ../../lib/palette-for.nix hostContext.hostName;

  # Scheme name -> list of store paths (empty when no pool is declared).
  poolFor = scheme: map (w: pkgs.fetchurl { inherit (w) url sha256; }) (pools.${scheme} or [ ]);
  darkPool = poolFor (paletteFor.select "dark").scheme;
  lightPool = poolFor (paletteFor.select "light").scheme;

  desktoppr = "${pkgs.desktoppr}/bin/desktoppr";

  # Random pick at flip time; guarded no-op on an empty pool.
  applyRandom =
    pool:
    if pool == [ ] then
      "true # no pool declared for this scheme"
    else
      ''
        pool=(${lib.concatMapStringsSep " " (p: "\"${p}\"") pool})
        ${desktoppr} "''${pool[RANDOM % ''${#pool[@]}]}"
      '';
in
{
  appearance.onChange.wallpaper = ''
    if [ "$DARKMODE" = "1" ]; then
      ${applyRandom darkPool}
    else
      ${applyRandom lightPool}
    fi
  '';

  # Deterministic default on rebuild: first entry of the *built*
  # polarity's pool — activation must be reproducible, so no randomness
  # here. mkIf omits the DAG entry entirely when no pool is declared.
  home.activation =
    let
      builtPool = if paletteFor.polarity == "dark" then darkPool else lightPool;
    in
    lib.mkIf (builtPool != [ ]) {
      setWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${desktoppr} "${builtins.head builtPool}"
      '';
    };
}
