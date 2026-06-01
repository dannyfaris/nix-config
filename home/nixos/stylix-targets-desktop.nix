# Stylix HM-side target enables for the **desktop** stack — the
# targets whose option paths only exist on hosts that import the
# desktop-env home bundle. Companion to `home/shared/stylix-targets.nix`
# (which carries the cross-platform-safe TUI targets).
#
# Lives under `home/nixos/` because every entry here is driven by a
# module that's Linux-only today (foot/fuzzel/fnott/waybar via Wayland;
# firefox/zen-browser via the launcher integration in `home/nixos/`;
# gtk/qt theming as part of the niri session). Imported by
# `home/nixos/bundles/desktop-env.nix` so desktop hosts pick it up
# transitively without needing a separate import line.
#
# Why the split: Stylix's `autoload.nix` declares every target's
# `enable` option universally regardless of platform, so the pre-split
# `home/shared/stylix-targets.nix` would have evaluated cleanly on
# Darwin (config emission is gated inside each target via
# `programs.<X>.enable` + per-config arg availability). Co-locating the
# desktop targets with the bundle that actually enables them is an
# architectural cleanup — it makes "what does mac-mini's HM tree
# include?" answerable by the import graph alone, rather than by
# tracing per-target gates inside a cross-platform file. The split is
# closure-identical for every NixOS host (verified pre/post; mercury
# and nixos-vm never imported the desktop bundle, so their targets
# were inert by construction; metis picks up the same set via the
# desktop-env bundle).
#
# Done as a prerequisite for the mac-mini onboarding work (#11).
{ config, lib, ... }:
let
  # `programs.foot.enable` is true only on desktop hosts (currently just
  # metis). Used as the desktop-session proxy to gate the toolkit-level
  # (gtk + qt) targets — Stylix's per-app targets above already gate on
  # their own `programs.<X>.enable`, but gtk/qt have no per-app gate
  # upstream.
  desktopSession = config.programs.foot.enable or false;
in
{
  stylix.targets = {
    # foot — desktop-host-only (metis). Inert on non-desktop hosts via
    # upstream Stylix's `programs.foot.enable` gate.
    foot.enable = true;
    # fuzzel — gates on `programs.fuzzel.enable`. Stylix writes font
    # (Inter at popups size), full base16 palette across 11 slots, and
    # polarity-driven icon-theme.
    fuzzel.enable = true;
    # fnott — gates on `services.fnott.enable`. Stylix writes three
    # fonts (title/summary/body), full colour palette including
    # per-urgency-level border accents (low/normal/critical), and the
    # polarity-driven icon-theme.
    fnott.enable = true;
    # waybar — gates on `programs.waybar.enable`. Stylix writes the CSS
    # (programs.waybar.style) with the full base16 palette as
    # @define-color variables, default background + text + tooltip
    # styling, and per-state workspace-button styling (focused/active
    # @base05 border; urgent @base08). Font defaults to monospace
    # (JetBrains Mono Nerd Font) for Nerd Font glyph coverage in
    # network/tray modules.
    waybar.enable = true;
    # firefox — gates on `programs.firefox.enable`. profileNames is
    # operator-declared because Stylix's Firefox module can't auto-
    # detect profile names without infinite recursion (documented in
    # stylix's modules/firefox/meta.nix). Stylix writes per-profile
    # font prefs (font.name.{monospace,sans-serif,serif} and
    # font.size.{monospace,variable}) into the `default` profile
    # declared in home/nixos/firefox.nix. Chrome-theming opt-ins
    # (colorTheme via Firefox Color extension; firefoxGnomeTheme via
    # the firefox-gnome-theme upstream) are NOT enabled day 1 — stock
    # chrome is fine. The two surfaces (the profile name here and
    # `programs.firefox.profiles.default` in firefox.nix) must stay in
    # lockstep.
    firefox = {
      enable = true;
      profileNames = [ "default" ];
    };
    # zen-browser — audit-phase parallel installation alongside Firefox
    # per #127. Stylix's `targets.zen-browser` *option* is always
    # declared via the autoload mechanism; what gates is the target's
    # *config* emission, which is wrapped in
    # `lib.optionals (options.programs ? zen-browser) [ … ]` inside
    # `modules/zen-browser/hm.nix` upstream — and `programs.zen-browser`
    # only exists where the flake HM module is imported (metis, via
    # `home/nixos/zen-browser.nix`). Net: writes prefs on metis only.
    # profileNames must match the profile declared in zen-browser.nix.
    # Stylix writes font name prefs, reader-mode colours, userChrome.css
    # (full base16 mapping into Zen's own --zen-* variable surface), and
    # userContent.css (about:-page chrome styling). `enableCss = true`
    # is the upstream default and intentionally not restated — disabling
    # it would defeat the audit. Unlike Firefox's target, Zen's does NOT
    # write font.size — Zen falls back to its built-in font sizing; see
    # docs/desktop/zen.md §Sharp edges.
    zen-browser = {
      enable = true;
      profileNames = [ "default" ];
    };
    # gtk + qt — toolkit-level theming, no per-app gating upstream
    # (unlike foot/fuzzel/fnott/waybar/firefox above, which gate on
    # `programs.<X>.enable` and become inert on non-desktop hosts).
    # Gated locally on `desktopSession` so a future desktop-less host
    # importing this file (unlikely under the desktop-env bundle) won't
    # pull adw-gtk3, gtk+3 (~42 MiB), CUPS, or the Qt5 stack (qtbase +
    # qtdeclarative + qttools + … ~118 MiB) for theming it can't
    # render — measured +585 MiB closure on mercury without the gate.
    # On metis the gate fires and GTK/Qt app chrome (file pickers,
    # settings dialogs, GTK/Qt apps generally) follows the base16
    # palette instead of default Adwaita-light.
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
