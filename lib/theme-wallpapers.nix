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
#
# URLs pin their source repos at a commit — immutable raw links,
# operator-selected 2026-07-02 (#499).
let
  gruvboxWallpapers =
    path:
    "https://raw.githubusercontent.com/AngelJumbo/gruvbox-wallpapers/5c145c83ae1f3e30332333bb964d3aeb8e05320a/wallpapers/${path}";
  omarchyGruvbox =
    path:
    "https://raw.githubusercontent.com/basecamp/omarchy/8e03151647ef210ce9e313180e642d3e58dbe9a6/themes/gruvbox/backgrounds/${path}";
  # Mid-tone impressionist painting, 4096x2428 — deliberately in BOTH
  # pools (the one image that carries either polarity); fetchurl dedupes
  # by hash so the store holds one copy.
  backwater = {
    url = omarchyGruvbox "1-the-backwater.jpg";
    sha256 = "1imaxha4vf98n5njlwg9pw7vpzm0aqdzh3w2ib089y8a6ypcdkqk";
  };
in
{
  gruvbox-dark-hard = [
    {
      # Vintage labelled solar chart, 3840x2160.
      url = gruvboxWallpapers "mix/solar-system.jpg";
      sha256 = "0n3pyickrwnfaf0bg4a4k266hhybfm1b9ijbmjxfnlh8i1d6r9gi";
    }
    backwater
  ];
  gruvbox-light-hard = [
    {
      # Cream clouds on sage, 4000x2200.
      url = gruvboxWallpapers "minimalistic/light/clouds.png";
      sha256 = "0p95ky2q0a7p1jcr9la2fzfnn7j8zamm5ld0ia1khdv9wnfclp57";
    }
    backwater
  ];
}
