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
#   - Microsoft 365 — Word/Excel/PowerPoint/Outlook (MAS):
#     same Apple-mechanism update path as Slack. Named clause-3
#     advantage is bypassing Microsoft's installer/updater stack
#     end-to-end — both the .pkg installer's /Applications/ writes
#     and Microsoft AutoUpdate (MAU, com.microsoft.autoupdate2).
#     The Homebrew casks DO deselect MAU via their pkg `choices`
#     block, but the cask path still triggers the Microsoft pkg's
#     /Applications/ writes, and Office apps may re-install MAU on
#     first launch when missing. MAS sandboxing prevents MAU
#     structurally. Teams was originally scoped in but dropped
#     after the 2026-06-03 mac-mini activation surfaced an
#     `mas install` failure that broke the whole Brewfile run;
#     operator chose the Chrome web client at teams.microsoft.com
#     over chasing the right MAS listing. See
#     docs/desktop/microsoft-365.md §Sharp edges.
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
#   - Cursor (cask, clause-2): not on MAS. Nixpkgs path carved out
#     because the immutable nix-store .app breaks Cursor's
#     ToDesktop auto-updater (Anysphere ships point releases
#     multiple times per week; flake-bump cadence is a feature-
#     delivery cost). No Sparkle keys — ToDesktop-generated
#     `com.todesktop.*` bundle ID, in-IDE Update Mode toggle is
#     the suppression fallback. The Darwin install-path doc is
#     docs/desktop/cursor.md — narrowly scoped per the README
#     "Deliberate no-doc" precedent (IDE-selection rationale
#     lives in home/nixos/cursor-ide.nix).
#   - Claude desktop (cask, clause-1): no MAS, no Darwin nixpkgs
#     equivalent. Anthropic's custom in-app updater — NOT Sparkle,
#     no SU* keys. Suppression fallback is in-app toggle.
#     See docs/desktop/claude-desktop.md.
#   - ChatGPT (cask, clause-2): not on MAS. Nixpkgs path carved
#     out because the immutable nix-store .app breaks ChatGPT's
#     Sparkle auto-updater. SU* keys wired below under com.openai.chat.
#     See docs/desktop/chatgpt.md.
#   - Gemini (cask, clause-1): no MAS (the Cypress North "Gemini"
#     on MAS is a Stellar wallet, not Google's AI). No Darwin
#     nixpkgs equivalent at write-time. Update mechanism is
#     Keystone — SHARED with Chrome's existing Keystone install
#     (one launchd agent, both apps). Suppression fallback recipe
#     in docs/desktop/chrome.md applies to both apps simultaneously.
#     See docs/desktop/gemini.md.
#   - Fellow (cask, clause-1): no MAS, no nixpkgs Darwin. Electron-
#     style in-app updater (no Sparkle keys). Bundle ID
#     `com.electron.fellow`. See docs/desktop/fellow.md.
#   - Wispr Flow (cask, clause-1): no MAS, no nixpkgs Darwin.
#     Electron-style in-app updater. Bundle ID
#     `com.electron.wispr-flow`. macOS Monterey+; needs
#     Accessibility + Microphone TCC prompts on first run. See
#     docs/desktop/wispr-flow.md.
#   - AltTab (cask, clause-2): not on MAS (GPL3+, upstream
#     distributes via GitHub releases only). Nixpkgs path carved
#     out because the immutable nix-store .app breaks AltTab's
#     Sparkle auto-updater (no pre-disable safety like Chrome).
#     SU* keys wired below under com.lwouis.alt-tab-macos.
#     Needs Accessibility + Screen Recording TCC prompts on first
#     run. See docs/desktop/alt-tab.md.
#   - Hammerspoon (cask, clause-1): not on MAS (sandboxed MAS
#     cannot drive Accessibility-API window manipulation or
#     global event taps). Not in nixpkgs Darwin
#     (`pkgs.hammerspoon` returns "does not provide attribute" on
#     aarch64-darwin / x86_64-darwin) — clause 1 fires; no
#     degradation analysis needed. `.zip`-enclosure Sparkle so
#     silent updates work (same shape as Ghostty). SU* keys wired
#     below under `org.hammerspoon.Hammerspoon`. Needs Accessibility
#     TCC prompt on first launch (one-time). Declarative init.lua
#     managed by home/darwin/hammerspoon.nix (read-only symlink —
#     UI / console edits do not survive activation). The macOS
#     hotkey-binding layer that lives on top of Karabiner's Hyper
#     modifier. See docs/desktop/hammerspoon.md.
#   - Karabiner-Elements (cask, clause-2): not on MAS (DriverKit +
#     sandbox structurally incompatible). Nixpkgs path carved out
#     because Karabiner is a privileged-pkg-installed system
#     component — DriverKit system extension + 7+ launchd jobs at
#     /Library/{LaunchDaemons,LaunchAgents}/ + privileged install
#     at /Library/Application Support/org.pqrs/Karabiner-Elements/
#     — that nix-store extraction cannot drive through macOS's
#     systemextensionsctl approval flow. Same shape as Tailscale
#     (pkg + system extension). Sparkle is pkg-enclosure so
#     updates always prompt for admin auth (no silent path per
#     Sparkle's docs); SU* keys below are belt-and-braces only.
#     Bundle ID `org.pqrs.Karabiner-Elements`. Needs DriverKit
#     extension approval (Login Items & Extensions → Driver
#     Extensions) + Input Monitoring TCC on first run. Declarative
#     karabiner.json managed by home/darwin/karabiner.nix
#     (read-only symlink — UI edits do not survive activation).
#     See docs/desktop/karabiner.md.
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
      # Microsoft Teams intentionally NOT included — see
      # docs/desktop/microsoft-365.md §Sharp edges. Teams's MAS
      # listing surfaced an `mas install` failure on the 2026-06-03
      # mac-mini bring-up that broke the entire activation; operator
      # chose to drop the desktop client and use Teams via Chrome at
      # teams.microsoft.com instead.
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
