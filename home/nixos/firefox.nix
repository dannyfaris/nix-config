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
# package portability. On macOS the browser is Chrome (the
# `google-chrome` cask in modules/darwin/homebrew.nix; docs/desktop/chrome.md).
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
    # See docs/desktop/firefox.md for the migration rationale.
    configPath = ".mozilla/firefox";
    profiles.default = {
      id = 0;
      isDefault = true;
    };

    # 1Password browser extension, installed declaratively via Firefox's
    # managed-policy mechanism (HM `policies` → the wrapper's extraPolicies →
    # policies.json) — no NUR input pulled in for one addon. `normal_installed`
    # installs it but leaves the operator in control (not `force_installed`,
    # which would lock it on — overkill for a personal box). The GUID is the
    # addon's AMO id (verified, not the slug). Declarative *install* only; the
    # native-messaging handshake to the desktop app rides the setgid
    # BrowserSupport wrapper + onepassword group from modules/nixos/
    # onepassword-gui.nix. See docs/desktop/1password.md §"Browser extension".
    policies.ExtensionSettings."{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
      installation_mode = "normal_installed";
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
