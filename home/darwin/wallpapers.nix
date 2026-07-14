# wallpapers — theme-following desktop wallpaper on macOS (#499, #605).
# The pools are declared in lib/theme-wallpapers.nix (scheme-keyed, pure
# data) and rendered per menu entry by home/darwin/theme-menu.nix
# (`wallpapers-{dark,light}/` as indexed store symlinks); this module
# drives the desktop through two paths:
#
#   1. home.activation — on a fresh provision (no runtime selection),
#      applies the boot default's pool deterministically (first entry)
#      so a fresh build is complete without the watcher ever firing
#      (survey §2.8 pattern). With a live selection present, a rebuild
#      leaves the desktop alone — the pointer owns the look.
#   2. appearance.onChange hook — on a polarity flip or theme switch,
#      picks randomly from the active entry's pool for the new half
#      (variety is the point of a pool; a pool of one degrades to
#      stable). Resolves the $XDG_STATE_HOME pointer, else the
#      boot-default family — one hook path for both gestures.
#
# desktoppr sets all displays by default (verified against its README);
# absolute store path for the launchd-context PATH reason documented in
# jankyborders-hook.nix. Empty pools no-op everywhere — the module is
# inert until lib/theme-wallpapers.nix declares entries for the active
# schemes. See docs/design/macos-live-theme-switching.md §Design.
{
  config,
  lib,
  pkgs,
  inputs,
  hostContext,
  ...
}:
let
  pools = import ../../lib/theme-wallpapers.nix;
  schemePair = import ../../lib/scheme-pair.nix {
    inherit
      inputs
      pkgs
      lib
      hostContext
      ;
  };
  paletteFor = import ../../lib/palette-for.nix hostContext.hostName;

  desktoppr = "${pkgs.desktoppr}/bin/desktoppr";

  # The boot default's built-polarity pool, for the activation step.
  # Same fetchurl inputs as theme-menu.nix's entry render — the store
  # dedupes, so this is a second reference, not a second fetch.
  builtPool = map (w: pkgs.fetchurl { inherit (w) url sha256; }) (
    pools.${(paletteFor.select paletteFor.polarity).scheme} or [ ]
  );
in
{
  appearance.onChange.wallpaper = ''
    entry=${config.xdg.stateHome}/theme-menu/current
    [ -e "$entry" ] || entry=${config.xdg.dataHome}/theme-menu/${schemePair.family}
    if [ "$DARKMODE" = "1" ]; then dir=$entry/wallpapers-dark; else dir=$entry/wallpapers-light; fi
    shopt -s nullglob
    pool=("$dir"/*)
    shopt -u nullglob
    # Pool-identity stamp: random variety on genuine pool change (polarity flip,
    # family switch, pool edit); no-op on self-heal re-applies. #620
    # Empty pool skips both desktoppr and the stamp — no apply means no
    # success to record; next run retries in case a rebuild fills the pool.
    if [ ''${#pool[@]} -gt 0 ]; then
      stamp_dir=${config.xdg.stateHome}/wallpaper
      stamp_file=$stamp_dir/last-pool
      pool_id=$(realpath "$dir")
      if [ -f "$stamp_file" ] && [ "$(cat "$stamp_file")" = "$pool_id" ]; then
        exit 0
      fi
      if ${desktoppr} "''${pool[RANDOM % ''${#pool[@]}]}"; then
        mkdir -p "$stamp_dir"
        printf '%s' "$pool_id" > "$stamp_file"
      fi
    fi
  '';

  # Deterministic default on a fresh provision only: first entry of the
  # boot default's built-polarity pool. Gated on the pointer at runtime
  # — activation must not stomp a live selection's wallpaper — and the
  # DAG entry is omitted entirely when no pool is declared.
  home.activation = lib.mkIf (builtPool != [ ]) {
    setWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e ${config.xdg.stateHome}/theme-menu/current ]; then
        run ${desktoppr} "${builtins.head builtPool}"
      fi
    '';
  };
}
