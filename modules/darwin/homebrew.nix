# nix-homebrew layer + nix-darwin homebrew cask list, per
# ADR-031 (docs/decisions/ADR-031-nix-homebrew-boundary.md).
#
# Two layers compose: nix-homebrew bootstraps the Homebrew prefix and
# pins taps as flake inputs; nix-darwin's own `homebrew` module
# manages the declarative cask list, activation behaviour, and the
# Sparkle silent-update keys via system.defaults.CustomUserPreferences.
#
# Configuration stance (per ADR-031 §Configuration stance):
#   - mutableTaps = false  — taps fully declarative; injects
#     HOMEBREW_NO_AUTO_UPDATE=1 for activation-time brew invocations.
#   - homebrew.global.autoUpdate = false  — extends the no-auto-update
#     posture to interactive brew invocations.
#   - onActivation.cleanup = "uninstall"  — the cask list is the
#     single source of truth; out-of-band installs are removed at
#     activation. (`zap` would also delete user data; too aggressive.)
#   - onActivation.autoUpdate = false + upgrade = false  — activation
#     installs missing casks but does not attempt brew-side upgrades.
#     Upgrades flow through the per-app vendor path.
#
# Update behaviour (per ADR-031 §Update mechanism stance + per-tool
# docs):
#   - Ghostty: Sparkle silent via auto-update = "download" in
#     home/darwin/ghostty.nix (Ghostty drives Sparkle's runtime
#     properties; the SU* keys below are belt-and-braces, inert today,
#     a hedge per docs/desktop/ghostty.md §Sharp edges).
#   - Tailscale: Sparkle silent via the SU* keys below (no in-app
#     config knob; CustomUserPreferences is the primary mechanism).
#   - 1Password: no CustomUserPreferences keys today — vendor prompts
#     accepted on "least action" grounds per ADR-031 §Rationale. The
#     suppression fallback (updates.autoUpdate = false) is documented
#     in docs/desktop/1password.md §Update behaviour for the day the
#     prompts become intolerable.
#
# Standalone module per ADR-027 (single-module — does not satisfy
# bundle-purity; no coherent sibling yet to graduate into a bundle).
# The host opts in by importing this module.
{ inputs, ... }:

let
  operator = import ../../lib/operator.nix;
  taps = {
    "homebrew/homebrew-core" = inputs.homebrew-core;
    "homebrew/homebrew-cask" = inputs.homebrew-cask;
  };
in
{
  imports = [
    inputs.nix-homebrew.darwinModules.nix-homebrew
  ];

  nix-homebrew = {
    enable = true;
    user = operator.name;
    inherit taps;
    mutableTaps = false;
  };

  homebrew = {
    enable = true;
    # The day-one cask list per ADR-031 §Day-one casks. Each cask has
    # a per-tool doc under docs/desktop/ recording justification,
    # configuration, fallback, and verification.
    casks = [
      "ghostty" # docs/desktop/ghostty.md
      "tailscale-app" # docs/desktop/tailscale.md  (NOT `tailscale`)
      "1password" # docs/desktop/1password.md
    ];
    # Mirror the taps declared by nix-homebrew so the nix-darwin module
    # knows which taps to expect — per zhaofengli/nix-homebrew README.
    taps = builtins.attrNames taps;
    global.autoUpdate = false;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "uninstall";
    };
  };

  # Sparkle silent-update keys for Ghostty + Tailscale's macOS app.
  # See per-tool docs (docs/desktop/{ghostty,tailscale}.md §Configuration)
  # for the per-app rationale + verification commands. Bundle IDs are
  # the *app* bundle IDs (not pkg installer IDs) — Tailscale's pkg ID
  # is com.tailscale.ipn.macsys, the app ID is io.tailscale.ipn.macsys.
  system.defaults.CustomUserPreferences = {
    "com.mitchellh.ghostty" = {
      SUEnableAutomaticChecks = true;
      SUAutomaticallyUpdate = true;
    };
    "io.tailscale.ipn.macsys" = {
      SUEnableAutomaticChecks = true;
      SUAutomaticallyUpdate = true;
    };
  };
}
