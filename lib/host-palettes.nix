# Single source of truth for "what theme is each host". Looked up by
# modules/nixos/stylix-palette.nix via hostContext.hostName.
# Missing-host lookups fail loudly at eval (no default fallback —
# Nix's `attr.X` on a missing X throws a clear error). Missing-field
# lookups (e.g., a host entry without `polarity`) fail the same way.
#
# Each entry declares a *theme family* — paired dark / light schemes
# from the same base16 family — and a polarity that selects which
# variant is active:
#
#   - schemes.dark — base16 yaml filename for the dark variant.
#   - schemes.light — base16 yaml filename for the light variant.
#     Optional: a dark-only host can omit `schemes.light` and eval
#     fails loudly if its polarity is ever flipped to `"light"`.
#   - polarity — `"dark"` or `"light"`; selects between the schemes
#     above and is also passed through to `stylix.polarity` so Stylix
#     can write the cross-app signals
#     (gtk-application-prefer-dark-theme, the xdg-portal color-scheme,
#     adw-gtk3 dark-variant selection, etc.). Stylix's third polarity
#     value `"either"` is intentionally NOT used here — leaving polarity
#     unset is precisely the bug #123 fixed.
#
# Scheme names match files under
# ${pkgs.base16-schemes}/share/themes/<name>.yaml. Flipping polarity is
# a single edit; the scheme follows automatically. Declaring schemes in
# pairs makes the dark↔light coupling explicit at the entry, so a
# scheme and its polarity can never drift apart silently — the
# fragility the previous interim shape (#123 / #141) carried.
#
# Visibly-distinct hues per host so SSH'ing between them surfaces a
# palette shift in prompt / Zellij frame / helix / macchina banner —
# the fourth signal layer in the SSH-context awareness stack
# (issues #4, #6, #7, #17 land the other three).
#
# Future hosts (mothership, mba, mac-mini) get entries here at bring-up.
{
  nixos-vm = {
    polarity = "dark";
    schemes = {
      dark = "catppuccin-mocha";
      light = "catppuccin-latte";
    };
  };
  mercury = {
    polarity = "dark";
    schemes = {
      dark = "tokyo-night-dark";
      light = "tokyo-night-light";
    };
  };
  metis = {
    polarity = "dark";
    schemes = {
      dark = "rose-pine";
      light = "rose-pine-dawn";
    };
  };
}
