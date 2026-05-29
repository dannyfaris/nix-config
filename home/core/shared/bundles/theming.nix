# Stylix HM-side target enables for the TUI stack. Stylix's palette
# propagation comes from modules/core/nixos/foundation.nix (the
# NixOS-side module sets stylix.enable = true and auto-wires HM via
# homeManagerIntegration). This bundle is the explicit whitelist of
# which HM-managed tools cede their theming to Stylix.
#
# Foundation sets autoEnable = false at the NixOS layer (whitelist
# stance per CLAUDE.md), and that propagates to HM, so each target
# must opt in here. Matches docs/philosophy.md's "explicit > implicit"
# stance.
#
# If you import this bundle on a host whose foundation doesn't enable
# Stylix, the option paths below don't exist and eval fails loudly.
#
# btop deliberately omitted — programs.btop isn't enabled anywhere in
# the repo; enabling the Stylix target would generate dead theme
# config + closure bloat. Add when btop earns a place in cli-utils.nix.
#
# eza and lazydocker have no Stylix target upstream. eza uses
# LS_COLORS; lazydocker uses its own colour defaults.
_: {
  stylix.targets = {
    helix.enable = true;
    bat.enable = true;
    fzf.enable = true;
    starship.enable = true;
    zellij.enable = true;
    yazi.enable = true;
    lazygit.enable = true;
    # fish — enables Stylix's HM-side fish target (sets fish_color_*
    # via base16-fish). Fish is the only Stylix target with options on
    # both NixOS and HM layers; foundation deliberately enables
    # neither, so this is the sole switch-on for fish theming.
    fish.enable = true;
    # foot — desktop-host-only (metis). Inert on nixos-vm and mercury
    # because Stylix's foot target gates on `programs.foot.enable`,
    # which only resolves to true via the desktop-env bundle. Kept in
    # this central whitelist for discoverability — "where does Stylix
    # theming live?" reads as one file.
    foot.enable = true;
    # fuzzel — desktop-host-only (metis). Same inert-on-non-desktop
    # gating as foot above (gates on `programs.fuzzel.enable`). Stylix
    # writes the font (Inter at popups size), full base16 colour
    # palette across 11 slots, and polarity-driven icon-theme.
    fuzzel.enable = true;
    # fnott — desktop-host-only (metis). Same inert-on-non-desktop
    # gating as foot/fuzzel (gates on `services.fnott.enable`).
    # Stylix writes three fonts (title/summary/body), full colour
    # palette including per-urgency-level border accents
    # (low/normal/critical), and the polarity-driven icon-theme
    # (when stylix.icons is configured).
    fnott.enable = true;
  };
}
