# nix-homebrew layer + nix-darwin homebrew cask + MAS app list, per
# ADR-031 (docs/decisions/ADR-031-nix-homebrew-boundary.md).
#
# Two layers compose: nix-homebrew bootstraps the Homebrew prefix and
# pins taps as flake inputs; nix-darwin's own `homebrew` module
# manages the declarative cask list, the `masApps` Mac App Store list
# (installed via mas-cli per ADR-031 clause 3), activation behaviour,
# and the Sparkle silent-update keys via system.defaults.CustomUserPreferences.
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
#   - Slack (MAS): updates flow through Apple's mechanism — no
#     Sparkle/CustomUserPreferences keys apply per ADR-031 clause 3.
#     See docs/desktop/slack.md.
#   - Microsoft 365 — Word/Excel/PowerPoint/Outlook/Teams (MAS):
#     same Apple-mechanism update path as Slack. Named clause-3
#     advantage is bypassing Microsoft's installer/updater stack
#     end-to-end — both the .pkg installer's /Applications/ writes
#     and Microsoft AutoUpdate (MAU, com.microsoft.autoupdate2).
#     The Homebrew casks DO deselect MAU via their pkg `choices`
#     block, but the cask path still triggers the Microsoft pkg's
#     /Applications/ writes, and Office apps may re-install MAU on
#     first launch when missing. MAS sandboxing prevents MAU
#     structurally. See docs/desktop/microsoft-365.md.
#   - Amphetamine (MAS): MAS is the only channel — no direct .dmg,
#     no cask, no nixpkgs package. Clause 3 by absence of
#     alternative, not by weigh-up. See docs/desktop/amphetamine.md.
#   - Typora (cask, clause-2): Sparkle silent via the SU* keys
#     below under abnerworks.Typora. Nixpkgs path carved out
#     because the immutable nix-store .app breaks Sparkle's
#     in-place update flow. See docs/desktop/typora.md.
#   - Obsidian (cask, clause-2): MAS vendor-disrecommended
#     (sandbox restrictions break vault filesystem access).
#     Nixpkgs path carved out because the immutable nix-store .app
#     breaks Obsidian's electron-builder updater. No Sparkle keys —
#     Obsidian's updater is not Sparkle. Suppression fallback is
#     the in-app Settings → About → Automatic updates toggle, not
#     a `defaults`-domain key. See docs/desktop/obsidian.md.
#   - Chrome: Keystone (com.google.Keystone.Agent) runs on its
#     vendor default and silently updates /Applications/Google
#     Chrome.app. No CustomUserPreferences keys today — Keystone is
#     allowed to run because browsers are security-load-bearing
#     (Chrome ships weekly CVE patches). Suppression fallback
#     (checkInterval = 0) is documented in docs/desktop/chrome.md
#     §Update behaviour for the day Mosyle escalates /Applications/
#     writes.
#
# `masApps` cleanup asymmetry (per ADR-031 §Configuration stance):
# `homebrew.onActivation.cleanup = "uninstall"` does NOT extend to
# `homebrew.masApps` — Homebrew Bundle limitation. Dropping a masApps
# entry leaves the app installed; `mas uninstall <id>` is required.
# Per-tool docs for MAS apps record the uninstall recipe.
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
      "google-chrome" # docs/desktop/chrome.md  (NOT `google-chrome-for-testing`)
      "typora" # docs/desktop/typora.md
      "obsidian" # docs/desktop/obsidian.md
    ];
    # Mac App Store apps installed via mas-cli per ADR-031 clause 3.
    # Keys are display-only; the numeric ID is the load-bearing
    # identifier. Cleanup asymmetry callout in the header — dropping
    # an entry requires `mas uninstall <id>` manually.
    masApps = {
      "Slack" = 803453959; # docs/desktop/slack.md
      # Microsoft 365 suite per docs/desktop/microsoft-365.md. All-MAS
      # keeps Microsoft AutoUpdate (com.microsoft.autoupdate2) off the
      # system — mixed-channel installs would re-introduce it.
      "Microsoft Word" = 462054704;
      "Microsoft Excel" = 462058435;
      "Microsoft PowerPoint" = 462062816;
      "Microsoft Outlook" = 985367838;
      "Microsoft Teams" = 1113153706; # NOT the legacy `teams` bundle
      "Amphetamine" = 937984704; # docs/desktop/amphetamine.md
    };
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

  # Sparkle silent-update keys for Ghostty, Tailscale, and Typora.
  # See per-tool docs (docs/desktop/{ghostty,tailscale,typora}.md
  # §Configuration) for the per-app rationale + verification commands.
  # Bundle IDs are the *app* bundle IDs (not pkg installer IDs) —
  # Tailscale's pkg ID is com.tailscale.ipn.macsys, the app ID is
  # io.tailscale.ipn.macsys.
  system.defaults.CustomUserPreferences = {
    "com.mitchellh.ghostty" = {
      SUEnableAutomaticChecks = true;
      SUAutomaticallyUpdate = true;
    };
    "io.tailscale.ipn.macsys" = {
      SUEnableAutomaticChecks = true;
      SUAutomaticallyUpdate = true;
    };
    "abnerworks.Typora" = {
      SUEnableAutomaticChecks = true;
      SUAutomaticallyUpdate = true;
    };
  };
}
