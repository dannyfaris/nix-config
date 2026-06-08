# ADR-033: Eval-time checks for deliberate stances and lib functions

**Date**: 2026-06-08
**Status**: Accepted, Implemented

> Adds a fast, eval-only regression net to the CI stack: assert the CLAUDE.md "Deliberate stances" still hold across the host matrix, and unit-test the `lib/` functions that carry real logic. No new architecture — it extends the [ADR-025](./ADR-025-ci-in-flake.md) in-flake CI framework with checks the per-host `toplevel` builds structurally cannot provide.

## Context

The verification stack (per [ADR-025](./ADR-025-ci-in-flake.md)) proves a config *builds and is clean*: per-host `system.build.toplevel` derivations, treefmt/statix/deadnix/shellcheck/actionlint, and the purity linters. Every one of those answers "does it evaluate, build, and lint?" None answers "is the config still doing what we deliberately decided it must?"

So a one-line change that weakens a deliberate stance — flipping `users.mutableUsers = true`, re-enabling SSH `PasswordAuthentication`, broadening the `allowUnfreePredicate` whitelist to a blanket `allowUnfree = true` — **builds green and auto-merges**. The CLAUDE.md §"Deliberate stances — do not relax without asking" table is enforced only by reviewer vigilance. After a high-throughput, squash-auto-merge stretch (the ADR-032 cleanup cluster, #291–#298) that is the live risk: a policy regression the build cannot see.

Separately, `lib/` carries real logic with no test coverage. `lib/auto-gen-paths.nix` parses `statix.toml` into the glob/regex lists that *both* `parts/formatter.nix` (treefmt excludes) and `parts/checks.nix` (statix/deadnix excludes) consume; a silent bug in its glob→regex translation would mis-scope the formatter across the whole tree and surface as confusing, unrelated churn.

## Decision

Add two eval-only check families to `flake.checks`, gated by `nix flake check` and therefore by CI:

1. **Deliberate-stance assertions.** `lib/stances.nix` evaluates each host's config against the stance table and returns a list of human-legible violation strings (empty = all hold). `parts/checks.nix` renders the list into a per-host `stances-<host>` derivation that fails the build, printing the violations, when non-empty. Coverage: `users.mutableUsers`, the SSH posture (`PasswordAuthentication`/`PermitRootLogin`/whitelist/`MaxAuthTries`/`LoginGraceTime`, gated on `services.openssh.enable`), the `allowUnfree` whitelist-not-blanket invariant, `programs.command-not-found.enable`, and `nix.settings.warn-dirty`. Platform-split because the option surfaces diverge (`mutableUsers`/`command-not-found` are NixOS-only; SSH hardening is structured `settings.*` on NixOS but free-form `extraConfig` text on nix-darwin).

2. **`lib/` unit tests.** `lib/tests/auto-gen-paths.nix` exercises `auto-gen-paths.nix`'s `globToRegex` (exposed for the purpose) via `pkgs.lib.runTests`, plus the `regexes == map globToRegex globs` contract. Rendered into a `lib-auto-gen-paths` check the same way. Run once on the x86_64-linux runner — the test is pure eval and platform-independent, so per-runner replication buys nothing.

These are **config-level** assertions: they prove a stance is *set* in the evaluated config — the fast, host-matrix-wide net, milliseconds, no VM.

## Rationale

**Why `pkgs.lib.runTests`, not `nix-unit`.** Per [ADR-032](./ADR-032-proportionate-enforcement-and-rationale.md) Rule 1 (lightest mechanism that holds the guarantee): `runTests` ships in nixpkgs `lib`, adds no flake input, and is sufficient for pure-function assertions. `nix-unit` is a richer harness but would add an input and a dependency to maintain for no gain at this scale. Escalate only if the test surface outgrows `runTests`.

**Why a render-to-derivation helper, not module `assertions`.** Module-level `assertions` would fail the host's own `toplevel` build, coupling stance verification to the (slow, heavy) build and giving a less legible failure. A separate eval-only check derivation per host keeps stance failures fast, isolated, and clearly named.

**Why config-level, not behavioural.** "Set in config" is not always "behaves at runtime" — sshd genuinely *rejecting* a password is the canonical gap. But config-level assertions are pure eval (fast, every PR, whole matrix) and catch the overwhelmingly likely regression: someone changing the declared value. Behavioural coverage is heavier and Linux-only (see below); the two are complementary, and the cheap net comes first.

## Consequences

- ✓ Flipping a deliberate stance now fails a CI-gated check on the affected host(s) with a legible message, instead of auto-merging green.
- ✓ `lib/auto-gen-paths.nix`'s logic has regression coverage; a glob→regex bug fails CI instead of silently mis-scoping the formatter.
- ✓ Pure eval — negligible CI cost (no VM, no extra build), runs on every PR alongside the existing checks.
- ✗ The stance assertions duplicate the *values* in the source modules; changing a stance now means editing both the module and `lib/stances.nix`. That coupling is the point — the check exists precisely to make a stance change a deliberate, two-place act — but it is a maintenance edge to keep in mind.
- ✗ Config-level only: a stance that is set correctly but fails to take effect at runtime is not caught. Tracked by the VM-test deferral below.

### Explicitly out of scope

- **Property tests — ruled out.** A declarative config has no meaningful randomised input space; the invariants are fixed over a known host set and belong as assertions, not generators. Recorded so it isn't reconsidered by reflex.
- **NixOS VM tests (`runNixOSTest`) — deferred to a fast-follow.** Worth it for the few stances where "set in config" ≠ "behaves" (sshd actually rejecting a password is the prime case), but heavyweight, slow, and **Linux-only** — Darwin (mac-mini) behaviour stays manual regardless. Track separately; this ADR is the cheap-net layer beneath it.

Cross-reference: [ADR-025](./ADR-025-ci-in-flake.md) (the in-flake CI framework this extends); [ADR-032](./ADR-032-proportionate-enforcement-and-rationale.md) (Rule 1 — lightest mechanism, which selects `runTests` over `nix-unit`); CLAUDE.md §"Deliberate stances" (the source of the asserted invariants).
