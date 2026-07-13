# palette-for — one host's theme-family selection semantics, single-sourced
# for its consumers (#541): the stylix-palette twins read the ACTIVE
# polarity's scheme + override; lib/scheme-pair.nix resolves the boot
# default AND the whole catalogue (menu), pre-baked for runtime theme
# switching; home/darwin/wallpapers.nix reads the default couplet's
# scheme names to key its pools.
#
# The catalogue is global and hosts carry boot defaults only — this file
# resolves defaults.<host>.family through families.<name> in
# lib/theme-families.nix. Polarity drives scheme selection — a single
# host-side toggle flips both the base16 palette and the cross-app
# dark/light signal, eliminating the lockstep-by-convention coupling the
# previous interim shape (#123 / #141) carried. An unknown host throws on
# the attr lookup; a reference to an undeclared family or polarity throws
# with a tailored message.
hostName:
let
  catalogue = import ./theme-families.nix;
  default = catalogue.defaults.${hostName};
  # Scheme + slot corrections for one polarity of one family. Overrides
  # are the family's base16 slot corrections for ports that violate slot
  # intents (ADR-028 §History, #331); empty for conformant families.
  selectionFor =
    familyName: polarity:
    let
      family =
        catalogue.families.${familyName}
          or (throw "theme-families: no `${familyName}` family declared (referenced by ${hostName})");
    in
    {
      scheme =
        family.schemes.${polarity}
          or (throw "theme-families: family `${familyName}` has no `${polarity}` scheme declared");
      override = family.overrides.${polarity} or { };
    };
in
{
  # The host's boot-default polarity — selects the active scheme in the
  # stylix-palette twins and passes through to stylix.polarity for the
  # cross-app dark/light signal.
  inherit (default) polarity;

  # The boot-default family name — the menu entry consumers fall back to
  # when no runtime selection exists (#605 stage 2).
  inherit (default) family;

  # polarity -> selection, for the host's boot-default family.
  select = selectionFor default.family;

  # The whole catalogue as selections — familyName -> { dark; light }.
  # The enumerable menu surface runtime theme switching pre-bakes from
  # (#605 stage 2, #609); lib/scheme-pair.nix resolves it against the
  # base16 engine.
  menu = builtins.mapAttrs (name: _: {
    dark = selectionFor name "dark";
    light = selectionFor name "light";
  }) catalogue.families;
}
