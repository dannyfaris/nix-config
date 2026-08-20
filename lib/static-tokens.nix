# static-tokens — the config-free half of the design-token module.
#
# A DTCG-shaped view over the design values that were previously bare
# literals repeated across per-surface modules — the scattering that let the
# base0D focus accent drift out of sync between modules (#333). Surfaces
# reference these tokens instead of restating literals.
#
# The design language (visual-identity.md §"Design tokens") is one
# conceptual module in two files, split by what each half needs to
# evaluate: everything here is a literal or a display-calibration read, so
# it imports as a plain attrset; `lib/theme-tokens.nix` is the other half,
# taking `{ config }` to resolve each colour role's `.hex` from the active
# Stylix palette, and re-exporting this file merged with those hexes.
#
# Why the split, and why it is load-bearing rather than tidy: post-#885
# Stylix exists only on Darwin, so a Linux consumer that imported the
# `{ config }` half would force `config.lib.stylix.colors` on a host where
# that option path does not exist — an eval failure. Importing THIS file
# makes that impossible by construction, rather than relying on Nix
# laziness to keep the colour group untouched (an undocumented landmine:
# it holds until the first future consumer reads a `.hex`).
#
# Naming: "static" is the load-bearing distinction — it answers the one
# question an importer has ("does this force `config`?") in the filename.
# `design-tokens.nix` was rejected: "design tokens" is already the repo's
# prose name for the WHOLE module (theme-tokens.nix's own header,
# visual-identity.md §Theming mechanism), so the file would claim the pair.
# `token-scales.nix` under-describes — the colour roles and borderAlpha
# here are not scales. Per docs/taxonomy.md's most-communicative-term rule.
#
# Imported as `import ../../lib/static-tokens.nix` — a plain attrset, the
# lib/ convention shared with display-profiles.nix and theme-families.nix.
#
# Provenance is one-line inline (Carbon spacing-NN / M3 ladder). The
# conformant tokens.json emit stays latent (ADR-024: Nix canonical, JSON an
# optional artifact) until a design tool wants it. See
# docs/desktop/visual-identity.md §Theming mechanism and #369.
let
  # A colour role aliases a base16 slot: `.slot` is the alias target (for
  # @define-color CSS and slot-keyed helpers) and `.ansi` the role's
  # projection onto the 16-colour terminal bus (for terminal-following
  # surfaces — prompt, #411 statuslines). The bus doesn't carry every slot
  # (base09 has no ANSI position — the base16→ANSI mapping doubles 08/0A–0E
  # into the bright slots), so `.ansi` is the *nearest on-bus* name, chosen
  # here once so approximations can't drift per-surface. The third field,
  # `.hex` (the resolved value, for "${...}ff" RRGGBBAA strings), is added
  # by theme-tokens.nix — it is the one field that needs a live palette.
  # Consumers pick whichever field minimises churn.
  role = slot: ansi: { inherit slot ansi; };

  # Static scales, let-level so the groups below can alias each other (one
  # definition, many consumers — even internally).
  spacing = {
    s01 = 2; # Carbon spacing-01
    s02 = 4; # Carbon spacing-02
    s03 = 8; # Carbon spacing-03
    s04 = 12; # Carbon spacing-04
    s05 = 16; # Carbon spacing-05
    s06 = 24; # Carbon spacing-06
  };
  radius = {
    sm = 8; # M3 sm
    md = 12; # M3 md
    lg = 16; # M3 lg
  };

  # Geometry below comes from the display calibration, so the rendered values
  # move with the output scale if that ever changes (#715 settled it at 1.5×).
  # The static spacing/radius let-bindings above remain as the vocabulary.
  profile = import ./display-profiles.nix;
in
{
  # IBM Carbon spacing scale (visual-identity.md §Spacing). "Stay on the
  # scale." No intra-surface padding consumer yet (#111 closed 2026-06-18
  # without one); s01/s05 are the on-vocab references for
  # geometry.borderWidth / layout.gap.
  inherit spacing;

  # Semantic colour roles (visual-identity.md §Colour) — each ALIASES a
  # base16 slot. Only the alias (`.slot`) and its terminal-bus projection
  # (`.ansi`) live here; the resolved hex is theme-tokens.nix's half.
  color.role = {
    focus = role "base0D" "blue"; # the surface that holds focus
    # bright-yellow is the nearest on-bus colour to base09 (in gruvbox it
    # renders warm gold — orange-adjacent); ANSI-16 has no orange.
    attention = role "base09" "bright-yellow"; # chrome shown without taking focus
    critical = role "base08" "red"; # error / urgent
    muted = role "base03" "bright-black"; # inactive
  };

  # JankyBorders wants 0xAARRGGBB; the stance is active-opaque /
  # inactive-translucent; this is the single source for both consumers
  # (modules/darwin/jankyborders.nix, home/darwin/theme-menu.nix).
  color.borderAlpha = {
    active = "ff";
    inactive = "80";
  };

  # Line weight & radii (visual-identity.md §Line weight & radii).
  geometry = {
    borderWidth = profile.geometry.border; # from the display calibration; on-vocab is Carbon spacing-01
    cornerRadius = profile.geometry.radius; # from the display calibration; on-vocab is radius.md
    inherit radius; # the M3 ladder vocabulary (sm/md/lg)
  };

  # niri layout primitive (visual-identity.md §Spacing — niri collapses
  # gutter+margin into one gaps value, so this is not a responsive grid).
  layout.gap = profile.geometry.gap; # from the display calibration; on-vocab is Carbon spacing-05

  # Motion taxonomy (visual-identity.md §Motion). Structure only — duration tiers
  # and easings are still unset (#111 closed 2026-06-18 without them), to be
  # decided against rendered reality.
  motion = {
    duration = { }; # $type: duration
    easing = { }; # $type: cubicBezier
  };
}
