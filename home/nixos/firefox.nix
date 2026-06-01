# firefox — Mozilla's web browser; Gecko engine; native Wayland.
#
# Stylix theming is wired centrally via
# `stylix.targets.firefox = { enable = true; profileNames = [ "default" ]; }`
# in home/nixos/stylix-targets-desktop.nix. Both fields are required:
# `enable` because our foundation sets `stylix.autoEnable = false`
# (whitelist stance per CLAUDE.md); `profileNames` because Stylix's
# Firefox module cannot auto-detect profile names without infinite
# recursion in the module system (documented in stylix's
# modules/firefox/meta.nix). Stylix writes per-profile font.name +
# font.size prefs into the `default` profile declared below.
#
# Lives under nixos/ because the desktop-registration surface
# (xdg.mimeApps) is Linux-only. Unlike foot/fuzzel/fnott/waybar
# (which don't build on Darwin at all), pkgs.firefox does build on
# Darwin — placement here is gated by the xdg.mimeApps wiring, not
# package portability. The macOS browser selection is deferred to
# home/darwin/ per the mac-mini onboarding epic #11.
#
# Wayland enablement requires no extra wiring: Firefox 121+ (we ship
# 150-class via nixos-unstable) auto-detects WAYLAND_DISPLAY at
# startup and launches native Wayland. Verify in `about:support` →
# "Window Protocol" row reads `wayland`.
#
# The `default` profile is declared as a stub — id = 0, isDefault =
# true are explicit for clarity but both have appropriate defaults.
# Settings, bookmarks, extensions can land here later; day 1 the
# stub exists primarily so Stylix has a profile name to target.
#
# MIME registration covers the URL paths xdg-open is asked to
# resolve in daily use: HTML/XHTML files, http/https URLs, about:
# URIs Firefox itself emits, and unknown:// scheme fallback. See
# docs/desktop/firefox.md for the full selection rationale and
# sharp edges (declarative-prefs vs profile-state, XDG path
# migration in HM 26.05, Stylix-prefs vs Firefox UI tug-of-war).
#
# Per #76.
_: {
  programs.firefox = {
    enable = true;
    # Pin the legacy profile-config path. HM 26.05 flipped the default to
    # `$XDG_CONFIG_HOME/mozilla/firefox`; our `home.stateVersion` is
    # `"25.11"` (set once, never change) so we still get the legacy path,
    # but HM warns on every rebuild until we declare intent explicitly.
    # Same pattern as `gtk.gtk4.theme` in stylix-targets-desktop.nix. See
    # docs/desktop/firefox.md for the migration rationale.
    configPath = ".mozilla/firefox";
    profiles.default = {
      id = 0;
      isDefault = true;
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "application/xhtml+xml" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
    };
  };
}
