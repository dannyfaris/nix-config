# theme-families — the fleet-wide catalogue of named theme families, and
# each host's boot default. Looked up through lib/palette-for.nix (#541);
# an unknown host or an undeclared family/polarity fails loudly at eval.
#
# A family is a paired dark/light base16 scheme couplet from the same
# upstream theme, plus optional per-polarity slot corrections. Both
# polarities are mandatory: polarity is a first-class runtime gesture on
# both platforms (the macOS appearance toggle; the Linux conductor), so a
# family missing its light half would break the flip while that theme is
# active. Downstream pre-baking of both halves per entry fails the build
# loudly on any gap.
#
#   - schemes.dark / schemes.light — base16 yaml filenames under
#     ${pkgs.base16-schemes}/share/themes/<name>.yaml.
#   - overrides — optional; per-polarity attrset of base16 slot
#     corrections merged over the scheme via `stylix.override`. These
#     correct a port's slot-intent violations, so they are intrinsic to
#     the family — any host selecting it at runtime inherits them —
#     and corrective hues come only from the theme's own upstream
#     palette. See ADR-028 §History (2026-06-10, #331).
#
# Host-identity theming is retired (operator call, 2026-07-13): the
# catalogue is global, every desktop host offers all of it at runtime,
# and a host's `defaults` entry is a boot default only — what a fresh
# build/reprovision renders before the user's first runtime selection
# (the reproducibility force in both theming design notes). The fuller
# rationale lands with #609's authority ADR. The catalogue grows
# deliberately, whitelist-style, under #605/#609.
#
# Family attr keys are stable public identifiers (menu entries, wallpaper
# association, future UI) — named for keeps.
{
  families = {
    catppuccin = {
      schemes = {
        dark = "catppuccin-mocha";
        light = "catppuccin-latte";
      };
    };
    tokyo-night = {
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
    rose-pine = {
      schemes = {
        dark = "rose-pine";
        light = "rose-pine-dawn";
      };
      # Rose-pine has six accents for seven used slots, so one collision
      # is unavoidable; the port ships 09==0E (gold). Relocate it to
      # 0D==0E (iris) so 0E stays purple-family. See ADR-028 §History
      # (2026-06-10, #331).
      overrides = {
        dark = {
          base0E = "c4a7e7"; # iris — deliberately shares with base0D (path)
        };
        light = {
          base0E = "907aa9"; # dawn iris — same relocation, light polarity
        };
      };
    };
    gruvbox = {
      schemes = {
        dark = "gruvbox-dark-hard";
        light = "gruvbox-light-hard";
      };
    };
    solarized = {
      schemes = {
        dark = "solarized-dark";
        light = "solarized-light";
      };
    };
  };

  # Boot defaults only — NOT identity. `family` names a catalogue entry
  # above; `polarity` ("dark" | "light") selects which half is active at
  # build time and passes through to `stylix.polarity` for the cross-app
  # dark/light signal (Stylix's third value "either" is intentionally
  # not used — leaving polarity unset is precisely the bug #123 fixed).
  #
  # Future host jupiter (celestial name per ADR-038) gets its entry here
  # at bring-up.
  defaults = {
    nixos-vm = {
      family = "catppuccin";
      polarity = "dark";
    };
    mercury = {
      family = "tokyo-night";
      polarity = "dark";
    };
    metis = {
      family = "rose-pine";
      polarity = "dark";
    };
    neptune = {
      family = "gruvbox";
      polarity = "dark";
    };
    saturn = {
      family = "solarized";
      polarity = "dark";
    };
  };
}
