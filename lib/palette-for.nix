# palette-for — one host's theme-family selection semantics, single-sourced
# for its three consumers (#541): the stylix-palette twins read the ACTIVE
# polarity's scheme + override; lib/scheme-pair.nix reads BOTH polarities,
# pre-baked for runtime theme switching.
#
# Polarity drives scheme selection — a single host-side toggle flips both
# the base16 palette and the cross-app dark/light signal, eliminating the
# lockstep-by-convention coupling the previous interim shape (#123 / #141)
# carried. Selecting a polarity the host hasn't declared fails loudly
# (e.g. a dark-only host flipped to "light"). Declarations live in
# lib/host-palettes.nix; a missing host throws on the attr lookup.
hostName:
let
  palette = (import ./host-palettes.nix).${hostName};
in
{
  # The host's declared polarity — selects the active scheme in the
  # stylix-palette twins and passes through to stylix.polarity for the
  # cross-app dark/light signal.
  inherit (palette) polarity;

  # Scheme + slot corrections for one polarity of the couplet. Overrides
  # are the per-host base16 slot corrections for ports that violate slot
  # intents (ADR-028 §History, #331); empty for conformant hosts.
  select = polarity: {
    scheme =
      palette.schemes.${polarity}
        or (throw "host-palettes: ${hostName} has no `${polarity}` scheme declared");
    override = palette.overrides.${polarity} or { };
  };
}
