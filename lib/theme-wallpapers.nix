# theme-wallpapers — wallpaper pools keyed by base16 scheme name (#499).
#
# Pure data, the host-palettes.nix pattern: no pkgs here; the consuming
# module (home/darwin/wallpapers.nix) maps entries through fetchurl so
# every image is a store path — reproducible, no runtime fetch, and the
# repo stays binary-free. Keyed by *scheme* name (the atom
# host-palettes.nix trades in), not theme x polarity: polarity is just
# which scheme of the couplet is active, and a future named-theme menu
# entry is a couplet of scheme names — this flat keying survives both
# stages unchanged. See docs/design/macos-live-theme-switching.md
# §Design.
#
# A scheme with no pool simply doesn't drive the desktop (opt-in per
# scheme, whitelist-shaped). An image suiting both polarities is listed
# under both schemes — fetchurl dedupes by hash, the store holds one
# copy. A dead URL fails the *build* loudly, never the runtime.
#
# Entry shape:
#   <scheme-name> = [
#     { url = "https://…"; sha256 = "…"; }
#   ];
{ }
