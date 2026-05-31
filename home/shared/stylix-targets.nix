# Stylix HM-side target enables for the TUI stack. Stylix's palette
# propagation comes from modules/nixos/stylix-palette.nix (the
# system-side module imported by foundation, which sets stylix.enable
# = true and auto-wires HM via homeManagerIntegration). This module is
# the explicit whitelist of which HM-managed tools cede their theming
# to Stylix.
#
# Standalone module, not a bundle — despite the plural filename. It is a
# single coherent capability (the Stylix-target whitelist) expressed as a
# flat list of `enable` toggles, so it sets options inline and lives
# directly under home/shared/ rather than in bundles/. Bundles are
# pure `imports` aggregations of >= 2 modules (bundle-purity, PRD §8.1
# #4); a whitelist of toggles is not an aggregation. It was mis-filed
# under bundles/ at birth (PR #30, pre-lint) and reclassified here per
# #65 — see ADR-027 §History for the rationale.
#
# Foundation sets autoEnable = false at the NixOS layer (whitelist
# stance per CLAUDE.md), and that propagates to HM, so each target
# must opt in here. Matches docs/philosophy.md's "explicit > implicit"
# stance.
#
# If you import this module on a host whose foundation doesn't enable
# Stylix, the option paths below don't exist and eval fails loudly.
#
# btop deliberately omitted — programs.btop isn't enabled anywhere in
# the repo; enabling the Stylix target would generate dead theme
# config + closure bloat. Add when btop earns a place in cli-utils.nix.
#
# eza and lazydocker have no Stylix target upstream. eza uses
# LS_COLORS; lazydocker uses its own colour defaults.
{ config, lib, ... }:
let
  # `programs.foot.enable` is `true` only on hosts that pick up the
  # desktop-env bundle (currently just metis). Used as the desktop-session
  # proxy below to gate the toolkit-level (gtk + qt) targets — matches the
  # inert-on-non-desktop behaviour foot/fuzzel/fnott/waybar/firefox get
  # for free from upstream Stylix's own `programs.<X>.enable` gating.
  desktopSession = config.programs.foot.enable or false;
in
{
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
    # waybar — desktop-host-only (metis). Same inert-on-non-desktop
    # gating as foot/fuzzel/fnott (gates on `programs.waybar.enable`).
    # Stylix writes the CSS (programs.waybar.style) with the full
    # base16 palette as @define-color variables, default background
    # + text + tooltip styling, and per-state workspace-button
    # styling (focused/active @base05 border; urgent @base08).
    # Font defaults to monospace (JetBrains Mono Nerd Font) for
    # Nerd Font glyph coverage in network/tray modules.
    waybar.enable = true;
    # firefox — desktop-host-only (metis). Gates on
    # `programs.firefox.enable`. profileNames is operator-declared
    # because Stylix's Firefox module can't auto-detect profile
    # names without infinite recursion (documented in stylix's
    # modules/firefox/meta.nix). Stylix writes per-profile font
    # prefs (font.name.{monospace,sans-serif,serif} and
    # font.size.{monospace,variable}) into the `default` profile
    # declared in home/nixos/firefox.nix. Chrome-theming
    # opt-ins (colorTheme via Firefox Color extension;
    # firefoxGnomeTheme via the firefox-gnome-theme upstream) are
    # NOT enabled day 1 — stock chrome is fine. The two surfaces
    # (the profile name here and `programs.firefox.profiles.default`
    # in firefox.nix) must stay in lockstep.
    firefox = {
      enable = true;
      profileNames = [ "default" ];
    };
    # zen-browser — desktop-host-only (metis). Audit-phase parallel
    # installation alongside Firefox per #127. Stylix's
    # `targets.zen-browser` *option* is always declared via the
    # autoload mechanism, so setting `enable = true` here doesn't
    # fail on mercury / nixos-vm. What gates is the target's *config*
    # emission, which is wrapped in
    # `lib.optionals (options.programs ? zen-browser) [ … ]` inside
    # `modules/zen-browser/hm.nix` upstream — and `programs.zen-browser`
    # only exists where the flake HM module is imported (metis, via
    # `home/nixos/zen-browser.nix`). Net: a no-op on non-desktop hosts,
    # writes prefs on metis. profileNames must match the profile
    # declared in home/nixos/zen-browser.nix.
    # Stylix writes font name prefs, reader-mode colours,
    # userChrome.css (full base16 mapping into Zen's own --zen-*
    # variable surface), and userContent.css (about:-page chrome
    # styling). `enableCss = true` is the upstream default and
    # intentionally not restated — disabling it would defeat the
    # audit. Unlike Firefox's Stylix target, Zen's target does NOT
    # write font.size — Zen falls back to its built-in font sizing;
    # see docs/desktop/zen.md §Sharp edges. The two surfaces (the
    # profile name here and `programs.zen-browser.profiles.default`
    # in zen-browser.nix) must stay in lockstep.
    zen-browser = {
      enable = true;
      profileNames = [ "default" ];
    };
    # gtk + qt — toolkit-level theming, no per-app gating upstream
    # (unlike foot/fuzzel/fnott/waybar/firefox above, which gate on
    # `programs.<X>.enable` and become inert on non-desktop hosts). Gated
    # locally on `desktopSession` so mercury and nixos-vm don't pull
    # adw-gtk3, gtk+3 (~42 MiB), CUPS, or the Qt5 stack (qtbase +
    # qtdeclarative + qttools + … ~118 MiB) for theming they can't
    # render — measured +585 MiB closure on mercury without the gate.
    # On metis the gate fires and GTK/Qt app chrome (file pickers,
    # settings dialogs, GTK/Qt apps generally) follows the base16
    # palette instead of default Adwaita-light. Closes the documented-
    # vs-deployed gap in CLAUDE.md's "across … GTK/Qt" claim (cross-ref
    # #95); folded into #65 per its 2026-05-31 amendment.
    gtk.enable = lib.mkIf desktopSession true;
    qt.enable = lib.mkIf desktopSession true;
  };

  # Silence the home-manager `gtk.gtk4.theme` legacy-default deprecation
  # warning that surfaces whenever `config.gtk.theme` is set (which Stylix
  # does when `targets.gtk` fires above). Keeps legacy behaviour — GTK4
  # inherits the same theme as GTK3 — until home.stateVersion crosses
  # 26.05 and the default flips to `null` upstream. Same gate as the
  # target enable above so the option only resolves on desktop hosts.
  gtk.gtk4.theme = lib.mkIf desktopSession config.gtk.theme;
}
