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
  # `gtk` target — Stylix's per-app targets above already gate on their own
  # `programs.<X>.enable`, but `gtk` has no per-app gate upstream. (The `qt`
  # target was dropped in #103 — see below.)
  desktopSession = config.programs.foot.enable or false;
in
{
  stylix.targets = {
    # foot — desktop-host-only (metis). Inert on non-desktop hosts via
    # upstream Stylix's `programs.foot.enable` gate.
    foot.enable = true;
    # niri — brings the compositor onto the palette. Stylix writes the
    # window border (active base0D / inactive base03) and disables the
    # focus-ring, so the active-window accent rides the idiomatic base0D
    # slot. Border width + corner radius are set in home/nixos/niri.nix.
    # Desktop-only by virtue of this file's import path. See
    # docs/desktop/niri.md §Window decorations.
    niri.enable = true;
    # fuzzel — gates on `programs.fuzzel.enable`. Stylix writes font
    # (IBM Plex Sans at popups size — the chrome sans, #369), full base16
    # palette across 11 slots, and polarity-driven icon-theme.
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
    # @base05 border; urgent @base08). Font is Stylix's monospace default
    # (Monaspace Argon Nerd Font) — under the hybrid model the bar is driven
    # chrome and rides the terminal mono, whose Nerd glyphs cover network/tray
    # directly, so waybar.nix adds no font override or symbols fallback (#369).
    waybar.enable = true;
    # swaylock — gates on `programs.swaylock.enable` (set in
    # home/nixos/screen-lock.nix). Stylix writes the lock screen's
    # colour config (~/.config/swaylock/config) so the lock surface
    # follows the host palette. See docs/desktop/screen-lock.md.
    swaylock.enable = true;
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
    # gtk — toolkit-level theming, no per-app gating upstream (unlike
    # foot/fuzzel/fnott/waybar/firefox above, which gate on
    # `programs.<X>.enable` and become inert on non-desktop hosts).
    # Gated locally on `desktopSession` so a future desktop-less host
    # importing this file (unlikely under the desktop-env bundle) won't
    # pull adw-gtk3 / gtk+3 (~42 MiB) for theming it can't render. On
    # metis the gate fires and GTK app chrome (file pickers, settings
    # dialogs, GTK apps generally) follows the base16 palette instead of
    # default Adwaita-light.
    #
    # The `qt` target was dropped (#103). The polkit-kde agent was the
    # only Qt app on metis; swapping it for mate-polkit (GTK) left zero
    # Qt apps, so `qt` theming themed nothing — removing it (and the
    # agent's KDE-Frameworks layer) trims a measured 573 MiB. Re-add
    # `qt.enable = lib.mkIf desktopSession true;` if a Qt app is ever
    # installed. See docs/desktop/polkit.md.
    gtk.enable = lib.mkIf desktopSession true;
  };

  # GTK app-UI uses the sansSerif chrome face (IBM Plex Sans), matching
  # waybar/fnott/fuzzel since the #369 typography pass — GTK chrome (the
  # polkit prompt, GTK file pickers, GTK app dialogs) is UI chrome, so it
  # rides the proportional sans rather than the terminal's mono. Sized at the
  # popups slot (the chrome body size, M3 body) so dialogs match the
  # notification/launcher body, not the applications slot (12, which sizes
  # web body text). This inverts the earlier mono-app-UI boundary (#349,
  # #108). mkForce because Stylix's gtk target also writes gtk.font. See
  # docs/desktop/fonts.md §Sizing.
  gtk.font = lib.mkIf desktopSession (
    lib.mkForce {
      name = config.stylix.fonts.sansSerif.name;
      package = config.stylix.fonts.sansSerif.package;
      size = config.stylix.fonts.sizes.popups;
    }
  );
}
