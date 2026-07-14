# CI workflow — per-knob rationale

The operational companion to [ADR-025](./decisions/ADR-025-ci-in-flake.md). ADR-025 records the *decision* — CI is flake-defined, every check is a flake output, a thin GitHub Actions matrix runs `nix flake check`. This doc is the reading-guide to the resulting `.github/workflows/ci.yaml`: the per-knob *why* a maintainer wants when editing that file, without re-deriving it inline. Living doc — it tracks `ci.yaml` as runners, cache tuning, and action pins evolve, the way `docs/desktop/<tool>.md` tracks the desktop modules.

The split, so neither place restates the other: **ADR-025 owns the framework decision and the dated history** (the cache saga #218→#228, the macos-15 / Darwin-matrix addition, the SHA-pinning trigger). **This doc owns the standing operational mechanics** — the things you need to understand the file, not the story of how each was found. Where ADR-025 (or another ADR) owns the deeper rationale, this doc points rather than repeats. `ci.yaml` itself carries only a one-to-three-line "what breaks if you change this" at each knob plus a pointer here.

## Display name and branch protection

The job sets an explicit `name: flake-check (${{ matrix.arch }})`. This is load-bearing, not cosmetic. Branch protection on `main` requires specific status-check *names* (`flake-check (x86_64-linux)`, `flake-check (aarch64-linux)`, `flake-check (aarch64-darwin)`). Without the explicit `name:`, GitHub auto-generates the check name from *every* matrix dimension — including the `runner:` key introduced by the `include:` block — yielding e.g. `flake-check (x86_64-linux, ubuntu-24.04)`, which never matches the protection rule, so the gate silently never applies. Keep the `name:` and keep it keyed on `matrix.arch` alone.

The required-checks set is configured out-of-band on GitHub (a ruleset), recorded in ADR-025 §Implementation and its §History. It is the three `flake-check (<arch>)` contexts **plus `gitleaks`** — so a secret-leaking PR can no longer auto-merge green. The `gitleaks` context is the gitleaks job's explicit `name:`; keep that name stable, since the ruleset matches on it. Adding a required check is **order-sensitive**: push the workflow so a run reports the context *first*, then add it to the ruleset — a context required before any run has reported it shows as "Expected — waiting" and blocks every PR indefinitely. If you add or rename a matrix arch (or the gitleaks job), update the ruleset in the same change or the new check won't gate (and a renamed one will leave an unmatchable required check blocking every PR).

## Permissions

Pinned to the minimum (whitelist > blanket, per [CLAUDE.md](../CLAUDE.md)):

- `contents: read` — `actions/checkout` clones the repo; Nix fetches public flake inputs.
- `actions: write` — `cache-nix-action`'s `purge-primary-key: always` flow calls `DELETE /repos/.../actions/caches` to evict the existing entry before resaving. Without this scope the delete returns 403 and the resave is silently skipped, so the cache never refreshes. Also required for the post-save LRU sweep (`purge-prefixes`) to delete stale sibling entries.

The explicit pin matters because the GitHub default token grants more (`pull-requests: write`, `issues: write`, …) than this workflow needs. The dated story of how the missing `actions: write` scope surfaced is in ADR-025 §History (2026-06-04).

## Runners

The matrix pins concrete runner labels via `include:` rather than `*-latest`:

- `ubuntu-24.04` (x86_64-linux), `ubuntu-24.04-arm` (aarch64-linux), `macos-15` (aarch64-darwin).
- `macos-15` is pinned rather than `macos-latest` — the floating label moves under us (it migrated to macos-15 in Aug 2025), which would silently change the build environment. The choice of the standard label over the metered `-large` / `-xlarge` / `-intel` variants, and the billing reasoning behind it, are in ADR-025 §History (PR #218) — not repeated here.
- `aarch64-darwin` matches neptune's real arch — no Rosetta cross-arch surprises.

`nix flake check` on the macOS runner realises `flake.checks.aarch64-darwin.host-neptune` but does **not** run nix-darwin activation — no `brew bundle`, `mas install`, `launchctl load`, or admin prompts fire at build time. CI is therefore side-effect-free on Darwin. The decision to add the Darwin matrix entry, and its cold-cache cost history, are in ADR-025 §History (2026-06-04).

Actions are SHA-pinned with a trailing `# vN` comment; the rationale and the trigger that prompted it are in ADR-025 §History (2026-06-05). Refresh a pin when you want a newer release; the trailing tag comment is the human-readable anchor.

## Substituters

The installer (`cachix/install-nix-action`) gets `extra_nix_config`:

- `accept-flake-config = false` carries the whitelist-over-blanket stance from `modules/shared/nix-daemon.nix` into CI — a transitive input's `nixConfig` block can't silently add a substituter or change settings on the runner. ADR-025 §Rationale owns this decision.
- `niri.cachix.org` is whitelisted as a substituter + trusted key, mirroring `nix.settings` in `modules/nixos/niri.nix` (ADR-028 slice 3b.5). Without it CI's daemon won't trust the cache, niri builds from source, and the build hits an in-flight upstream nixpkgs Rust-crate-fetcher 403. The public key is the one niri-flake itself would have added via its default-on `cache.enable`; `niri.nix` is the single source for both the substituter URL and the key.
- Cross-arch note: `niri.cachix.org` serves x86_64-linux only. `nix flake check` builds every host, but only the x86_64 hosts import the niri module, so the substituter is only ever queried on the x86_64 matrix entry — harmless on the others.

## Private flake inputs

The flake takes `wiki-infra` (github:dannyfaris/wiki-infra, **private** — the wiki's deployment packaging; module shape governed in the wiki repo, its `docs/design/deployment-packaging.md`) as an input, and Nix fetches *all* inputs at eval, so every CI job that evals the flake must authenticate that fetch. The default `GITHUB_TOKEN` cannot: it is scoped to this repo alone and returns 404 on any other private repo (observed on PR #622's first run). Both nix-evaluating workflows therefore pass `github_access_token: ${{ secrets.GH_PAT_PRIVATE_INPUTS || secrets.GITHUB_TOKEN }}` to `install-nix-action`, which writes it as an `access-tokens` line in the runner's nix.conf.

`GH_PAT_PRIVATE_INPUTS` is a fine-grained PAT: repository access **only** the private input repos (today: `wiki-infra`), permissions **Contents: read-only** (metadata rides along). It is deliberately not `GH_PAT_FLAKE_LOCK` — that one is scoped to *this* repo with write permissions for PR-opening and grants nothing on the inputs; one token per job, each with the minimum its job needs (whitelist > blanket). The `|| GITHUB_TOKEN` fallback keeps forks and secret-less contexts at the old behavior. When a new private input lands, add it to this PAT's repository list — the failure mode is the same 404, now documented. Expiry note: fine-grained PATs expire; a sudden fleet-wide CI 404 on the input is the renewal signal.

## Cache

`cache-nix-action` provides `actions/cache`-shaped storage for build **outputs**. It is **not** a substituter and is orthogonal to the `niri.cachix.org` trust lines — it amortises the non-niri half of the desktop closure (Quickshell, Qt6, matugen, DMS, xwayland-satellite, foot, transitive deps) that a fresh runner would otherwise rebuild every cold run. It is a post-ADR-025 addition (under `#61`, an ADR-028 follow-up — ADR-025 §23 deferred the binary-cache question and CI v1 ran cache-less), not a foundational CI-v1 decision; the dated sizing/tuning history is in ADR-025 §History.

**Why this and not Cachix / FlakeHub / Attic.** Those are larger trust or operational delegations than a one-operator / few-host project warrants today (a substituter is a signing-key trust root; Attic is a service to run). `cache-nix-action` is plain `actions/cache` storage with no new trust root. Revisit only if hit-rate stays below ~60% over a month, or a second major source-built dependency lands (the `#61` "triggers to revisit").

**Key semantics.** The primary key is `nix-<os>-<arch>-<flake.lock hash>`, so a lockfile bump invalidates cleanly. PR branches restore from the `<os>-<arch>` prefix seeded on `main`; the squash-auto-merge flow reseeds after each PR lands.

**Size ceilings.** `gc-max-store-size-linux: 5G`, `gc-max-store-size-macos: 8G`. The Darwin closure is ~7.3 GiB at write-time, so 8G holds it with ~700 MB headroom; a lower ceiling forces eviction on save and warm-cache runs re-fetch the shortfall from `cache.nixos.org` every time. GitHub caps each repo's cache pool at 10 GB and LRU-evicts across it; the Linux closures sit well under their 5G ceiling, so the nominal 18 GB total is more headroom than it looks. The dated sizing history (5G under-provisioned → 8G) is in ADR-025 §History.

**`purge-primary-key: always`** is the non-obvious one. `cache-nix-action` wraps `actions/cache`'s "primary-key hit → save is a no-op" semantic. Without `always`, every run after the first hits the existing primary key and skips the save, so the original cache contents are cemented in the pool *even after the closure grows or the ceiling is raised*. With `always`, the action purges the primary key before the save-step's existence check, the lookup misses, GC runs against the current closure under the cap, and a fresh full cache is saved — each run refreshes its own key with no manual bump. This is the knob that needs `actions: write` (see §Permissions). Root-cause history: ADR-025 §History (#225).

## Retry

The `nix flake check` step wraps itself in a bounded retry (3 attempts, 30s backoff). Some eval-time fetches reach third-party forges — e.g. niri's pipewire-rs from gitlab.freedesktop.org via `builtins.fetchGit` — which are **not** covered by Nix's own `download-attempts` (that retries the HTTP downloader / binary-cache fetches, left at its default of 5). A transient blip on such a forge would otherwise red `main` for a non-issue.

The retry is **blind, not regex-gated**: an earlier version matched a 19-branch stderr signature to classify transient-vs-real, brittle both ways (it can mask a real failure whose log happens to match, and miss a transient signature it didn't enumerate). Per [ADR-032](./decisions/ADR-032-proportionate-enforcement-and-rationale.md) Rule 1 (proportionate enforcement) the lighter mechanism wins, and the cost is small: the Nix store persists across attempts within a job, so a retry re-runs only the failed derivation and its un-built dependents (an eval error re-evals in seconds), not the whole closure — and a real, deterministic error still goes red, just after the retries are spent. The step's `if`-wrapped `nix flake check` is exempt from the default `-e` errexit because GitHub's `run:` shell is `bash --noprofile --norc -eo pipefail` (a failing command in an `if` condition doesn't trip errexit).

## Timeouts

Every job sets `timeout-minutes` — a wall-time backstop on a hung leg, not a budget. GitHub's default is 360 minutes per job; with `ci.yaml`'s deliberate 3× blind retry (§Retry) a wedged `nix flake check` could otherwise burn ~18 runner-hours before GitHub killed it. The caps are sized generously over observed worst-case so a slow-but-healthy run never trips them:

- `flake-check`: **60 min**. Warm-cache runs land in ~11–13 min, but a cold cache (a lockfile bump invalidates the key) can force a ~30–40 min Darwin closure rebuild — ADR-025 §History records a 38m53s cold first run — and the 3× blind retry can stack attempts on top. 60 min clears that with headroom.
- `gitleaks`: **10 min** (incremental scans finish in seconds).
- `flake-lock` bump: **15 min** (`nix flake update` + PR open is quick).

A job that hits its cap fails the run, which — for `flake-check` and `gitleaks`, both required — blocks the merge, the same as any other red check.

## Sibling workflows

`.github/workflows/flake-lock.yaml` (weekly lockfile bump → PR) and `.github/workflows/gitleaks.yaml` (incremental secrets scan) are decided in ADR-025 §Decision / §Rationale (cadence, manual-merge, the fine-grained PAT). `gitleaks` is now also a **required** check (see §"Display name and branch protection") and scopes its `push:` trigger to `main` so a PR branch isn't scanned twice (push + pull_request); its wall-time cap is in §Timeouts. Beyond those knobs they stay stable enough not to need a per-knob companion section here — if they grow further operational subtleties, they get their own sections rather than inline essays.

## References

- [ADR-025](./decisions/ADR-025-ci-in-flake.md) — the framework decision and the dated history this doc points back to.
- [ADR-028](./decisions/ADR-028-stylix-foundation-and-desktop-env.md) — desktop closure + the niri cache (slice 3b.5); `modules/nixos/niri.nix` is the single source for the niri substituter + key.
- [ADR-032](./decisions/ADR-032-proportionate-enforcement-and-rationale.md) — proportionate enforcement (the blind-retry choice) and single-sourced rationale (why this doc points rather than restates).
