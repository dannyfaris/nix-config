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

    # Capability bundles.
    ../../modules/darwin/bundles/remote-access.nix

    # Standalone system modules.
    ../../modules/darwin/linux-builder.nix
    # nix-homebrew + declarative cask list per ADR-031. Owns Ghostty,
    # Tailscale (`tailscale-app`), and 1Password on Darwin, plus the
    # Sparkle silent-update keys for the two Sparkle-driven apps. See
    # docs/desktop/{ghostty,tailscale,1password}.md for per-app
    # rationale + fallback recipes.
    ../../modules/darwin/homebrew.nix
  ];

  networking.hostName = "mac-mini";

  # Integer stateVersion (Darwin's form; distinct from NixOS's "25.11"
  # string and separately tracked from `system.darwinRelease`). Pins
  # the nix-darwin release this host is compatible with — keeps
  # option-defaults stable across upgrades per nix-darwin's
  # `version.nix` description. Never bumped silently. 7 is the current
  # upstream `maxStateVersion`.
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
  # (personal dev box: cli-tooling + git-personal + full agent CLI set)
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
      ../../home/shared/bundles/git-personal.nix
      ../../home/shared/stylix-targets.nix
      ../../home/shared/ssh.nix
      ../../home/shared/macchina.nix
      ../../home/darwin/macchina-shell-init.nix
      # Ghostty user config (~/.config/ghostty/config). Cask owns the
      # .app — see modules/darwin/homebrew.nix and docs/desktop/ghostty.md.
      ../../home/darwin/ghostty.nix
      ../../home/shared/agent-clis.nix
      ../../home/shared/agent-clis-extras.nix
    ];
  };
}
