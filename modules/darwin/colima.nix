# colima — Lima-VM-backed Docker daemon for Darwin. Imported per-host;
# currently only by mac-mini. Mirrors the structure of
# modules/nixos/docker.nix (NixOS rootless dockerd) on the Darwin side
# of the fleet.
#
# Runtime choice (colima vs Docker Desktop vs OrbStack, with the
# license-cost / GUI-premium weigh-up) and the ADR-031 install-path
# walk are single-sourced to ADR-021 §"Darwin-specific rationale"
# (amended 2026-06-03 to cover Darwin) and docs/desktop/colima.md
# §Selection — not restated here (ADR-032 Rule 2). The operator-facing
# daemon lifecycle — first-use `colima start` resource flags, the
# launchd auto-start, and the GUI-session / auto-login caveat for
# unattended reboots — lives in docs/desktop/colima.md (§Workflow,
# §Sharp edges).
#
# Standalone module per ADR-027 (single-module — does not satisfy
# bundle-purity; no coherent sibling yet to graduate into a bundle).
# The host opts in by importing this module.
{ pkgs, lib, ... }:
let
  operator = import ../../lib/operator.nix;
in
{
  environment.systemPackages = [
    pkgs.colima # the daemon + control CLI
    pkgs.docker # the docker client; colima daemon registers the context
    pkgs.docker-compose # standalone `docker-compose` binary (same
    # shape as NixOS module — see modules/nixos/docker.nix for the
    # subcommand-vs-standalone caveat ADR-021 §Consequences names).
  ];

  # launchd user agent — auto-starts colima on GUI session load.
  # `colima start` is fire-and-exit: it brings up the Lima VM and
  # returns, the VM persisting as a separate process. So RunAtLoad is
  # the load-bearing knob; KeepAlive = false stops launchd respawning
  # after the start command exits 0. Re-firing when the VM is already
  # up is an idempotent no-op, so it's safe on every session load.
  # Agent stdout/stderr go to ~/Library/Logs/colima.{out,err}.log for
  # first-start debugging.
  launchd.user.agents.colima = {
    serviceConfig = {
      ProgramArguments = [
        "${pkgs.colima}/bin/colima"
        "start"
      ];
      RunAtLoad = true;
      KeepAlive = false;
      # launchd agents run with a minimal PATH that lacks the nix profile,
      # so `colima start`'s dependency check couldn't find the `docker` CLI
      # (it's in environment.systemPackages → on the interactive PATH, but
      # NOT here) and fataled "docker not found", silently breaking
      # auto-start. Give the agent docker explicitly; colima's own VM deps
      # (limactl, the vz backend) are wrapped into its binary, and the
      # system paths cover tools lima shells out to (ssh, etc.).
      EnvironmentVariables.PATH =
        lib.makeBinPath [
          pkgs.docker
          pkgs.docker-compose
        ]
        + ":/usr/bin:/bin:/usr/sbin:/sbin";
      StandardOutPath = "${operator.darwinHome}/Library/Logs/colima.out.log";
      StandardErrorPath = "${operator.darwinHome}/Library/Logs/colima.err.log";
    };
  };

  # DOCKER_HOST for SDK clients (lazydocker) that ignore the docker-CLI
  # context colima registers and instead read DOCKER_HOST or fall back to
  # /var/run/docker.sock — colima populates neither. Set as a home-manager
  # session var so it's sourced by fish and inherited by zellij panes
  # (nix-darwin's environment.variables doesn't reliably reach a
  # GUI-launched fish). Darwin parallel to the NixOS docker module's
  # setSocketVariable.
  home-manager.users.${operator.name}.home.sessionVariables.DOCKER_HOST =
    "unix://${operator.darwinHome}/.colima/default/docker.sock";
}
