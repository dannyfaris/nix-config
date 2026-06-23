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
#   - overrides — optional; per-polarity attrset of base16 slot
#     corrections merged over the selected scheme via `stylix.override`.
#     For ports that violate base16 slot intents; corrective hues come
#     only from the theme's own upstream palette. See ADR-028 §History
#     (2026-06-10, #331).
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
# Future hosts (jupiter, saturn — celestial names per ADR-038) get
# entries here at bring-up.
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
    # Port corrections — these ports park the theme's red in base0F and
    # render accents off-intent (dark 08/09/0A, with 09 byte-identical
    # to the base05 fg; light 08/0A). See ADR-028 §History (2026-06-10, #331).
    overrides = {
      dark = {
        base08 = "f7768e"; # red — from this port's own base0F
        base09 = "ff9e64"; # upstream orange (as in tokyo-night-terminal-dark)
        base0A = "e0af68"; # upstream yellow (ditto)
      };
      light = {
        base08 = "8c4351"; # red — from this port's own base0F
        base0A = "8f5e15"; # upstream yellow (as in tokyo-night-terminal-light)
      };
    };
  };
  metis = {
    polarity = "dark";
    schemes = {
      dark = "rose-pine";
      light = "rose-pine-dawn";
    };
    # Rose-pine has six accents for seven used slots, so one collision
    # is unavoidable; the port ships 09==0E (gold). Relocate it to
    # 0D==0E (iris) so the SSH marker is purple-family like every other
    # host. See ADR-028 §History (2026-06-10, #331).
    overrides = {
      dark = {
        base0E = "c4a7e7"; # iris — deliberately shares with base0D (path)
      };
      light = {
        base0E = "907aa9"; # dawn iris — same relocation, light polarity
      };
    };
  };
  # Visibly distinct from the existing three (catppuccin / tokyo-night /
  # rose-pine) — gruvbox's warm-orange accent is the obvious shift when
  # an SSH session moves between neptune (this Mac) and any Linux host.
  neptune = {
    polarity = "dark";
    schemes = {
      dark = "gruvbox-dark-hard";
      light = "gruvbox-light-hard";
    };
  };
}
