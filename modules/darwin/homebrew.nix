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
# Per-app update behaviour — clause classification (ADR-031), update
# mechanism (Sparkle / Keystone / MAS / Electron / ToDesktop / custom),
# Sparkle bundle ID, nixpkgs carve-out rationale, and first-run TCC /
# DriverKit prompts — lives in the per-tool doc for each app under
# docs/desktop/, which every cask and masApps entry below points to by
# name. It is single-sourced to those docs (not restated here) per
# ADR-032 (Rule 2 — single-sourced rationale); the Sparkle keys this
# module actually sets are annotated at their definition below.
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
    # mas-cli — required on PATH for `homebrew.masApps`. brew bundle's
    # lazy on-demand install of `mas` is fragile, so declare it
    # explicitly; brew processes the Brewfile in file-line order, so
    # `mas` lands before any `mas` entry on first activation. The
    # one-time App Store sign-in prerequisite and the 2026-06-03
    # ordering-failure incident are recorded in
    # docs/runbooks/darwin-bootstrap.md and
    # docs/desktop/microsoft-365.md §Sharp edges.
    brews = [ "mas" ];

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
      "cursor" # docs/desktop/cursor.md  (Darwin install-path doc only — IDE selection is foregone, see README "Deliberate no-doc")
      "claude" # docs/desktop/claude-desktop.md
      "chatgpt" # docs/desktop/chatgpt.md
      "google-gemini" # docs/desktop/gemini.md  (NOT the Cypress North MAS app — that's a crypto wallet)
      "fellow" # docs/desktop/fellow.md
      "wispr-flow" # docs/desktop/wispr-flow.md
      "alt-tab" # docs/desktop/alt-tab.md
      "karabiner-elements" # docs/desktop/karabiner.md
      "logitune" # docs/desktop/logi-tune.md
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
      # Microsoft Teams intentionally excluded — runs in Chrome.
      # See docs/desktop/microsoft-365.md §Sharp edges.
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

  # Sparkle silent-update keys for the Sparkle-driven casks. The *app*
  # bundle ID (distinct from the pkg installer ID), each app's update
  # mechanism, and the verification commands are single-sourced to the
  # per-tool doc pointed at on each key (ADR-032 Rule 2). The one
  # pkg-enclosure cask (Karabiner) gets no silent path from Sparkle, so
  # its keys are belt-and-braces — see docs/desktop/karabiner.md.
  system.defaults.CustomUserPreferences = {
    # docs/desktop/ghostty.md
    "com.mitchellh.ghostty" = {
      SUEnableAutomaticChecks = true;
      SUAutomaticallyUpdate = true;
    };
    # docs/desktop/tailscale.md
    "io.tailscale.ipn.macsys" = {
      SUEnableAutomaticChecks = true;
      SUAutomaticallyUpdate = true;
    };
    # docs/desktop/typora.md
    "abnerworks.Typora" = {
      SUEnableAutomaticChecks = true;
      SUAutomaticallyUpdate = true;
    };
    # docs/desktop/chatgpt.md
    "com.openai.chat" = {
      SUEnableAutomaticChecks = true;
      SUAutomaticallyUpdate = true;
    };
    # docs/desktop/alt-tab.md
    "com.lwouis.alt-tab-macos" = {
      SUEnableAutomaticChecks = true;
      SUAutomaticallyUpdate = true;
    };
    # docs/desktop/karabiner.md
    "org.pqrs.Karabiner-Elements" = {
      SUEnableAutomaticChecks = true;
      SUAutomaticallyUpdate = true;
    };
  };
}
