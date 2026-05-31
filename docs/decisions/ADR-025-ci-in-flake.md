# ADR-025: Continuous integration in the flake

**Date**: 2026-05-26
**Status**: Accepted

## Context

Until now, CI has been informal: the operator runs `nh os switch` locally on each host; a single hand-rolled `pre-commit` hook in `.githooks/` enforces ADR-023's "do not hand-edit `hardware-configuration.nix`" rule; nothing else is automated. Three forces motivate formalising this.

**The host count has tripled.** When the repo had one host (nixos-vm), local rebuild was sufficient gating — if it broke, the operator noticed immediately on the only machine that mattered. With Mercury (AWS, x86_64) and Metis (bare metal, x86_64) now in the role, no single pre-flight rebuild covers all targets. A bumped flake input that builds clean on the VM may break Mercury's `amazon-image` integration or Metis's btrfs disko layout; without per-host gating, the discovery moment becomes `nh os switch` on the broken host — by then the broken commit is on `main`.

**The lockfile is going to drift.** ADR-022's flake adopted two new inputs (`nixos-anywhere`, `disko`) on top of the existing five. None receive deliberate bumps today. The longer drift continues, the larger the eventual catch-up bump and the harder it is to attribute breakage to a specific upstream change.

**The current enforcement mechanism is single-source-of-truth in name only.** ADR-023 declared the "`hardware-configuration.nix` must be auto-generated" rule and identified a pre-commit hook as the planned enforcement (Consequences §3) but left it out of scope. The hook was subsequently implemented as a bash script in `.githooks/pre-commit`, installed via `just install-hooks` (an imperative recipe that mutates `core.hooksPath`), and never folded back into ADR-023's Implementation section. The script is not run in CI; nothing prevents a contributor — including future-AI sessions — from pushing without it installed. The `.githooks/` directory and the imperative install step together violate the declarative-over-imperative stance from `docs/philosophy.md` for what is, ultimately, a check.

This ADR formalises CI as a first-class part of the flake: every check is defined as a flake output, CI is a thin GitHub Actions matrix that runs `nix flake check`, and the imperative `.githooks/` apparatus is replaced by `git-hooks.nix` installed automatically by the devShell.

The binary cache question — Cachix vs attic vs self-hosted — is deliberately deferred to a separate ADR-026. It is a trust-root decision (who can sign our store paths, where keys live) with consequences for host configuration that don't touch CI mechanics. CI v1 runs without a cache beyond the default `cache.nixos.org`; ADR-026 will add a substituter step without other structural change.

## Decision

Adopt **flake-defined CI**, with three new flake-parts modules and three GitHub Actions workflows.

- **`parts/checks.nix`** — imports `git-hooks.nix`'s flake module; exposes per-host `system.build.toplevel` derivations under `checks.<system>.host-<name>`, scoped via `lib.optionalAttrs` to the system that can build them (nixos-vm under `aarch64-linux`, mercury and metis under `x86_64-linux`). Hooks: nixfmt, statix, deadnix, actionlint, plus the migrated `hardware-config-banner` hook.
- **`parts/formatter.nix`** — imports `treefmt-nix`'s flake module; programs enabled are nixfmt and shfmt. `nix fmt` formats; `nix flake check` verifies.
- **`parts/dev-shells.nix`** — exposes `devShells.default` containing the operator's nix/sops tooling, with `git-hooks.nix`'s `installationScript` wired into `shellHook` so `nix develop` auto-installs `.git/hooks/pre-commit`.
- **`.github/workflows/ci.yaml`** — matrix on `{ubuntu-24.04, ubuntu-24.04-arm}`, runs `nix flake check`. Installer is `cachix/install-nix-action` with `accept-flake-config = false` in `extra_nix_config`. Required to merge into `main`.
- **`.github/workflows/flake-lock.yaml`** — weekly schedule (Mondays 04:00 UTC), runs `DeterminateSystems/update-flake-lock` to open a PR; PR body surfaces per-input commit range URLs; merge is manual.
- **`.github/workflows/gitleaks.yaml`** — incremental secrets scan on PR and push.

The `.githooks/` directory is removed; `just install-hooks` is removed from the justfile. The bash banner check moves verbatim to `scripts/hardware-config-banner.sh` and is wired into `pre-commit.settings.hooks` as an extra hook.

The binary cache backend is deferred to ADR-026. CI v1 runs without an extra substituter; cold-build cost on the headless role is ~5–8 min per arch.

ADR-023's *rule* is unchanged. Its Implementation section gains a forward-pointer to ADR-025 as the realised enforcement mechanism — the existing bash hook was never formally documented there.

## Rationale

**Flake as the single source of truth for checks.** The architectural commitment is that every check CI runs is a flake output. CI is mechanism (run `nix flake check`); the flake is policy (what counts as correct). This means (i) `nix flake check` locally exactly reproduces CI; (ii) the pre-commit hook, the CI gate, and the operator's manual verification all run the same code path; (iii) "what does CI do?" is answered by reading `parts/checks.nix`, not by reading YAML. The previous regime — bash hook installed imperatively, no CI mirror — failed both the determinism principle and the declarative-over-imperative stance from `docs/philosophy.md`.

**`git-hooks.nix` over the bash hook.** `git-hooks.nix` (renamed from `pre-commit-hooks.nix`) is the only flake-native hook-management option that integrates cleanly with `flake-parts` and surfaces its checks under `checks.<system>.pre-commit-check` for `nix flake check` to consume. Replacing the bash hook with a `git-hooks.nix` extra hook costs ~10 lines of nix and removes ~50 lines of `.githooks/` + `justfile` imperative ceremony. The banner-grep logic moves to `scripts/hardware-config-banner.sh`; `git-hooks.nix` invokes it via `entry` per matched file, with pre-commit's framework handling the staged-content selection that the old hook did manually via `git diff --cached`. Keeping the shell as a tracked file preserves diff readability and portability across whatever runs it.

**Per-host check shape.** `checks.<system>.host-<name>` is the conventional way to surface NixOS configurations to `nix flake check`. The `lib.optionalAttrs` scoping by system ensures `nix flake check` on `aarch64-linux` builds only nixos-vm and skips mercury/metis; on `x86_64-linux` it builds the inverse. CI's matrix then exercises each arch's natural set without per-host workflow conditionals. Modern Nix also builds `nixosConfigurations.*.config.system.build.toplevel` automatically for `nix flake check`, but exposing them as named checks lets us `nix build .#checks.x86_64-linux.host-mercury` directly without remembering the full attribute path.

**`cachix/install-nix-action` over `DeterminateSystems/nix-installer-action`.** The DSI installer ships Determinate Nix (vanilla nix with patches) and integrates with FlakeHub Cache; we use neither. Every flake input in this repo carries `inputs.nixpkgs.follows = "nixpkgs"`; consuming a different nix flavour in CI than on hosts would violate that pattern in spirit. `cachix/install-nix-action` installs upstream nix from nixpkgs, matching the daemon nix on every host. The ~20s install-time delta is irrelevant at our CI cadence.

**`accept-flake-config = false` on the runner.** Without this, transitive `nixConfig` blocks from any flake input could silently add substituters or change settings during a CI build. With prompts disabled (CI is non-interactive), nix's default behaviour is silent acceptance. The explicit `false` carries the whitelist-over-blanket stance from `nix-daemon.nix` into CI.

**Weekly lockfile bumps with manual merge.** A weekly cadence keeps each bump's diff small enough to glance at without the noise of more-frequent automation. Manual merge preserves the moment-of-attention on the diff — green CI proves structural correctness (every host still builds) but does not prove behavioural neutrality (a service whose defaults shifted, a renamed home-manager option, a security-relevant change worth knowing about). The `update-flake-lock` action's `pr-body` is configured to surface per-input commit range URLs so the review is a 15-second eyeball, not a hunt. Auto-merge-after-delay was considered and rejected: it removes the forcing function that makes the manual click meaningful — you stop looking and let the timer run.

**Fine-grained PAT for the bot.** PRs opened with the default `GITHUB_TOKEN` do not trigger downstream workflows (GitHub's recursion guard), which would defeat the purpose — CI would never run on the bumped lockfile. A fine-grained PAT scoped to this repo with `contents=write, pull-requests=write, metadata=read` is the smallest authority that solves the problem. GitHub App was considered: it offers better hygiene (1-hour minted tokens, bot identity for audit) at roughly triple the setup cost. The remaining App benefit over a fine-grained PAT (minted tokens vs 1-year-max stored tokens) is real but marginal for a personal repo with one bot.

**No binary cache in v1.** Adopting Cachix in v1 would pre-empt ADR-026's deliberate choice between Cachix and attic, and would require operator-side keypair setup the in-flake CI work doesn't otherwise need. `magic-nix-cache-action` would solve CI iteration speed but not the headline problem (hosts also pulling) and is being sunset in favour of FlakeHub Cache. "No cache" lands CI now with cold-build cost of ~5–8 min/arch on the headless role; ADR-026 reverses that with one additional workflow step.

**Always run; no `paths-ignore`.** Skipping docs-only changes was considered. The savings (~2–5 hours/year of non-billable runner time on a public repo) do not justify either (i) the GitHub gotcha where required status checks expected-but-not-reported leave PRs unmergeable, or (ii) the YAML complexity required to dodge it cleanly (paths-changed detector + gated downstream jobs).

## Consequences

- ✓ Every host's `system.build.toplevel` is built on every PR. The "broken commit on `main` discovered by `nh os switch`" failure mode is eliminated.
- ✓ Lockfile freshness becomes declarative (weekly cadence, declared in `.github/workflows/`) rather than operator-vigilance-dependent.
- ✓ The bash hook + `just install-hooks` apparatus disappears; a fresh clone gets full enforcement via `nix develop` with no separate install step. Bus-factor improves: the hook is part of the flake and survives operator changes.
- ✓ `nix flake check` locally reproduces CI exactly. No "works on CI, fails locally" or vice versa.
- ✓ The amendment to ADR-023 preserves it as the single source of truth for the banner rule; readers there find the current enforcement mechanism rather than having to discover ADR-025.
- ✗ Two new flake inputs (`git-hooks-nix`, `treefmt-nix`). Both are well-maintained nix-community-adjacent projects; new surface area in a deliberately minimal flake.
- ✗ CI runs without a binary cache; cold-build cost is ~5–8 min per arch per run. Bearable for the headless role at the current PR cadence; resolved by ADR-026.
- ✗ Fine-grained PAT lives in repo secrets and expires after 1 year (GitHub's hard cap). Rotation is operator work, scheduled out-of-band.
- ✗ `cachix/install-nix-action` is owned by Cachix, a single org. The action is a thin shim over the upstream installer rather than a flavour of nix; risk is the action itself rather than the nix it installs. Migration is one line if the action becomes unmaintained.
- ⚠ Explicit non-goals — considered and rejected for v1, with re-evaluation triggers documented:
    - **Binary cache backend.** Subject of ADR-026.
    - **`nixosTest` for the headless role.** Trigger: role gains anything beyond pure module merges (custom systemd unit, activation script with side-effects).
    - **Self-hosted runner on Metis.** Triggers: (1) ADR-026 picks attic-on-Metis — shared `/nix/store` makes the pairing compelling; (2) Tier 5 lands and CI wall-clock crosses ~20 min.
    - **`paths-ignore` for docs-only changes.** Trigger: per-arch CI runtime crosses ~20 min and docs-only PR cadence becomes material.
    - **SAST / CodeQL.** Wrong threat model for a personal config.
    - **Dependency vulnerability scanners** (Trivy, Grype, etc.). Same.
    - **Bootstrap-path verification** (nixos-anywhere in CI). Overkill until `disko.nix` changes non-trivially.
    - **Closure-size regression gates.** Premature.
    - **Deploy from CI** (deploy-rs / colmena). Separate ADR, separate decision.
    - **Required approving review on PRs.** Solo repo; false ceremony.
    - **SHA-pinned action versions.** `@vN` major-version pins are sufficient for the current threat model; trigger to revisit is if the repo gains automation that touches real secrets or a specific action's maintainer warrants distrust.
    - **GitHub App for the lockfile bot.** Trigger: a second bot worth consolidating under one App identity, or PAT rotation becomes a noticeable burden.
    - **Auto-merge of green `flake.lock` PRs.** Trigger: the manual review consistently surfaces nothing of interest across several months and the friction outweighs the signal.
    - **Sharded check runs** (e.g. `nix-fast-build`, matrix-of-checks rather than one `nix flake check` invocation). Trigger: per-arch `nix flake check` runtime crosses ~15 min.

## Implementation

**Flake inputs added** (`flake.nix`):

```nix
git-hooks-nix = {
  url = "github:cachix/git-hooks.nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
treefmt-nix = {
  url = "github:numtide/treefmt-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

**Flake-parts modules added** to the `imports` list in `outputs`:

```
./parts/checks.nix
./parts/formatter.nix
./parts/dev-shells.nix
```

Each module follows the per-output-file convention used by `parts/nixos.nix` (attributed there to ryan4yin's flake shape).

**`parts/checks.nix`** imports `git-hooks-nix.flakeModule`. Pre-commit hooks: nixfmt, statix, deadnix, actionlint, plus an extra `hardware-config-banner` hook whose `entry` points to `./scripts/hardware-config-banner.sh` and whose `files` pattern matches `^hosts/[^/]+/hardware-configuration\.nix$`. Per-host checks under `checks.<system>` via `lib.optionalAttrs` per the Decision section. The hook `package` references for nixfmt are explicitly `pkgs.nixfmt` (canonical RFC-style formatter) — *not* `pkgs.nixfmt-rfc-style` (deprecated alias; see the comments in `home/core/shared/nix-tooling.nix`).

**`parts/formatter.nix`** imports `treefmt-nix.flakeModule`. Programs enabled: `nixfmt`, `shfmt`. `projectRootFile = "flake.nix"`.

**`parts/dev-shells.nix`** defines `devShells.default = pkgs.mkShell` with `inherit (config.pre-commit.installationScript) shellHook;` and a packages list including `just`, `nixfmt`, `statix`, `deadnix`, `actionlint`, `nix-output-monitor`, `sops`, `age`. `actionlint` is included so ad-hoc local runs match the CI hook surface.

**`.github/workflows/ci.yaml`**: matrix `include` covers `{ runner: ubuntu-24.04, arch: x86_64-linux }` and `{ runner: ubuntu-24.04-arm, arch: aarch64-linux }`. Steps: `actions/checkout@v4`, `cachix/install-nix-action@v31` with

```
extra_nix_config: |
  experimental-features = nix-command flakes
  accept-flake-config = false
```

then `nix flake check --print-build-logs`. Concurrency group cancels in-progress on PR commits, never on `main`.

**`.github/workflows/flake-lock.yaml`**: schedule `0 4 * * 1`, plus `workflow_dispatch`. Permissions `contents: write, pull-requests: write`. Uses `cachix/install-nix-action@v31` for consistency with the gating workflow, then `DeterminateSystems/update-flake-lock@main` with `token: ${{ secrets.GH_PAT_FLAKE_LOCK }}` (fine-grained PAT scoped to this repo: contents r/w, pull-requests r/w, metadata r), `pr-title: "flake: weekly lockfile bump"`, `pr-labels: dependencies,automated,flake-lock`, and a `pr-body` template surfacing per-input commit range URLs.

**`.github/workflows/gitleaks.yaml`**: triggers on `pull_request` and `push`; uses `gitleaks/gitleaks-action@v2` with default (incremental) scope.

**Action version pinning**: all actions pinned to `@vN` major-version tags. SHA pinning rejected as ceremony beyond the current threat model.

**Branch protection** (configured on GitHub, recorded here for completeness): require the `flake-check (x86_64-linux)` and `flake-check (aarch64-linux)` status checks to merge; no required approving review (solo); linear history enforced (matches existing git history).

**Files removed:**
- `.githooks/pre-commit` (logic moves to `scripts/hardware-config-banner.sh`)
- `.githooks/` directory
- `install-hooks` recipe in `justfile`

**Files added:**
- `parts/checks.nix`, `parts/formatter.nix`, `parts/dev-shells.nix`
- `scripts/hardware-config-banner.sh` (verbatim move with minor adjustments for `git-hooks.nix` entry conventions)
- `.github/workflows/ci.yaml`, `.github/workflows/flake-lock.yaml`, `.github/workflows/gitleaks.yaml`

**Files amended:**
- `flake.nix` (two new inputs, three new module imports)
- `docs/decisions/ADR-023-host-config-three-file-structure.md` (Implementation section: pointer to ADR-025; the rule itself unchanged)

**Operator-side one-shot setup** (post-merge, before CI is enabled as a required check):
1. Generate fine-grained PAT on GitHub (Settings → Developer settings → Personal access tokens → Fine-grained; scope: `dannyfaris/nix-config`; permissions: contents r/w, pull-requests r/w, metadata r; expiration: 1 year).
2. Store as repo secret `GH_PAT_FLAKE_LOCK`.
3. After first green CI run on a PR, configure branch protection on `main` to require both matrix statuses.

The binary cache backend is the subject of follow-up **ADR-026**. CI's Implementation will gain a cache-substituter step at that time without other structural change to this ADR's commitments.

### Implementation notes (post-acceptance)

Three corrections discovered during the implementation pass (2026-05-27):

1. **`self` is not available inside `perSystem`.** flake-parts deliberately scrubs `self` from `perSystem`'s module args (it throws via `throwAliasError'`). The per-host `host-<name>` checks are therefore defined at the top-level `flake.checks.<system>.host-<name>` namespace, not inside `perSystem`. `pre-commit.settings.hooks` correctly remains in `perSystem`.

2. **`config.pre-commit.installationScript` is a string, not an attrset.** The Implementation section's prescribed `inherit (config.pre-commit.installationScript) shellHook` would throw at evaluation. The correct path is `config.pre-commit.shellHook` — that's what `parts/dev-shells.nix` uses.

3. **nixfmt lives in treefmt only, not in the pre-commit hooks list.** Enabling nixfmt in both `treefmt-nix` and `git-hooks.nix`'s pre-commit hooks (as the Implementation section originally listed) causes two nixfmt invocations per `nix flake check`. The implementation keeps the formatter cleanly separated: treefmt owns formatting (nixfmt + shfmt, exposed via `nix fmt` and `checks.<system>.treefmt`); pre-commit owns linting (statix + deadnix + actionlint + hardware-config-banner).

A small conformance gap surfaced: the auto-generated `hosts/<name>/hardware-configuration.nix` files have inherent statix W20 (repeated-key) warnings from `nixos-generate-config`'s output shape, which can't be refactored without breaking ADR-023's regenerate-via-`nixos-anywhere` contract. The implementation excludes those files via `statix.toml`'s `ignore = [...]` (statix runs whole-tree, so per-hook `excludes` don't filter it), via the per-hook `excludes` in `parts/checks.nix` for deadnix, and via `treefmt.settings.global.excludes` in `parts/formatter.nix`. The `nixos-vm` legacy two-file `hardware.nix` is excluded by the same set per ADR-023's legacy carve-out.

## History

### treefmt added to the pre-commit hooks; §3's formatter/linter split revised (2026-05-31)

Implementation note §3 above drew a clean line — *treefmt owns formatting; pre-commit owns linting* — and kept the formatter out of the pre-commit hook list specifically to avoid two nixfmt invocations per `nix flake check`. That split optimised for one cost (duplicate invocation) but missed the cost that actually bit: **a pre-commit that does not format-check lets format violations reach CI.** A multiline-string mis-format in `home/core/nixos/greetd.nix` was committed locally without complaint and failed only in CI (#54 P5.5, root-caused in #64). The forcing function the pre-commit hook is supposed to provide — catch it before it leaves the machine — did not exist for formatting.

This amendment revises §3: **`treefmt` is now also a pre-commit hook** (`parts/checks.nix`, `pre-commit.settings.hooks.treefmt`), so `git commit` runs the same format check that CI runs. The split is no longer "formatting vs linting" but "where each runs": formatting and linting both run at commit-time and at flake-check/CI-time.

**Single-source-of-truth is preserved.** The hook does not re-declare nixfmt/shfmt or the auto-generated-`hardware-configuration.nix` exclude globs. It reuses the wrapper `parts/formatter.nix` already builds, via `packageOverrides.treefmt = config.treefmt.build.wrapper` (which required widening `parts/checks.nix`'s `perSystem` signature from `_:` to `{ config, ... }:` so the formatter's merged config resolves). The formatter list and its carve-outs stay defined once, in `formatter.nix` — adding a third formatter or changing an exclude still touches one file.

**§3's double-invocation cost is accepted, deliberately.** Because git-hooks.nix surfaces the pre-commit hooks into `checks.<system>.pre-commit`, and the standalone `checks.<system>.treefmt` is retained (#64 chose "add hook, keep CI check"), treefmt now runs twice per `nix flake check`. This is exactly what §3 set out to avoid — and is accepted here as a negligible price: treefmt is fast and incremental (sub-second on this repo), and keeping the standalone `checks.<system>.treefmt` provides an **independent CI format gate** that still fails the build if the hook integration ever regresses (e.g. a flake-input bump breaking `config.treefmt.build.wrapper`). Defence-in-depth at trivial cost outweighs the tidiness §3 optimised for. Were the duplicate run ever to become non-trivial, the lever is to drop the standalone check and rely on the hook's surfaced `checks.<system>.pre-commit`.

The Decision and Implementation sections' hook enumerations ("Hooks: nixfmt, statix, deadnix, actionlint, …") predate this change and are read as historical; the live hook set is `parts/checks.nix`.

### Auto-generated-hardware-config exclude list collapsed to one source (2026-05-31)

The Implementation conformance-gap paragraph above named three separate places where the ADR-023 carve-out is enforced — `statix.toml`'s `ignore`, `parts/checks.nix`'s `autoGenExcludes`, and `parts/formatter.nix`'s `treefmt.settings.global.excludes`. The earlier History entry's "formatter list and its carve-outs stay defined once, in `formatter.nix`" was accurate for the formatter list but had always been wrong about the carve-outs themselves — they were enumerated three times in different syntaxes (TOML glob, Nix regex, Nix glob), with a comment in `parts/checks.nix` honestly acknowledging the duplication.

Per #50 the canonical list now lives once, in `statix.toml`'s `ignore` array (statix-the-CLI reads it directly from a fixed path, so it has to exist there). A small helper at `lib/auto-gen-paths.nix` parses that file via `builtins.fromTOML (builtins.readFile …)` and exposes the list in both shapes (`globs` verbatim, `regexes` derived). Both Nix-side consumers — the pre-commit hook's `excludes` and treefmt's `settings.global.excludes` — read from the helper. Adding a new auto-generated file is now a one-line append to `statix.toml`'s `ignore` array.

Two behavioural notes: (i) the derived regex form converts glob `*` to `[^/]*` (zero-or-more) rather than the previously hand-coded `[^/]+` (one-or-more); no real filesystem path has a zero-length segment, so this is observable only as a string-level shift in the `pre-commit-config.json.drv` hash — every nixosConfiguration's toplevel `drvPath` is byte-identical to pre-change main. (ii) The glob→regex helper handles only `*` and the literal `.` by design; if the canonical list ever needs `?`, `**`, or character classes, widen the helper rather than letting consumers diverge again (the helper's head comment makes this contract explicit).
