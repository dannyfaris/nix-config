# colima — Lima-VM-backed Docker daemon for Darwin. Imported per-host;
# currently only by mac-mini. Mirrors the structure of
# modules/nixos/docker.nix (NixOS rootless dockerd) on the Darwin side
# of the fleet.
#
# See ADR-021 (amended 2026-06-03 to cover Darwin) for the full
# rationale. Short version of the per-Darwin-runtime evaluation:
#
#   - Docker Desktop (rejected): proprietary, heaviest footprint,
#     license-cost friction for company-funded work use (paid sub
#     required if employer >250 employees OR >$10M revenue),
#     diverges from the daemon-as-service mental model ADR-021 set
#     on the Linux side.
#   - OrbStack (rejected): polished, lightest, but proprietary and
#     license-cost-bearing for work use (~$96/seat/yr). Buys a GUI
#     the operator wouldn't use (lazydocker is the established TUI
#     client per ADR-006). Doesn't justify the cost when colima
#     covers the same functional surface.
#   - colima (chosen): FOSS (MIT), nix-native (pkgs.colima available
#     on aarch64-darwin), declarative install, mirrors ADR-021's
#     "daemon as a service, docker CLI on PATH, no GUI" posture on
#     NixOS. Pair with pkgs.docker as the CLI client, pkgs.docker-
#     compose for the standalone `docker-compose` binary (same shape
#     as the NixOS module's environment.systemPackages entry).
#
# Install-path under ADR-031:
#   - ADR-031's §Boundary rule sets "nixpkgs by default"; clauses 1-3
#     are carve-outs FROM that baseline (no Darwin equivalent;
#     materially-degraded nix-managed install; MAS as a third source).
#   - None of the three clauses fires here: pkgs.colima ships on
#     aarch64-darwin (clause 1 N/A); colima is a CLI/daemon with no
#     /Applications/-rooted bundle and no Sparkle auto-updater, so
#     the clause-2 degradation shape that governs GUI casks (Chrome,
#     Typora, Obsidian, 1Password, Cursor) does not apply; colima is
#     not distributed on MAS (clause 3 N/A).
#   - The nixpkgs-by-default baseline applies directly. Homebrew's
#     `colima` formula exists but offers nothing over the nixpkgs path.
#
# Daemon lifecycle:
#   - First-use: `colima start` (one-time bootstrap; downloads the
#     base Lima VM image, ~250MB; takes ~30s). Defaults: 2 CPU, 2GB
#     RAM, 60GB disk; override via `colima start --cpu N --memory N
#     --disk N` for larger workloads.
#   - Daily: colima persists VM state. After reboot, the launchd
#     user agent below re-runs `colima start` on first GUI session
#     establishment (see GUI-session dependency below for the SSH-
#     only-access caveat); the VM comes back with its previously-set
#     flags from ~/.colima/default/colima.yaml.
#   - launchd auto-start IS wired — the operator wants colima up and
#     ready whether at the keyboard or via SSH. This is the Darwin
#     parallel to `linger = true` on the Linux side; see ADR-021's
#     2026-06-03 amendment for the framing.
#
#   - GUI-session dependency: macOS `launchd.user.agents` fire when
#     the user's `gui/<uid>` domain becomes active — established by
#     GUI login (keyboard+display) or by macOS auto-login (System
#     Settings → Users & Groups → Automatic login). SSH alone does
#     NOT bootstrap the gui-domain; SSH into a Mac that has not had
#     a GUI login since boot will NOT have colima running.
#
#     For "always-on after unattended reboot (power cut etc.)
#     without anyone at the keyboard," the operator needs macOS
#     auto-login enabled. That toggle is not nix-darwin-declarative
#     (auto-login requires an obfuscated kcpassword file that we
#     deliberately do not commit to the repo) — operator-side
#     System Settings choice, one-time per machine. The launchd
#     agent here covers both cases: with auto-login, colima starts
#     on every boot before any human input; without auto-login,
#     colima starts on the first GUI login post-boot. Documented
#     in docs/desktop/colima.md §Sharp edges.
#
# Docker context + DOCKER_HOST: colima registers a `colima` docker-CLI
# context on first start (sets it default), so the `docker` CLI resolves
# the daemon via that context. But SDK-based clients — notably lazydocker
# (ADR-006) — do NOT follow CLI contexts; they read DOCKER_HOST or fall
# back to /var/run/docker.sock, which colima doesn't populate. So we also
# export DOCKER_HOST to colima's socket in the operator's shell env
# (below). This is the Darwin parallel to the NixOS module's
# `setSocketVariable = true`; the only difference is the socket path
# (colima's per-user ~/.colima/default/docker.sock vs the rootless path).
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

  # launchd user agent — auto-starts colima on session load (per
  # the §"Daemon lifecycle" notes in the header). `colima start` is
  # fire-and-exit: it brings up the Lima VM and then returns, with
  # the VM persisting as a separate process. So RunAtLoad=true is
  # the load-bearing knob; KeepAlive=false means launchd doesn't
  # spam restarts after the start command exits successfully.
  #
  # Logs land at $HOME/Library/Logs/colima.{out,err}.log — standard
  # macOS user-log location; `colima logs` is the in-tool surface
  # for VM-side output once it's running, but the launchd agent's
  # own stdout/stderr from the `colima start` invocation goes here
  # for first-start debugging.
  #
  # Subsequent invocations of `colima start` when the VM is already
  # running are no-ops (colima reports "already running" and exits
  # 0), so this is safe to fire on every session load even if the
  # operator has already started colima manually that session.
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
  # context colima sets — see the "Docker context + DOCKER_HOST" note in
  # the header. Set as a home-manager session var so it's sourced by fish
  # and inherited by zellij panes (nix-darwin's environment.variables
  # doesn't reliably reach a GUI-launched fish). Keeps all colima wiring in
  # this module, parallel to the NixOS docker module owning its socket var.
  home-manager.users.${operator.name}.home.sessionVariables.DOCKER_HOST =
    "unix://${operator.darwinHome}/.colima/default/docker.sock";
}
