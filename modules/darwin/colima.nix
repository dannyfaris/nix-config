# colima — Lima-VM-backed Docker daemon for Darwin. The Darwin parallel
# to modules/nixos/docker.nix (rootless dockerd); imported per-host,
# currently by neptune and saturn.
#
# Decision (colima vs Docker Desktop vs OrbStack) + the ADR-031
# install-path classification live in ADR-021 (amended 2026-06-03 for
# Darwin). Operator workflow, daemon lifecycle, the GUI-session
# auto-start caveat, and docker-context/DOCKER_HOST handling live in
# docs/desktop/colima.md. Single-sourced there per ADR-032 Rule 2;
# only the why-of-this-setting notes that aren't operator-facing stay
# inline below.
#
# Standalone module per ADR-027 (single-module — no coherent sibling
# yet to graduate into a bundle). The host opts in by importing it.
{ pkgs, lib, ... }:
let
  operator = import ../../lib/operator.nix;
in
{
  environment.systemPackages = [
    pkgs.colima # the daemon + control CLI
    pkgs.docker # the docker client; colima daemon registers the context
    # standalone `docker-compose` (subcommand-vs-standalone caveat:
    # modules/nixos/docker.nix + ADR-021 §Consequences).
    pkgs.docker-compose
  ];

  # Auto-start colima on GUI-session load (the gui-domain caveat and the
  # auto-login mitigation live in docs/desktop/colima.md §Sharp edges).
  # `colima start` is fire-and-exit, so RunAtLoad is the load-bearing
  # knob; KeepAlive = false stops launchd respawning after it exits 0,
  # and a repeat start on an already-running VM is a no-op.
  launchd.user.agents.colima = {
    serviceConfig = {
      ProgramArguments = [
        "${pkgs.colima}/bin/colima"
        "start"
      ];
      RunAtLoad = true;
      KeepAlive = false;
      # launchd agents get a minimal PATH without the nix profile, so
      # `colima start`'s dependency check fatals "docker not found" and
      # silently breaks auto-start. Inject docker explicitly; colima's
      # own VM deps (limactl, the vz backend) are wrapped into its binary.
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

  # DOCKER_HOST for SDK clients (lazydocker) that ignore colima's docker
  # context — see docs/desktop/colima.md §Sharp edges. A home-manager
  # sessionVariable (not environment.variables) so it's sourced by fish
  # and inherited by zellij panes; keeps all colima wiring in this module.
  home-manager.users.${operator.name}.home.sessionVariables.DOCKER_HOST =
    "unix://${operator.darwinHome}/.colima/default/docker.sock";
}
