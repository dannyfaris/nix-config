# ADR-021: Container runtime on hosts that need containers — rootless Docker on Linux, colima on Darwin, per-host opt-in

**Date**: 2026-05-18
**Status**: Accepted (amended 2026-06-03 — see §History)

> **Revision (2026-06-05):** stale module paths in this ADR were swept to the
> current flat layout (`home/core/…` → `home/…`, `modules/core/…` → `modules/…`)
> per [ADR-026](./ADR-026-drop-core-tier-prefix.md), which dropped the `core/`
> tier prefix. Navigability fix only — the decision recorded here is unchanged.

## Context

[ADR-006](./ADR-006-cli-utilities.md) § "Tool-vs-runtime split" deliberately deferred the docker daemon decision: lazydocker landed in the home tier as the universal client UI, the docker CLI was scoped to per-project devShells (consistent with the per-project toolchain pattern in [ADR-003](./ADR-003-direnv.md)), and the daemon was left as "a deployment decision deferred until the first project needs it."

Mercury ([ADR-017](./ADR-017-headless-bootstrap-aws-ami.md)) is the first concrete host where running containers locally is a real workflow requirement — a work-only dev box where projects routinely involve `docker compose up`-style local development. That triggers ADR-006's deferral.

Three options were on the table for the daemon on NixOS: rootful Docker (the historical default — `virtualisation.docker.enable`), rootless Docker (`virtualisation.docker.rootless.enable`), or Podman with docker-socket compatibility. Two questions came alongside: where the docker CLI lives (per-project devShells per ADR-006, or system-wide on this host), and whether the docker module belongs in the headless role or as a per-host import.

**Darwin extension (2026-06-03 amendment).** mac-mini's onboarding (2026-06-02) brought container workloads to the Darwin side of the fleet for the first time. macOS has no native Linux container runtime — every option runs a Linux VM under the hood (Apple Virtualization.framework or HyperKit). Three options on the Darwin side: **Docker Desktop** (Docker Inc.'s proprietary commercial product), **OrbStack** (proprietary native macOS app from OrbStack Inc.), or **colima** (FOSS Lima-VM-backed daemon). License-cost, footprint, and fit-with-the-Linux-side mental model all weighed in.

## Decision

**Rootless Docker** on hosts that need containers. Enabled via `virtualisation.docker.rootless.enable = true` + `setSocketVariable = true`, with `dbf`'s subUid/subGid ranges declared explicitly in the same module and systemd lingering enabled so the user-mode daemon survives session disconnects.

**System-wide CLI on those hosts.** `pkgs.docker` is auto-installed by the rootless module and ships with `composeSupport = true` at the pinned nixpkgs revision — the docker binary is wrapped with `DOCKER_CLI_PLUGIN_DIRS` pointing at the compose plugin bundled into the same derivation, so `docker compose` works from `pkgs.docker` alone. `pkgs.docker-compose` is added explicitly on top to expose the standalone `docker-compose` binary for scripts and tooling that invoke the hyphenated form directly. This deviates from ADR-006's per-project devShells stance specifically for hosts running containers; ADR-006's reasoning was conditional on "no daemon yet, so devShells let each project pin its own CLI version" — once the daemon exists, the cost of devShell-only CLI exceeds the version-pinning benefit on a single-user dev box.

**Per-host opt-in via direct import**, not via the role. `modules/nixos/docker.nix` is imported by `hosts/mercury/default.nix` directly; `roles/headless.nix` does not include it. The UTM VM doesn't run containers; pulling Docker into its closure for nothing would waste bandwidth, store space, and rebuild time. Future headless hosts that need Docker import the same module from their own host files. This is the same shape as the work-vs-personal import splits in [ADR-020](./ADR-020-role-overlap-via-import-splits.md).

**Darwin: colima** as the Linux-side equivalent on hosts that need containers (mac-mini today; any future Mac that runs containers). Same per-host opt-in pattern via direct module import (`modules/darwin/colima.nix`), same system-wide CLI stance (`pkgs.docker` + `pkgs.docker-compose` on PATH alongside `pkgs.colima` itself), same deviation-from-ADR-006 reasoning. **Daemon auto-started via a `launchd.user.agents.colima` definition** — Darwin equivalent of `linger = true` on the Linux side, ensuring colima is up and ready whether the operator is at the keyboard or accessing the host remotely. The lifecycle mechanism differs from Linux (launchd user agent runs `colima start` at session load; that command brings up the Lima VM and exits, with the VM persisting as a separate process), but the *posture* — daemon always-on, no operator action required per session — matches.

## Rationale

**Rootless over rootful.** The `docker` group is effectively root-equivalent — any member can mount the host root and exfiltrate or escalate. On a dev box that's an acceptable tradeoff for many users, but rootless avoids the tradeoff entirely: the daemon runs as `dbf`, containers can't escape that user's privileges, and the docker group simply doesn't exist. The cost is concrete and known: privileged-port binds (`--publish 80:80`), host-network containers (`--network=host` mostly works rootless, but with caveats), and a few esoteric kernel features (binfmt registration without sudo, etc.) need workarounds. None of those are load-bearing for the workflows Mercury exists to support; they can be revisited if a real project hits them.

**Podman rejected** for this slice despite its security model being comparable. Podman's daemonless design is genuinely interesting, but tooling that probes for "real Docker" (commercial CI runners, some `docker compose` features, IDE integrations) can surface confusing failure modes when it hits Podman's docker-socket shim. On a work box where the dev environment should behave like other work setups, that surface-area uncertainty isn't worth the architectural elegance.

**System-wide CLI over devShell-only on Mercury.** The per-project devShells pattern in ADR-006 was rationalised in a context where (a) no daemon existed locally, so the CLI was only useful when paired with a remote `DOCKER_HOST`, and (b) projects might pin different docker CLI versions. (b) is rare in practice on this user's workflows — the Docker API is stable enough that one CLI version usually serves every project. (a) was the bigger constraint, and it disappears once the daemon is local. Having `docker` and `docker-compose` on PATH outside any devShell is straightforwardly more convenient.

**Per-host import over role import.** PRD §3.2's rule ("choice between alternatives = choice of which module to import") and ADR-020's extension of that to host-level divergences fit cleanly here. Docker is not a role-level requirement of `headless`; it's a per-host workload choice. Hosts that want it import it; hosts that don't, don't. Closure on the VM is unchanged because the module is never reached.

**Subuid/subgid declared explicitly.** The NixOS rootless docker module does not auto-configure subordinate UIDs (verified against the pinned nixpkgs revision). Without subUidRanges/subGidRanges, `newuidmap`/`newgidmap` fail and containers can't start. Declaring `100000-165535` in the docker module itself (rather than in `users.nix`) keeps the subordinate-UID setup co-located with what needs it; the VM doesn't import the module, so its `/etc/subuid` stays empty.

**Lingering enabled.** `users.users.dbf.linger = true;` makes systemd-logind treat dbf as having a persistent user session, so the user-mode dockerd starts at boot and runs whether or not dbf is logged in. Without it, background containers stop the moment the last SSH/mosh session closes — fine for foreground use, surprising for anything long-running.

### Darwin-specific rationale (2026-06-03 amendment)

**colima over Docker Desktop.** Docker Desktop is the historical default and the most familiar option, but the cost surface is heavy on every axis that matters here. License-wise, the paid subscription is required for company-funded use at any employer with >250 employees or >$10M revenue; that's a non-trivial cost to absorb (or a non-trivial compliance liability to ignore) for a tool whose functional surface is replicated by free alternatives. Footprint-wise, Docker Desktop is the heaviest of the three options (~1–2GB RAM idle, slow start, multi-hundred-MB `.app`). Architecturally, it diverges from the daemon-as-service mental model the Linux side adopted — Docker Desktop's GUI dashboard, marketplace, and lifecycle controls don't have a counterpart on the rootless-Docker NixOS hosts, and the operator's established TUI workflow (lazydocker per [ADR-006](./ADR-006-cli-utilities.md)) makes the GUI premium wasted spend.

**colima over OrbStack.** OrbStack is the best non-FOSS option — genuinely lighter than Docker Desktop, polished native macOS app, similar feature surface — and would be the recommendation if licensing weren't a concern. But it carries a similar commercial-use license requirement (~$96/seat/year) and pays for a GUI premium the operator doesn't use day-to-day (same lazydocker-already-established reasoning as the Docker Desktop case). The marginal advantage of OrbStack over colima is the GUI; without that, colima wins on FOSS, declarative install, and cross-platform mental-model parity.

**colima over Homebrew cask install of itself.** `pkgs.colima` is available cleanly on `aarch64-darwin` and `x86_64-darwin`; colima is a CLI/daemon (no `.app` bundle, no Sparkle auto-updater), so the clause-2 carve-out shape that governs the GUI casks under [ADR-031](./ADR-031-nix-homebrew-boundary.md) does not apply. ADR-031 Step 1 (nixpkgs default) lands cleanly. Homebrew's `colima` formula exists but offers nothing the nixpkgs path doesn't already deliver, and installing via nixpkgs keeps the version bump under the same flake-update cadence as the rest of the system.

**launchd auto-start, with a GUI-session caveat.** The Linux side uses `linger = true` to keep the rootless daemon alive across session disconnects. The Darwin parallel is `launchd.user.agents.colima` with `RunAtLoad = true` running `colima start` at session establishment. `colima start` is fire-and-exit (brings up the Lima VM, returns); the VM persists as a separate process, so `KeepAlive = false` avoids spamming restarts after a successful start. Subsequent invocations when colima is already running are idempotent no-ops, so the agent is safe to fire on every session load.

The honest caveat: macOS `launchd.user.agents` fire when the user's `gui/<uid>` launchd domain becomes active — established by GUI login (keyboard + display) or by macOS auto-login. **SSH alone does NOT bootstrap the gui-domain.** SSH into a Mac that has not had a GUI login since boot will find colima NOT running, despite the agent being declared.

For "always-on after unattended reboot without anyone at the keyboard," the operator needs **macOS auto-login** enabled (System Settings → Users & Groups → Automatic login). That toggle is intentionally not nix-darwin-declarative — auto-login requires an obfuscated `/etc/kcpassword` file derived from the user's login password, which would commit a secret-derived artifact to the repo. The decision lives operator-side, as a one-time per-machine System Settings choice. The launchd agent here covers both worlds: with auto-login, colima starts on every boot before any human input; without auto-login, colima starts on the first GUI login post-boot and persists until reboot. The per-tool doc records both states honestly.

**System-wide CLI on Darwin.** Same reasoning as the Linux side: once the daemon exists locally, the cost of devShell-only CLI exceeds the version-pinning benefit. `pkgs.docker` + `pkgs.docker-compose` land in `environment.systemPackages` on hosts that import the colima module, mirroring the rootless-docker module's behaviour on NixOS.

**No `DOCKER_HOST` env-var override.** The Linux module sets `setSocketVariable = true` to point the docker CLI at `unix:///run/user/$UID/docker.sock`. The Darwin path uses a different mechanism: colima registers a `colima` docker context on first `colima start` and sets it as the default; `docker` then resolves to colima's socket via context, not via `DOCKER_HOST`. This is the upstream-supported path and doesn't need declarative override.

## Consequences

- ✓ `dbf` is not in the `docker` group; no root-equivalent privilege required to use containers.
- ✓ The user-mode docker daemon survives session disconnects (via lingering), so long-running containers behave the way the user expects.
- ✓ The VM's closure is unaffected — Docker is genuinely Mercury-only, not behind a host-keyed `mkIf` somewhere.
- ✓ ADR-006's deferred daemon decision is closed; future readers see this ADR rather than a still-open question.
- ✗ Rootless containers can't bind privileged ports (<1024) without setting net.ipv4.ip_unprivileged_port_start or using a workaround. For typical dev workflows (services on 8080, 5432, etc.) this is irrelevant; some `docker compose` files that publish to port 80 or 443 will need port-mapping changes.
- ✗ Host-network mode (`--network=host`) has quirks under rootless — the container sees the user's network namespace, not the host's true namespace. Most workflows don't notice; some do.
- ✗ Subuid/subgid ranges are declared per-host that imports the module, hard-coded as 100000-165535. If two future headless hosts ever need to share container state via a bind-mounted filesystem, the matching ranges would be load-bearing. Not a current scenario.
- ⚠ Linux migration trigger 1: a real project that requires privileged ports, host network, or some other rootless-incompatible feature. The migration is to flip the same module to rootful (or to introduce a sibling `docker-rootful.nix`); existing containers keep running through the switch because the storage layout is compatible.
- ✗ Rootless container resource limits (`--memory`, `--cpus`) require cgroup v2. NixOS at recent revisions defaults to cgroup v2 and the official AWS AMIs follow suit, so this is typically a non-issue. If resource limits start mysteriously failing post-bootstrap, `cat /sys/fs/cgroup/cgroup.controllers` is the diagnostic — empty or missing `memory`/`cpu` means cgroup v1 fallback is in effect.
- ✗ `docker compose` (subcommand) and `docker-compose` (standalone) come from different derivations — the subcommand from the plugin bundled into `pkgs.docker`, the standalone from `pkgs.docker-compose`. They can drift in version between nixpkgs updates. `docker compose version` and `docker-compose --version` may report different numbers; usually harmless but worth knowing when a feature works in one and not the other.
- ⚠ Linux migration trigger 2: a future workflow that hits the `docker compose`-subcommand-vs-`docker-compose`-standalone distinction in surprising ways. If the bundled compose plugin diverges materially from the standalone, dropping `pkgs.docker-compose` and standardising on the subcommand form is the obvious patch.

**Darwin-specific (2026-06-03 amendment):**

- ✓ Cross-platform mental-model parity: `docker` and `docker-compose` are on PATH on every host that runs containers, talking to a daemon owned by `dbf` (rootless dockerd on Linux, colima's Lima VM on Darwin). lazydocker continues to work uniformly as the TUI client.
- ✓ FOSS-only — no commercial-use license question to track, no employer-revenue threshold to monitor, no future price-hike risk on a critical-path tool.
- ✓ Declarative install via nixpkgs: bump cadence matches the rest of the system, no out-of-band brew/manual update step.
- ✓ Auto-started via `launchd.user.agents.colima` — `colima start` fires on GUI session establishment; the Lima VM comes back with its previously-saved resource flags. Operator doesn't need to remember to start the daemon. Equivalent to `linger = true`'s effect on the Linux side.
- ✗ The launchd user agent fires only when the GUI session is established (macOS `gui/<uid>` domain). After an unattended reboot with no GUI login, colima will NOT be running until someone logs in via keyboard+display — or until macOS auto-login is enabled (operator-side System Settings toggle, not declarative; see §Rationale above). For a Mac mini accessed primarily remotely, the operator's pragmatic answer is usually: enable auto-login. Documented in `docs/desktop/colima.md` §Sharp edges as a flagged-but-not-blocking caveat.
- ✗ First `colima start` downloads ~250MB Lima base image and bootstraps a VM (~30s). One-time cost per host; the launchd agent surfaces it as a brief delay on first GUI login post-activation.
- ✗ Resource limits on the Linux VM are colima-config-side, not host-side: `colima start --cpu 4 --memory 4 --disk 100` for the operator's typical work envelope. Defaults (2 CPU, 2GB RAM, 60GB disk) may be too small for heavier workloads. The launchd agent runs `colima start` without flags — the operator's first manual `colima start --cpu N --memory N --disk N` sets the persisted flags in `~/.colima/default/colima.yaml`, after which subsequent flag-less starts (including launchd's) honour the saved envelope.
- ✗ Linux-only kernel features inside containers (eBPF, certain mount types, host-kernel-version-specific behaviour) are bounded by the Lima VM's kernel version, not the macOS host. Usually fine; surfaces when an image expects exact kernel features.
- ⚠ Darwin migration trigger 1: a real workflow that hits Lima-VM-specific limits the operator can't work around with `--cpu`/`--memory`/`--disk` flags, OR a hard requirement for Docker Desktop's GUI/marketplace/Kubernetes-UI surface. The migration is to flip the module to install the `docker-desktop` cask instead (clause-2 carve-out under ADR-031, with the license-cost question revisited at that time).
- ⚠ Darwin migration trigger 2: a future Mac host with a different workload profile (e.g., GUI-driven container management, Kubernetes-on-Mac demos for stakeholders). At that point the colima-vs-OrbStack tradeoff gets reopened — OrbStack's GUI may earn its license cost on a host where the GUI is load-bearing.

## Implementation

**Linux side (original):**

- `modules/nixos/docker.nix` — the module itself: enables rootless docker, sets `setSocketVariable`, declares dbf's subUid/subGid ranges (100000-165535), enables systemd lingering, and adds `pkgs.docker-compose` to `environment.systemPackages`. The docker CLI is auto-added by the rootless module so isn't listed explicitly.
- `hosts/mercury/default.nix` and `hosts/metis/default.nix` — import the module directly. The VM's host file does not.
- ADR-006 (CLI utilities) is updated to mark its deferred decision resolved by this ADR; ADR-006's per-project devShell stance for docker is preserved as the default for hosts that don't import the daemon module.

First-use verification on Mercury after the bootstrap is in `docs/runbooks/headless-bootstrap.md` § Verification: `docker run --rm hello-world` should succeed as `dbf` without any sudo invocation, and `systemctl --user status docker` should show the rootless daemon active.

**Darwin side (2026-06-03 amendment):**

- `modules/darwin/colima.nix` — the module itself: adds `pkgs.colima` + `pkgs.docker` + `pkgs.docker-compose` to `environment.systemPackages`, and declares `launchd.user.agents.colima` (RunAtLoad=true, KeepAlive=false, ProgramArguments running `${pkgs.colima}/bin/colima start`, stdout/stderr to `~/Library/Logs/colima.{out,err}.log`). No `DOCKER_HOST` override (colima registers a docker context instead).
- `hosts/mac-mini/default.nix` — imports the module directly. Any future Mac that runs containers imports the same module from its own host file.
- Per-tool doc at `docs/desktop/colima.md` covers the operator-facing surface (first-use `colima start`, resource flags, lazydocker pairing, `docker context` interaction).

First-use verification on mac-mini: `colima start` (one-time bootstrap), then `docker run --rm hello-world` should succeed without sudo; `colima status` should show the VM running; `docker context ls` should list `colima` as the current context.

## History

### Darwin coverage added — colima on mac-mini (2026-06-03)

The original ADR was scoped to NixOS — its title named "headless hosts," its rationale was structured around `virtualisation.docker.rootless`, and Darwin was not in the fleet at write-time. mac-mini's onboarding on 2026-06-02 brought container workloads to the Darwin side for the first time, triggering the same "first project needs it" deferral that ADR-006 originally tracked — now on a second platform.

Three options were on the table for the Darwin runtime: Docker Desktop, OrbStack, colima. Walking the criteria (license-cost for company-funded work use, footprint, GUI-vs-CLI fit with the operator's established lazydocker workflow, parity with the Linux-side mental model, FOSS-vs-proprietary), colima is the cleanest fit on every axis except GUI feature parity — which the operator does not use anyway. Docker Desktop loses on every axis; OrbStack would win if licensing weren't a concern, but it isn't worth the ~$96/seat/year for a GUI premium the operator wouldn't exercise.

The amendment widens the ADR's scope from "Docker on headless hosts" to "Container runtime on hosts that need containers — rootless Docker on Linux, colima on Darwin." The Linux decision is unchanged; the Darwin decision lands alongside, sharing the same per-host-opt-in pattern, system-wide CLI stance, operator-only daemon ownership, and always-on posture. The lifecycle mechanism differs (Linux uses `linger = true` to keep the rootless daemon alive across session disconnects; Darwin uses a `launchd.user.agents.colima` definition with `RunAtLoad = true` to fire `colima start` on GUI session establishment), but the *posture* matches: daemon up by default, no per-session operator action required. The honest caveat that macOS user agents need a GUI session (and therefore that "always-on after unattended reboot" requires the operator-side System Settings auto-login toggle) is captured in §Rationale and §Consequences here, and in `docs/desktop/colima.md` §Sharp edges.

Pre-existing path correction: the original ADR referenced `modules/core/nixos/docker.nix` in §Decision and §Implementation. The `core/` tier was retracted by [ADR-026](./ADR-026-drop-core-tier-prefix.md); the canonical path is `modules/nixos/docker.nix`. The stale references were updated in the same amendment edit.

Files touched: `docs/decisions/ADR-021-docker-on-headless.md` (this file), `modules/darwin/colima.nix` (new), `hosts/mac-mini/default.nix` (import), `docs/desktop/colima.md` (new per-tool doc), `docs/desktop/README.md` (index row).
