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
    # mas-cli formula. Declarative dependency for `homebrew.masApps`
    # — nix-darwin's `masApps` option emits `mas "<Name>", id: <id>`
    # lines into the Brewfile, but `brew bundle` needs the `mas`
    # binary on PATH to invoke them. brew bundle does have a lazy
    # fallback that tries to install `mas` on-demand the first time
    # it hits a `mas` entry without the binary present, but that
    # path is fragile (raises if the on-demand install fails for any
    # reason, and surfaces diagnostics inconsistently). Declaring
    # `mas` here makes the dependency a deterministic, explicit step
    # — brew bundle processes the Brewfile in strict file-line order
    # with `--jobs=1` (verified against nix-darwin's homebrew module
    # invocation), so `brew "mas"` is installed before any `mas`
    # entry is reached on a single first activation; no second pass
    # needed.
    #
    # The empirical 2026-06-03 mac-mini activation produced zero
    # MAS installs without this entry; the failure mode was the
    # lazy-fallback path interacting with mas-cli's auth-state
    # requirements (App Store sign-in is a separate prerequisite,
    # documented in docs/runbooks/darwin-bootstrap.md step 8).
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
      "hammerspoon" # docs/desktop/hammerspoon.md
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
      # Microsoft Teams intentionally NOT included — its MAS listing
      # broke activation (`mas install` failure); Teams runs via Chrome
      # instead. See docs/desktop/microsoft-365.md §Sharp edges.
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

  # Sparkle silent-update keys for Ghostty, Tailscale, Typora,
  # ChatGPT, AltTab, Karabiner-Elements, and Hammerspoon. See
  # per-tool docs (docs/desktop/{ghostty,tailscale,typora,chatgpt,
  # alt-tab,karabiner,hammerspoon}.md §Configuration) for the
  # per-app rationale + verification commands. Bundle IDs are the
  # *app* bundle IDs (not pkg installer IDs) — Tailscale's pkg ID
  # is com.tailscale.ipn.macsys, the app ID is io.tailscale.ipn.macsys.
  # ChatGPT's is `com.openai.chat` (singular "chat", not "chatgpt").
  # AltTab's is `com.lwouis.alt-tab-macos` (the upstream maintainer's
  # GitHub handle is part of the reverse-DNS prefix). Karabiner's
  # is `org.pqrs.Karabiner-Elements` (the main app — NOT the
  # `org.pqrs.Karabiner-DriverKit-VirtualHIDDevice` system extension,
  # NOT the `org.pqrs.Karabiner-EventViewer` companion). Karabiner
  # is pkg-enclosure Sparkle so the keys are belt-and-braces only —
  # Sparkle's package-updates path always prompts for admin auth
  # and has no silent mode (per Sparkle's own docs). Hammerspoon's
  # is `org.hammerspoon.Hammerspoon`; `.zip`-enclosure Sparkle so
  # the silent path applies (same shape as Ghostty).
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
    "com.openai.chat" = {
      SUEnableAutomaticChecks = true;
      SUAutomaticallyUpdate = true;
    };
    "com.lwouis.alt-tab-macos" = {
      SUEnableAutomaticChecks = true;
      SUAutomaticallyUpdate = true;
    };
    "org.pqrs.Karabiner-Elements" = {
      SUEnableAutomaticChecks = true;
      SUAutomaticallyUpdate = true;
    };
    "org.hammerspoon.Hammerspoon" = {
      SUEnableAutomaticChecks = true;
      SUAutomaticallyUpdate = true;
    };
  };
}
