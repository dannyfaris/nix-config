# Host-specific configuration for saturn (Apple Silicon MacBook Air,
# aarch64-darwin). Second Darwin host and the fleet's first laptop — the
# operator's portable personal + work daily driver, the travelling
# counterpart to neptune (the always-on desktop Mac mini). Celestial name
# per ADR-038; onboarded under epic #11 (the nix-darwin bring-up); this
# Phase-1 build (FileVault on, power.nix deferred) per #431.
#
# Composes the Darwin foundation + capability modules per ADR-027. macOS
# owns disk and hardware, so there is no disko.nix /
# hardware-configuration.nix sibling (ADR-023's three-file structure
# applies to NixOS hosts only).
#
# Saturn is essentially neptune minus two modules, both laptop-driven and
# deliberately omitted (see the imports list): power.nix (an always-on
# desktop posture, wrong for a battery) and sshd.nix (no inbound SSH on a
# roaming personal laptop). FileVault is on, enabled at the OS level at
# bootstrap — nix-darwin has no declarative FileVault option, so it is an
# operator step, not a module (see docs/runbooks/darwin-bootstrap.md).
#
# Bootstrap runbook: docs/runbooks/darwin-bootstrap.md.
_: {
  imports = [
    # Foundation — bundle every Darwin host imports by convention.
    ../../modules/darwin/foundation.nix

    # nix-homebrew + declarative cask list per ADR-031. The cask + masApps
    # list is fleet-shared (single source of truth in homebrew.nix), so
    # saturn carries the same full work + personal app set as neptune.
    ../../modules/darwin/homebrew.nix

    # colima — container runtime per ADR-021's 2026-06-03 amendment. Adds
    # pkgs.colima + docker + docker-compose to PATH and a launchd user
    # agent that auto-starts the Lima VM on GUI session establishment. See
    # docs/desktop/colima.md for the GUI-session dependency + auto-login
    # caveat.
    ../../modules/darwin/colima.nix

    # UTM — virtualisation platform. On saturn this hosts the operator's
    # own VMs (saturn is a VM host in its own right). Adds pkgs.utm to PATH
    # which surfaces both UTM.app and `utmctl`. See docs/desktop/utm.md.
    ../../modules/darwin/utm.nix

    # linux-builder — nix-darwin's built-in aarch64-linux build VM. neptune
    # carries it as the fleet's cross-platform builder; saturn carries its
    # own so the laptop stays self-sufficient for Linux builds when away
    # from neptune (offloading to neptune isn't reachable off the tailnet
    # / behind hotel NAT). See the module header for the resource-tuning
    # and x86_64-emulation notes.
    ../../modules/darwin/linux-builder.nix

    # Touch ID for sudo — pam_tid.so + pam_watchid.so. The MacBook Air's
    # built-in Touch ID is the sensor; Apple Watch unlock is the free
    # side-effect. See docs/darwin/touch-id.md.
    ../../modules/darwin/touch-id.nix

    # macOS + App Store unattended-install posture (fleet-wide). See
    # docs/darwin/system-updates.md.
    ../../modules/darwin/system-updates.nix

    # macOS user-facing system preferences — Dock, Finder, save/print
    # dialog expansion, screensaver password-on-wake, boot chime. See the
    # module header for the per-knob rationale.
    ../../modules/darwin/system-prefs.nix

    # macOS keyboard shortcuts (com.apple.symbolichotkeys) — the screenshot
    # file/clipboard chord swap. See docs/desktop/keybinds.md §Screenshots.
    ../../modules/darwin/keyboard-shortcuts.nix

    # JankyBorders — the focused-window border for AeroSpace tiles (the macOS
    # analogue of the window border niri draws). Colours source from the design
    # tokens; runs as a launchd user agent. See the module header and
    # docs/design/macos-deterministic-tiling.md (ADR-040 Stage 2, #494).
    ../../modules/darwin/jankyborders.nix

    # Weekly launchd daemon to prune dead GC roots. nix-darwin does not
    # automatically remove dangling gcroot symlinks, so dead `result` links
    # silently pin store paths against GC (#512).
    ../../modules/darwin/nix-gcroots-cleanup.nix

    # Deliberately NOT imported (both laptop-driven; their absence is the
    # design, not an oversight):
    #   - sshd.nix — saturn is an SSH client, not a server; no inbound SSH
    #     on a roaming personal laptop (tighter attack surface). Reachability
    #     is outbound-only.
    #   - power.nix — its values (sleep.computer = "never",
    #     restartAfterPowerFailure) are an always-on desktop posture that
    #     would shred a battery and are meaningless on a host whose supply is
    #     its own battery. Saturn runs macOS factory laptop power defaults
    #     until an empirically-tuned power-laptop.nix lands (#431 Phase 2).
  ];

  # All three macOS name facets are set together so they agree. hostName is
  # the primary name; computerName is the System Settings > Sharing name;
  # localHostName is the Bonjour/.local name.
  networking = {
    hostName = "saturn";
    computerName = "Saturn";
    localHostName = "saturn";
  };

  # Integer stateVersion (Darwin's form). Pins the nix-darwin release this
  # host is compatible with — keeps option-defaults stable across upgrades.
  # Never bumped silently. 7 is the upstream maxStateVersion in the pinned
  # nix-darwin (matches neptune); re-verify against the pin before bumping.
  system.stateVersion = 7;

  # macOS owns user creation; nix-darwin only manages the attributes in
  # modules/darwin/users.nix. The UID must match exactly what macOS assigned
  # at first-boot setup — nix-darwin refuses to manage a user with a
  # mismatched UID, and the option is required at eval time. 501 is the
  # macOS first-user default; verify with `id -u dbf` on the actual machine
  # at first boot and correct here if it differs.
  users.users.dbf.uid = 501;

  # Per-host parametrisation consumed by home-manager modules. The full HM
  # imports list mirrors neptune's daily-driver set (cli-tooling +
  # git-multi-identity + the macOS client tools + full agent CLI set) — the
  # two hosts are the same operator's personal + work daily driver.
  #
  # flakePath omitted — host-context.nix's Darwin default
  # ("/Users/dbf/nix-config") matches this host.
  hostContext = {
    hostName = "saturn";
    extraHomeModules = [
      ../../home/shared/bundles/cli-tooling.nix
      ../../home/shared/bundles/git-multi-identity.nix
      ../../home/shared/stylix-targets.nix
      ../../home/shared/ssh.nix
      ../../home/shared/macchina.nix
      ../../home/darwin/macchina-shell-init.nix
      # macOS desktop workflow — Ghostty, Karabiner (Hyper), AeroSpace, the
      # screenshots dir, and the runtime theme-switching trio. The Darwin
      # parallel of home/nixos/bundles/desktop-env.nix; per-module rationale
      # lives in the bundle.
      ../../home/darwin/bundles/desktop-env.nix
      ../../home/shared/agent-clis.nix
      # Darwin variant — overrides `codex` to the upstream prebuilt
      # aarch64-darwin binary, sidestepping the source build cache.nixos.org
      # doesn't substitute on aarch64-darwin. See the module header and #220.
      ../../home/darwin/agent-clis-extras.nix
    ];
  };
}
