# ADR-021: Docker on headless hosts — rootless daemon, system-wide CLI, per-host opt-in

**Date**: 2026-05-18
**Status**: Accepted

## Context

[ADR-006](./ADR-006-cli-utilities.md) § "Tool-vs-runtime split" deliberately deferred the docker daemon decision: lazydocker landed in the home tier as the universal client UI, the docker CLI was scoped to per-project devShells (consistent with the per-project toolchain pattern in [ADR-003](./ADR-003-direnv.md)), and the daemon was left as "a deployment decision deferred until the first project needs it."

Mercury ([ADR-017](./ADR-017-headless-bootstrap-aws-ami.md)) is the first concrete host where running containers locally is a real workflow requirement — a work-only dev box where projects routinely involve `docker compose up`-style local development. That triggers ADR-006's deferral.

Three options were on the table for the daemon: rootful Docker (the historical default — `virtualisation.docker.enable`), rootless Docker (`virtualisation.docker.rootless.enable`), or Podman with docker-socket compatibility. Two questions came alongside: where the docker CLI lives (per-project devShells per ADR-006, or system-wide on this host), and whether the docker module belongs in the headless role or as a per-host import.

## Decision

**Rootless Docker** on hosts that need containers. Enabled via `virtualisation.docker.rootless.enable = true` + `setSocketVariable = true`, with `dbf`'s subUid/subGid ranges declared explicitly in the same module and systemd lingering enabled so the user-mode daemon survives session disconnects.

**System-wide CLI on those hosts.** `pkgs.docker` is auto-installed by the rootless module and ships with `composeSupport = true` at the pinned nixpkgs revision — the docker binary is wrapped with `DOCKER_CLI_PLUGIN_DIRS` pointing at the compose plugin bundled into the same derivation, so `docker compose` works from `pkgs.docker` alone. `pkgs.docker-compose` is added explicitly on top to expose the standalone `docker-compose` binary for scripts and tooling that invoke the hyphenated form directly. This deviates from ADR-006's per-project devShells stance specifically for hosts running containers; ADR-006's reasoning was conditional on "no daemon yet, so devShells let each project pin its own CLI version" — once the daemon exists, the cost of devShell-only CLI exceeds the version-pinning benefit on a single-user dev box.

**Per-host opt-in via direct import**, not via the role. `modules/core/nixos/docker.nix` is imported by `hosts/mercury/default.nix` directly; `roles/headless.nix` does not include it. The UTM VM doesn't run containers; pulling Docker into its closure for nothing would waste bandwidth, store space, and rebuild time. Future headless hosts that need Docker import the same module from their own host files. This is the same shape as the work-vs-personal import splits in [ADR-020](./ADR-020-role-overlap-via-import-splits.md).

## Rationale

**Rootless over rootful.** The `docker` group is effectively root-equivalent — any member can mount the host root and exfiltrate or escalate. On a dev box that's an acceptable tradeoff for many users, but rootless avoids the tradeoff entirely: the daemon runs as `dbf`, containers can't escape that user's privileges, and the docker group simply doesn't exist. The cost is concrete and known: privileged-port binds (`--publish 80:80`), host-network containers (`--network=host` mostly works rootless, but with caveats), and a few esoteric kernel features (binfmt registration without sudo, etc.) need workarounds. None of those are load-bearing for the workflows Mercury exists to support; they can be revisited if a real project hits them.

**Podman rejected** for this slice despite its security model being comparable. Podman's daemonless design is genuinely interesting, but tooling that probes for "real Docker" (commercial CI runners, some `docker compose` features, IDE integrations) can surface confusing failure modes when it hits Podman's docker-socket shim. On a work box where the dev environment should behave like other work setups, that surface-area uncertainty isn't worth the architectural elegance.

**System-wide CLI over devShell-only on Mercury.** The per-project devShells pattern in ADR-006 was rationalised in a context where (a) no daemon existed locally, so the CLI was only useful when paired with a remote `DOCKER_HOST`, and (b) projects might pin different docker CLI versions. (b) is rare in practice on this user's workflows — the Docker API is stable enough that one CLI version usually serves every project. (a) was the bigger constraint, and it disappears once the daemon is local. Having `docker` and `docker-compose` on PATH outside any devShell is straightforwardly more convenient.

**Per-host import over role import.** PRD §3.2's rule ("choice between alternatives = choice of which module to import") and ADR-020's extension of that to host-level divergences fit cleanly here. Docker is not a role-level requirement of `headless`; it's a per-host workload choice. Hosts that want it import it; hosts that don't, don't. Closure on the VM is unchanged because the module is never reached.

**Subuid/subgid declared explicitly.** The NixOS rootless docker module does not auto-configure subordinate UIDs (verified against the pinned nixpkgs revision). Without subUidRanges/subGidRanges, `newuidmap`/`newgidmap` fail and containers can't start. Declaring `100000-165535` in the docker module itself (rather than in `users.nix`) keeps the subordinate-UID setup co-located with what needs it; the VM doesn't import the module, so its `/etc/subuid` stays empty.

**Lingering enabled.** `users.users.dbf.linger = true;` makes systemd-logind treat dbf as having a persistent user session, so the user-mode dockerd starts at boot and runs whether or not dbf is logged in. Without it, background containers stop the moment the last SSH/mosh session closes — fine for foreground use, surprising for anything long-running.

## Consequences

- ✓ `dbf` is not in the `docker` group; no root-equivalent privilege required to use containers.
- ✓ The user-mode docker daemon survives session disconnects (via lingering), so long-running containers behave the way the user expects.
- ✓ The VM's closure is unaffected — Docker is genuinely Mercury-only, not behind a host-keyed `mkIf` somewhere.
- ✓ ADR-006's deferred daemon decision is closed; future readers see this ADR rather than a still-open question.
- ✗ Rootless containers can't bind privileged ports (<1024) without setting net.ipv4.ip_unprivileged_port_start or using a workaround. For typical dev workflows (services on 8080, 5432, etc.) this is irrelevant; some `docker compose` files that publish to port 80 or 443 will need port-mapping changes.
- ✗ Host-network mode (`--network=host`) has quirks under rootless — the container sees the user's network namespace, not the host's true namespace. Most workflows don't notice; some do.
- ✗ Subuid/subgid ranges are declared per-host that imports the module, hard-coded as 100000-165535. If two future headless hosts ever need to share container state via a bind-mounted filesystem, the matching ranges would be load-bearing. Not a current scenario.
- ⚠ Migration trigger: a real project that requires privileged ports, host network, or some other rootless-incompatible feature. The migration is to flip the same module to rootful (or to introduce a sibling `docker-rootful.nix`); existing containers keep running through the switch because the storage layout is compatible.
- ✗ Rootless container resource limits (`--memory`, `--cpus`) require cgroup v2. NixOS at recent revisions defaults to cgroup v2 and the official AWS AMIs follow suit, so this is typically a non-issue. If resource limits start mysteriously failing post-bootstrap, `cat /sys/fs/cgroup/cgroup.controllers` is the diagnostic — empty or missing `memory`/`cpu` means cgroup v1 fallback is in effect.
- ✗ `docker compose` (subcommand) and `docker-compose` (standalone) come from different derivations — the subcommand from the plugin bundled into `pkgs.docker`, the standalone from `pkgs.docker-compose`. They can drift in version between nixpkgs updates. `docker compose version` and `docker-compose --version` may report different numbers; usually harmless but worth knowing when a feature works in one and not the other.
- ⚠ Migration trigger: a future workflow that hits the `docker compose`-subcommand-vs-`docker-compose`-standalone distinction in surprising ways. If the bundled compose plugin diverges materially from the standalone, dropping `pkgs.docker-compose` and standardising on the subcommand form is the obvious patch.

## Implementation

- `modules/core/nixos/docker.nix` — the module itself: enables rootless docker, sets `setSocketVariable`, declares dbf's subUid/subGid ranges (100000-165535), enables systemd lingering, and adds `pkgs.docker-compose` to `environment.systemPackages`. The docker CLI is auto-added by the rootless module so isn't listed explicitly.
- `hosts/mercury/default.nix` — imports the module directly. The VM's host file does not.
- ADR-006 (CLI utilities) is updated to mark its deferred decision resolved by this ADR; ADR-006's per-project devShell stance for docker is preserved as the default for hosts that don't import the daemon module.

First-use verification on Mercury after the bootstrap is in `docs/runbooks/headless-bootstrap.md` § Verification: `docker run --rm hello-world` should succeed as `dbf` without any sudo invocation, and `systemctl --user status docker` should show the rootless daemon active.
