# macOS + App Store auto-update — unattended-install posture for the
# two Apple-owned update channels (macOS itself via SoftwareUpdate, MAS
# apps via Commerce). Mirrors the "binary stays current" stance the
# Sparkle silent-update keys carry for cask apps in homebrew.nix.
#
# Three keys, two surfaces:
#
#   1. `system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates`
#      — first-class nix-darwin option. Covers macOS point releases,
#      security responses (RSR), XProtect, MRT, configuration data.
#
#   2. `com.apple.commerce` `AutoUpdate` (via CustomUserPreferences)
#      — App Store auto-download. nix-darwin does NOT expose this as a
#      first-class option; the GUI toggle (System Settings → App Store
#      → Automatic Updates) writes to `com.apple.commerce`, not to
#      `com.apple.SoftwareUpdate`. CustomUserPreferences is the
#      sanctioned escape hatch — same pattern homebrew.nix uses for the
#      per-app Sparkle SU* keys.
#
#   3. `com.apple.commerce` `AutoUpdateRestartRequired` — MAS updates
#      that need a restart-to-install auto-install without prompting.
#      Without this, restart-required updates queue up and surface as
#      a prompt the next time System Settings is opened. The setting
#      is the difference between "most updates silently install" and
#      "all updates silently install" — the right choice given the
#      auto-update-everything stance.
#
# Capability-shaped per ADR-027: an unattended/CI Darwin host could
# legitimately want manual control over restart-required installs to
# avoid clobbering long-running tasks. Stays standalone, imported
# per-host. Future hosts that want manual control either don't import
# this module, or override the relevant key in their own default.nix.
#
# What this does NOT cover: per-app vendor updaters (Sparkle/Keystone/
# Electron/ToDesktop) are configured per-cask in homebrew.nix. MAS app
# installation declarations also live in homebrew.nix:masApps. Nix
# store updates flow through operator-driven `nix flake update` +
# `nh darwin switch`.
#
# Full rationale + manual-control fallback + sharp edges:
# docs/darwin/system-updates.md.
_: {
  system.defaults = {
    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;

    # CustomUserPreferences shape mirrors homebrew.nix:219–236
    # (Sparkle keys keyed by bundle ID). Apple's commerce domain is a
    # well-known stable surface; the GUI toggle writes the same keys.
    CustomUserPreferences."com.apple.commerce" = {
      AutoUpdate = true;
      AutoUpdateRestartRequired = true;
    };
  };
}
