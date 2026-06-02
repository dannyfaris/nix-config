# colima — container runtime on Darwin

CLI/daemon, not a GUI tool. This doc lives alongside the
GUI per-tool docs in `docs/desktop/` for consistency, but
the operator-facing surface is the terminal, not a `.app`.

## Selection

Darwin: `pkgs.colima` + `pkgs.docker` + `pkgs.docker-compose`
via `modules/darwin/colima.nix`, imported by
`hosts/mac-mini/default.nix`. ADR-031's §Boundary rule
nixpkgs-by-default baseline applies directly — none of the
three clauses fires: `pkgs.colima` ships on `aarch64-darwin`
(clause 1 N/A); colima is a CLI/daemon with no
`/Applications/`-rooted bundle and no Sparkle auto-updater, so
the clause-2 shape that governs the GUI casks doesn't apply;
colima isn't on MAS (clause 3 N/A).

The colima-vs-Docker-Desktop-vs-OrbStack walk lives in
[ADR-021](../decisions/ADR-021-docker-on-headless.md) (amended
2026-06-03 to cover Darwin). Short version: colima is FOSS,
declarative, lightweight, and mirrors the rootless-Docker
mental model the Linux side adopted; Docker Desktop and OrbStack
both carry commercial-use licensing for company-funded work and
buy a GUI premium the operator wouldn't use (lazydocker is the
established TUI client per ADR-006).

## Workflow

**Auto-started via launchd.** `modules/darwin/colima.nix`
declares `launchd.user.agents.colima` with `RunAtLoad = true`,
firing `colima start` on GUI session establishment. The Lima VM
comes up automatically; daily use requires no manual start step.

The launchd agent fires when the user's `gui/<uid>` launchd
domain becomes active — i.e., on GUI login (keyboard + display)
or on macOS auto-login. **SSH into a freshly-rebooted Mac that
has not had a GUI login does NOT trigger the agent** — see
§Sharp edges for the operator-side mitigation.

**First use, one-time per machine** (overrides the launchd
auto-start's flag-less invocation):

```bash
colima start --cpu 4 --memory 4 --disk 100
```

Downloads the Lima base VM image (~250MB) and bootstraps the VM
(~30s). Default resources without flags are 2 CPU, 2GB RAM, 60GB
disk — usually too tight for real work envelopes, so pass flags
explicitly on the first start. The flags persist in
`~/.colima/default/colima.yaml`; subsequent flag-less starts
(including the launchd agent's) honour the saved envelope.

Verify after first start:

```bash
docker context ls       # `colima *` listed as current
colima status           # VM running, with current resource flags
docker run --rm hello-world
```

**Daily, after reboot:** nothing for keyboard logins — the
launchd agent handles `colima start` on the first GUI session
establishment. SSH-only access on a freshly-rebooted Mac that
hasn't had a GUI login yet finds colima not running; see
§Sharp edges for the auto-login mitigation.

**TUI client:** [lazydocker](https://github.com/jesseduffield/lazydocker)
is on `mac-mini` per [`home/shared/cli-utils.nix`](../../home/shared/cli-utils.nix);
just run `lazydocker` once colima is up.

**Stopping / pausing:**

```bash
colima stop             # stops the VM; containers stop with it
colima delete           # removes the VM entirely (rare; re-bootstrap on next start)
```

**Re-sizing the VM envelope after first start:**

```bash
colima stop && colima start --cpu N --memory N --disk N
```

Destroys nothing — the VM's disk persists. The new flags get
written into `colima.yaml` and become the new launchd-agent
defaults.

**Inspecting the launchd agent's own logs** (separate from
colima's runtime VM logs):

```bash
tail -f ~/Library/Logs/colima.out.log   # stdout from `colima start`
tail -f ~/Library/Logs/colima.err.log   # stderr from `colima start`
```

VM-side logs are reachable via `colima logs` once it's running.

## Configuration

**Module declaration** — `modules/darwin/colima.nix`:

```nix
environment.systemPackages = [
  pkgs.colima
  pkgs.docker
  pkgs.docker-compose
];

launchd.user.agents.colima = {
  serviceConfig = {
    ProgramArguments = [
      "${pkgs.colima}/bin/colima"
      "start"
    ];
    RunAtLoad = true;
    KeepAlive = false;
    StandardOutPath = "${operator.darwinHome}/Library/Logs/colima.out.log";
    StandardErrorPath = "${operator.darwinHome}/Library/Logs/colima.err.log";
  };
};
```

Colima's runtime config (resource flags, mount points, network
mode) is set imperatively via `colima start --<flag>` on first
use, persisted in `~/.colima/default/colima.yaml`. This is a
deliberate departure from the rest of the config's declarative-
first stance: colima's upstream config-file shape doesn't have a
stable declarative nix-darwin module wrapper today, and the
resource envelope rarely changes once dialled in. The launchd
agent runs `colima start` without flags, which honours whatever
is persisted in `colima.yaml`.

## Update behaviour

**nixpkgs flake bumps.** colima, docker, and docker-compose all
ship via nixpkgs; updates land on `nix flake update` + `nh
darwin switch`. No Sparkle, no MAS, no auto-update agent. Same
cadence as the rest of the nix-managed surface.

## Sharp edges

**launchd auto-start has a GUI-session dependency.** The
`launchd.user.agents.colima` definition fires when the user's
`gui/<uid>` launchd domain becomes active — that's GUI login
(keyboard + display) or macOS auto-login. **SSH alone does NOT
bootstrap the gui-domain.** Concretely:

| Scenario | Does colima auto-start? |
|---|---|
| You log into the Mac via keyboard/monitor at least once after boot | ✅ Yes, on that login + persists until reboot |
| macOS auto-login enabled in System Settings → Users & Groups | ✅ Yes, on every boot, before any human input |
| Mac reboots unattended (power cut, software update), no GUI login, you SSH in | ❌ No — the launchd user agent never fired; `docker` returns "Cannot connect" until someone logs in via GUI |

For "always-on after unattended reboot," enable macOS auto-login
in **System Settings → Users & Groups → Automatic login**. This
is intentionally not nix-darwin-declarative: auto-login requires
an obfuscated `/etc/kcpassword` file derived from the user's
login password, which would commit a secret-derived artifact to
the repo. **One-time operator action per machine, outside of
nix-darwin.** ADR-021's 2026-06-03 amendment names this decision
as operator-side; the launchd agent here works for both worlds
(auto-login on → colima up at boot; auto-login off → colima up
on first GUI login).

If you forget to enable auto-login and find colima not running
after an unattended reboot: log in via keyboard once. The agent
will fire and colima will come up. There's no "kick the agent
from SSH" shortcut on the same boot cycle — running `colima
start` manually in the SSH session works, but it won't fix the
GUI-domain state that launchd cares about for the NEXT boot.

**Docker context — not `DOCKER_HOST`.** colima registers a
docker context on first start and sets it as the default. The
`docker` CLI resolves to colima's socket via context, not via
the `DOCKER_HOST` env var. If you ever see `Cannot connect to
the Docker daemon`, check `docker context ls` first — if
something switched the current context away from `colima`,
`docker context use colima` restores it.

**Resource flags are first-start-sticky.** `colima start --cpu
4` on first start commits the VM to 4 CPUs in its `colima.yaml`;
subsequent bare `colima start` invocations honour that, no need
to re-pass flags. To change after the fact:
`colima stop && colima start --cpu 8`. The VM's disk persists
through stop/start.

**Linux-only kernel features are bounded by the Lima VM's kernel,
not the host.** Most workflows don't notice; some do (eBPF
programs targeting specific kernel versions, certain mount
types, host-kernel-version-specific behaviour). If a container
expects features the Lima VM's kernel doesn't have, that's the
likely culprit.

**`docker compose` vs `docker-compose` version drift.** Same
caveat as ADR-021 §Consequences names for the Linux side — the
subcommand form comes from the plugin bundled into `pkgs.docker`,
the standalone form from `pkgs.docker-compose`. Versions can
drift; usually harmless, occasionally surprising.

**First `colima start` takes ~30s and downloads ~250MB.** Not a
forever-cost, but worth knowing on a fresh machine. The same
holds after `colima delete` if you ever fully reset.

## References

- [ADR-021](../decisions/ADR-021-docker-on-headless.md) —
  container-runtime decision; Linux + Darwin (amended 2026-06-03).
- [ADR-006](../decisions/ADR-006-cli-utilities.md) — lazydocker
  as the universal TUI client; tool-vs-runtime split.
- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) —
  install-path boundary; colima lands under §Boundary rule's
  nixpkgs-by-default baseline (no clause fires for a CLI/daemon).
- colima upstream — https://github.com/abiosoft/colima
- lima (colima's VM backend) — https://github.com/lima-vm/lima
