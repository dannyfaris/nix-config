# Host-specific configuration for mac-mini (Apple Silicon Mac mini,
# aarch64-darwin). First Darwin host in the fleet; the operator's
# primary SSH client into the Linux hosts (nixos-vm, mercury, metis)
# and a cross-platform NixOS-builder via linux-builder (PRD §10, §11.6).
#
# Composes the Darwin foundation + linux-builder standalone, per
# ADR-027. macOS owns disk and hardware, so there is no disko.nix /
# hardware-configuration.nix sibling (ADR-023's three-file structure
# applies to NixOS hosts only).
#
# The `remote-access` bundle is deliberately NOT imported in this
# slice — it transitively pulls modules/shared/ghostty-terminfo.nix,
# whose `pkgs.ghostty.terminfo` is unavailable on aarch64-darwin
# (Ghostty ships as a native .app on macOS, not via nixpkgs). The bug
# would have surfaced on first eval of any Darwin host that imported
# the bundle, but no darwinConfiguration existed until this PR.
# Tracked in #167; once resolved, this host adopts
# `../../modules/darwin/bundles/remote-access.nix` to enable inbound
# SSH + mosh. Functional impact for first activation is nil — the
# runbook's SSH-context verification flow is outbound from this host.
#
# Bootstrap runbook: docs/runbooks/darwin-bootstrap.md.
_: {
  imports = [
    # Foundation — bundle every Darwin host imports by convention.
    ../../modules/darwin/foundation.nix

    # Standalone system modules.
    ../../modules/darwin/linux-builder.nix
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
      ../../home/shared/agent-clis.nix
      ../../home/shared/agent-clis-extras.nix
    ];
  };
}
