# Design tokens — the desktop's design language, defined once.
#
# A DTCG-shaped view over the design values that were previously bare literals
# repeated across per-surface modules (the scattering that let the base0D focus
# accent drift out of sync between modules, #333). Colour roles and type sizes
# *alias* what Stylix centralizes (Stylix stays the source); geometry, spacing,
# and layout are canonical here; motion carries structure only (values open,
# #111). Surfaces reference these tokens instead of restating literals.
#
# Imported per-consumer as `import ../../lib/theme-tokens.nix { inherit config; }`
# — the lib/ import convention (host-palettes/operator are plain attrsets,
# stances takes { lib }; this one takes config), not threaded via _module.args.
# Takes `config` for the dynamic colour/type groups that read Stylix; the static
# groups never touch it, so static-only consumers (niri) force no Stylix eval
# (laziness).
#
# Provenance is one-line inline (Carbon spacing-NN / M3 ladder). The conformant
# tokens.json emit stays latent (ADR-024: Nix canonical, JSON an optional
# artifact) until a design tool wants it. See docs/desktop/visual-identity.md
# §Theming mechanism and #369.
{ config }:
let
  c = config.lib.stylix.colors;
  hexOf = slot: c."${slot}-hex"; # base16 slot -> "RRGGBB" (the one accessor site)

  # A colour role aliases a base16 slot: `.slot` is the alias target (for
  # @define-color CSS and slot-keyed helpers), `.hex` the resolved value (for
  # "${...}ff" RRGGBBAA strings). Consumers pick whichever field minimises churn.
  role = slot: {
    inherit slot;
    hex = hexOf slot;
  };

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
in
{
  # IBM Carbon spacing scale (visual-identity.md §Spacing). Static. "Stay on the
  # scale." Intra-surface padding consumers land under #111; s01/s05 are already
  # aliased below by geometry.borderWidth / layout.gap.
  inherit spacing;

  # Semantic colour roles (visual-identity.md §Colour) — each ALIASES a base16
  # slot. Dynamic: resolves per-host/per-polarity through config.lib.stylix.colors.
  color.role = {
    focus = role "base0D"; # the surface that holds focus
    attention = role "base09"; # chrome shown without taking focus (notifications)
    critical = role "base08"; # error / urgent
    muted = role "base03"; # inactive
  };

  # Font sizes ALIAS stylix.fonts.sizes.* (modules/nixos/desktop-fonts.nix).
  # Dynamic. PR1 aliases today's sizes (all 11); the M3 role ramp grows here in
  # the typography follow-up (#369 PR2), where the font-line consumers rewire to
  # read these. Defined now, not yet consumed.
  type.size = {
    chrome = config.stylix.fonts.sizes.desktop; # waybar
    popup = config.stylix.fonts.sizes.popups; # fnott + fuzzel
    terminal = config.stylix.fonts.sizes.terminal; # foot / TUI
  };

  # Line weight & radii (visual-identity.md §Line weight & radii). Static.
  geometry = {
    borderWidth = spacing.s01; # = Carbon spacing-01; even width → crisp on 4K/1.5
    cornerRadius = radius.md; # the chrome's corner radius — selects one ladder rung
    inherit radius; # the M3 ladder vocabulary (sm/md/lg)
  };

  # niri layout primitive (visual-identity.md §Spacing — niri collapses
  # gutter+margin into one gaps value, so this is not a responsive grid). Static.
  layout.gap = spacing.s05; # niri inter-window gap (= Carbon spacing-05)

  # Motion taxonomy (visual-identity.md §Motion). Structure only — duration tiers
  # and easings land under #111, decided against rendered reality.
  motion = {
    duration = { }; # $type: duration
    easing = { }; # $type: cubicBezier
  };
}
