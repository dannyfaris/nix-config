# Host-specific configuration for mac-mini (Apple Silicon Mac mini,
# aarch64-darwin). First Darwin host in the fleet; the operator's
# primary SSH client into the Linux hosts (nixos-vm, mercury, metis)
# and a cross-platform NixOS-builder via linux-builder (PRD §10, §11.6).
#
# Composes the Darwin foundation + remote-access bundle + linux-builder
# standalone, per ADR-027. macOS owns disk and hardware, so there is no
# disko.nix / hardware-configuration.nix sibling (ADR-023's three-file
# structure applies to NixOS hosts only).
#
# Bootstrap runbook: docs/runbooks/darwin-bootstrap.md.
_: {
  imports = [
    # Foundation — bundle every Darwin host imports by convention.
    ../../modules/darwin/foundation.nix

    # Standalone system modules.
    # Inbound SSH (key-only, no root, no password). Was the `remote-access`
    # bundle (sshd + mosh); mosh was removed (#47) and a single-module
    # bundle isn't allowed (ADR-027), so the bundle was dissolved and sshd
    # imported directly. Ghostty clients get terminfo via Ghostty's own
    # shell-integration ssh-terminfo push on connect (Ghostty ships as a
    # native .app on macOS, not a nixpkgs terminfo), or fall back to
    # TERM=xterm-256color.
    ../../modules/darwin/sshd.nix
    ../../modules/darwin/linux-builder.nix
    # nix-homebrew + declarative cask list per ADR-031. Owns Ghostty,
    # Tailscale (`tailscale-app`), and 1Password on Darwin, plus the
    # Sparkle silent-update keys for the two Sparkle-driven apps. See
    # docs/desktop/{ghostty,tailscale,1password}.md for per-app
    # rationale + fallback recipes.
    ../../modules/darwin/homebrew.nix

    # colima — container runtime per ADR-021's 2026-06-03 amendment.
    # Adds pkgs.colima + pkgs.docker + pkgs.docker-compose to PATH and
    # a `launchd.user.agents.colima` definition that auto-starts the
    # Lima VM on GUI session establishment (Darwin parallel to
    # `linger = true` on the Linux side). See docs/desktop/colima.md
    # for the GUI-session dependency + auto-login caveat.
    ../../modules/darwin/colima.nix

    # UTM — virtualisation platform; second Darwin nixpkgs-installed
    # runtime after colima. Hosts the nixos-vm fleet member. Adds
    # pkgs.utm to PATH which surfaces both UTM.app (via nix-darwin's
    # system-applications symlink) and `utmctl` (the CLI control tool,
    # via the derivation's makeWrapper loop). See docs/desktop/utm.md
    # for the ADR-031 walk + CLI-first rationale.
    ../../modules/darwin/utm.nix

    # Touch ID for sudo — pam_tid.so + pam_watchid.so via
    # `security.pam.services.sudo_local.touchIdAuth`. Magic Keyboard
    # with Touch ID is the sensor on this host; Apple Watch unlock is
    # the free side-effect. See docs/darwin/touch-id.md.
    ../../modules/darwin/touch-id.nix

    # macOS + App Store unattended-install posture. Three keys:
    # SoftwareUpdate.AutomaticallyInstallMacOSUpdates + the two
    # com.apple.commerce keys (AutoUpdate, AutoUpdateRestartRequired)
    # via CustomUserPreferences. Mirrors the Sparkle silent-update
    # stance applied to per-app casks in homebrew.nix. See
    # docs/darwin/system-updates.md.
    ../../modules/darwin/system-updates.nix

    # macOS user-facing system preferences — Dock, Finder, save/print
    # dialog expansion, screensaver password-on-wake, boot chime.
    # Bulk of the System Settings knobs the operator otherwise clicks
    # through on every new Mac. Rationale per-knob lives in the
    # module header.
    ../../modules/darwin/system-prefs.nix

    # Power / sleep / recovery for the always-on builder + SSH-bastion
    # role. Auto-restart after outage, never sleep the computer,
    # display sleep at factory default. Values here are wrong for a
    # battery-powered Mac — a future MacBook host would not import
    # this module. See module header for the per-knob rationale.
    ../../modules/darwin/power.nix
  ];

  networking.hostName = "mac-mini";

  # Integer stateVersion (Darwin's form; distinct from NixOS's "25.11"
  # string and separately tracked from `system.darwinRelease`). Pins
  # the nix-darwin release this host is compatible with — keeps
  # option-defaults stable across upgrades per nix-darwin's
  # `version.nix` description. Never bumped silently. 7 is the upstream
  # `maxStateVersion` as of 2026-06-05 (verified against the pinned
  # nix-darwin's `modules/system/version.nix` default). Re-verify
  # against the same file in the pinned input before bumping.
  system.stateVersion = 7;

  # macOS owns user creation; nix-darwin only manages the attributes in
  # modules/darwin/users.nix gated on users.knownUsers (already set in
  # the foundation). The UID must match exactly what macOS assigned at
  # first-boot setup — nix-darwin refuses to manage a user with a
  # mismatched UID, and the option is required at eval time (no
  # upstream default), so the host file must set it for the
  # darwinConfiguration to evaluate. 501 verified against `id -u dbf`
  # on the actual Mac (2026-06-02) — matches the macOS first-user
  # default.
  users.users.dbf.uid = 501;

  # Per-host parametrisation consumed by home-manager modules.
  # extraHomeModules is the full HM imports list for this host —
  # capability bundles + standalone modules per ADR-027. Mirrors metis
  # (personal dev box: cli-tooling + git-multi-identity + full agent CLI set)
  # with NixOS-only modules swapped for Darwin equivalents:
  #   - desktop-env dropped (macOS owns the desktop; no Darwin parallel).
  #   - home/nixos/macchina-shell-init.nix → home/darwin/macchina-shell-init.nix
  #     (Apple-logo ASCII + `route -n get default` interface detection).
  #
  # flakePath omitted — host-context.nix's Darwin default
  # ("/Users/dbf/nix-config") matches this host.
  hostContext = {
    hostName = "mac-mini";
    extraHomeModules = [
      ../../home/shared/bundles/cli-tooling.nix
      ../../home/shared/bundles/git-multi-identity.nix
      ../../home/shared/stylix-targets.nix
      ../../home/shared/ssh.nix
      ../../home/shared/macchina.nix
      ../../home/darwin/macchina-shell-init.nix
      # Ghostty user config (~/.config/ghostty/config). Cask owns the
      # .app — see modules/darwin/homebrew.nix and docs/desktop/ghostty.md.
      ../../home/darwin/ghostty.nix
      # Karabiner-Elements karabiner.json (~/.config/karabiner/karabiner.json).
      # Cask owns the .app + DriverKit system extension + launchd jobs;
      # this module owns the declarative remap config. Realizes the
      # Hyper modifier from docs/desktop/keybinds.md (caps_lock → ⌘⌃⌥⇧).
      # See docs/desktop/karabiner.md.
      ../../home/darwin/karabiner.nix
      # Hammerspoon init.lua (~/.hammerspoon/init.lua). Cask owns
      # the .app; this module owns the declarative Lua source.
      # Binds Hyper+letter / Hyper+key actions on top of Karabiner's
      # modifier. Enumerated bindings live in docs/desktop/keybinds.md
      # §"Active bindings — macOS clients". See docs/desktop/hammerspoon.md.
      ../../home/darwin/hammerspoon.nix
      # Ensures ~/Screenshots exists; pairs with screencapture.location
      # in modules/darwin/system-prefs.nix.
      ../../home/darwin/screenshots-dir.nix
      ../../home/shared/agent-clis.nix
      # Darwin variant — overrides `codex` to the upstream-published
      # prebuilt aarch64-darwin binary, sidestepping the heavy
      # rustPlatform.buildRustPackage + librusty_v8 source build that
      # cache.nixos.org doesn't substitute on aarch64-darwin. See
      # home/darwin/agent-clis-extras.nix header for the trade-off
      # framing and #220 for the alternatives analysis (this is
      # "Option A"). Linux hosts continue to import
      # home/shared/agent-clis-extras.nix unchanged.
      ../../home/darwin/agent-clis-extras.nix
    ];
  };
}
