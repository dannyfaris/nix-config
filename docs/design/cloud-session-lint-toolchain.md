# Cloud-session lint toolchain — nix-less linters for containerised agent work

**Status:** Accepted (2026-08-02) — design note (`docs/design/`). Built in the same change; the fetcher is review-bound before its first execution, so the verification plan below is owed rather than discharged. [#722](https://github.com/dannyfaris/nix-config/issues/722) · adjacent to [#464](https://github.com/dannyfaris/nix-config/issues/464), which owns host-side commit-time enforcement and the pre-commit/CI boundary doc — this note does not touch that surface.

*Reading order note: the three options named in #722's scope are argued in **Rationale & alternatives**; **Design** states only the chosen one, fully specified.*

## Summary

A committed `scripts/fetch-lint-toolchain.sh` acquires, into `$HOME/.local/bin`, the six linters the repo's pre-commit set runs — statix, deadnix, shellcheck, actionlint, nixfmt, shfmt — pinned to the exact versions the flake's nixpkgs supplies, so a nix-less cloud container can get the same verdicts locally instead of discovering them in a CI round-trip (~8 minutes post-#712; ~35 at the time of the motivating incidents). Four tools land as checksum-pinned upstream static binaries (~12 MB, verified downloadable and version-exact from a session container); the two Rust tools with no publishable binary — deadnix and statix — are built with the already-present cargo, pinned by crates.io version and by git rev respectively. `treefmt` is deliberately dropped: the repo has no committed `treefmt.toml`, and invoking `nixfmt --check` and `shfmt -i 2 -s -d` directly reproduces its verdicts exactly without re-encoding `parts/formatter.nix` in a second config file. The script installs binaries only — it does not run lints — and it is invoked on demand, not from a SessionStart hook.

## Motivation

Agent sessions for this repo increasingly run in a nix-less cloud container: `nix` is absent, and so is every linter (`statix`, `deadnix`, `shellcheck`, `actionlint`, `nixfmt`, `shfmt`, `treefmt`, `pre-commit` — all confirmed absent). The repo's entire lint policy lives in Nix (`parts/checks.nix` hooks lifted into `checks.<system>.pre-commit`; `.pre-commit-config.yaml` is gitignored), so the host-side escape hatch documented in [docs/workflow.md](../workflow.md) is unavailable there. The consequence is measured, not hypothetical: #464's 2026-08-02 handoff comment records two ~35-minute CI round-trips caused by findings a local linter would have caught in seconds (statix W20 and shellcheck SC2018/SC2019 on #695; shellcheck SC2016 on #709), both authored from exactly this environment.

Forces any solution must honour:

- **Verdict parity with CI, or an honest statement of where it is absent.** A tool that disagrees with the CI binary is worse than no tool: a false green re-buys the round-trip while implying it was paid off.
- **[ADR-032](../decisions/ADR-032-proportionate-enforcement-and-rationale.md) proportionality.** The demonstrated failure licenses *a* mechanism, not a heavy one. #722 itself pre-flags nix-portable as "heavyweight for five binaries".
- **No new drift surface, or a named and bounded one.** The repo single-sources lint scope through `statix.toml` → `lib/auto-gen-paths.nix` → `parts/checks.nix` + `parts/formatter.nix`. A second hand-maintained table of anything is measured against that chain.
- **Untrusted-code discipline.** Fetching and executing third-party binaries is executing code; [docs/workflow.md](../workflow.md) §"Peer review binds to what executes" makes the fetcher itself review-bound, and argues for content-pinning every artifact.
- **Zero blast radius on hosts and on session startup.** This is an agent convenience. It must not be able to wedge a session, and it must not change what any host builds or what CI enforces.
- **Scope discipline.** #722 asks for binary acquisition plus a small design pass. Not a lint runner, not a justfile recipe, not a CI step, not a change to what CI checks.
- **Constraints of the environment, verified:** `api.github.com` is per-repo gated and the HTML `expanded_assets` listing 403s, so asset URLs and versions **cannot be discovered at runtime** — every URL must be hardcoded. `curl`, `tar`, `xz`, `jq`, `git`, `cargo`/`rustc` 1.94.1 and `go` are present; `zstd` is **absent**; `gh` is absent. `$HOME/.local/bin` is first on PATH and writable (uid 0). 30 GB free. x86_64, glibc 2.39.

## Design

### Tool set — six in, treefmt out

| Tool | Pinned version (nixpkgs `e2587caef70cea85dd97d7daab492899902dbf5d`) | Acquisition | Integrity pin |
|---|---|---|---|
| shellcheck | 0.11.0 | `releases/download/v0.11.0/shellcheck-v0.11.0.linux.x86_64.tar.xz`, extract `shellcheck-v0.11.0/shellcheck` | vendored `sha256:8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198` (no upstream checksum file exists) |
| actionlint | 1.7.12 | `releases/download/v1.7.12/actionlint_1.7.12_linux_amd64.tar.gz`, extract `actionlint` | vendored `sha256:8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8`, transcribed from upstream `actionlint_1.7.12_checksums.txt` |
| shfmt | 3.13.1 | `releases/download/v3.13.1/shfmt_v3.13.1_linux_amd64` (bare binary) | vendored `sha256:fb096c5d1ac6beabbdbaa2874d025badb03ee07929f0c9ff67563ce8c75398b1` |
| nixfmt | 1.4.0 | `releases/download/v1.4.0/nixfmt` (bare binary, no platform suffix in the asset name) | vendored `sha256:62488394d5233283096466350487ed46470366f57db4bec824a87ecbacce960a` |
| deadnix | 1.3.1 | `cargo install deadnix --version 1.3.1 --locked --root "$STAGE"` | crates.io sparse-index checksum, verified by cargo (`1.3.1 cksum d47a1ef3…`) |
| statix | `0.5.8-unstable-2026-07-17` | `cargo install --git https://github.com/molybdenumsoftware/statix --rev 52530001bdbc8e94aae0d406a929c7ad7f09d9d1 --locked --root "$STAGE"` | git rev (content-addressed); transitive deps by the `Cargo.lock` committed at that rev |

**Why treefmt is dropped.** The repo commits no `treefmt.toml` / `.treefmt.toml` — the config is generated inside `config.treefmt.build.wrapper` by treefmt-nix from `parts/formatter.nix`. A standalone treefmt binary is inert without a hand-written config that re-encodes `projectRootFile`, nixfmt `includes`, shfmt `-i 2 -s` over `*.sh *.bash *.envrc *.envrc.*`, and `global.excludes` from `lib/auto-gen-paths.nix` — i.e. a second, hand-maintained derivation of Nix-owned config, precisely the drift surface the forces forbid. Invoking `nixfmt --check` and `shfmt -i 2 -s -d` directly was verified to produce the same verdicts on the current tree with no config file at all. Residual risk: if `parts/formatter.nix` gains a formatter or non-default options, the documented direct invocations silently stop matching. Bounded and named — the note points at `parts/formatter.nix` as the source of truth, and that file changing is a review-visible event.

**Why statix stays despite being the hardest case.** nixpkgs pins a mid-branch commit of a *fork* (`molybdenumsoftware/statix`; the commit's own `bin/Cargo.toml` says `version = "0.6.0"` while the derivation is labelled `0.5.8-unstable-…`). No release, anywhere, corresponds to what CI runs; the newest upstream release (v0.5.8, 2023-09-09) is ~3 years of rule drift away. Building the pinned rev is therefore the *only* route to parity — and it introduces no trust that CI does not already extend, because it is byte-identical source to what nixpkgs fetches and builds for every `nix flake check`. Dropping statix instead would exclude one of the two tools whose miss motivated the issue. Note for any version-assertion logic: **statix at this rev has no `--version`/`-V` flag** — idempotence must be stamped on the git rev, not parsed from the binary.

### Mechanics

- **Install target:** `${XDG_BIN_HOME:-$HOME/.local/bin}`, which is already first on PATH in the container. No PATH wiring, no shell-init edit, no `$CLAUDE_ENV_FILE` write, no repo pollution and therefore no `.gitignore` change. cargo builds go to a staging `--root`, and only the resulting binary is moved into place.
- **Platform guard:** refuse unless `uname -s` = `Linux` and `uname -m` = `x86_64`. The nixfmt and shfmt assets carry no platform suffix or an amd64-only one; a silent wrong-arch install is worse than a refusal. Hosts have nix and do not need this script.
- **Fetch discipline:** `curl --fail --location --silent --show-error --retry 3 --retry-delay 2 --max-time 120` to a temp file. `--fail` is non-negotiable: without it a proxy denial body is written to the target path and installed as a "binary". Checksum verified via `sha256sum --check` **before** extraction or install; a mismatch deletes the temp file, records a failure, installs nothing.
- **Idempotence:** each tool is skipped when already installed at `$BIN_DIR` and self-reporting the pinned version; statix is skipped when `${XDG_DATA_HOME:-$HOME/.local/share}/nix-config-lint-toolchain/statix.rev` matches the pinned rev.
- **Failure semantics:** per-tool isolation — a failed tool never aborts the others. The script prints a per-tool `ok/skip/FAIL` summary and exits non-zero if any tool failed, so the agent sees a visible, in-turn, recoverable tool error. Because the script is invoked on demand and never from a startup hook, a total network failure costs the agent one failed Bash call; the session itself is unaffected in every case.
- **Pin-drift warning (the sync story, see below):** the script reads `flake.lock`'s `nixpkgs` rev with `jq` and prints a one-line warning when it differs from the rev the table was aligned against (`e2587caef70cea85dd97d7daab492899902dbf5d`). A warning, not a gate.
- **No lint running.** The script installs. The reference invocations below are documentation, not a committed runner — committing a runner would re-encode `lib/auto-gen-paths.nix`'s exclude derivation in bash, buying a real drift surface to save one copy-paste.

### Version-pin sync story: accepted, documented skew + a warning rung

Every linter CI runs comes from one nixpkgs rev (`git-hooks-nix` and `treefmt-nix` both declare `inputs.nixpkgs = ["nixpkgs"]`), so the pin target is unambiguous. Three sync options were weighed; **the chosen one is accepted-and-documented skew, with the script's `flake.lock` comparison as the detection rung and no mechanical gate.**

Rationale, in ADR-032 terms: a flake check comparing `pkgs.<tool>.version` against a committed manifest is mechanisable and would hold the guarantee — but it goes red on *every* nixpkgs bump, and clearing it requires a network-dependent regeneration (new URLs, new sha256s) before an unrelated flake update can land. That is a standing tax paid to guard an agent convenience, and no skew failure has been demonstrated. The residual risk is bounded in both directions: a skewed linter can only produce a false red (loud, self-correcting — the agent investigates and finds the divergence) or a false green (costs exactly the CI round-trip that is today's status quo, i.e. never worse than not having the script). The warning line makes drift visible at the moment of use, which is when it matters. The escalation trigger is recorded in Future possibilities.

Additionally, statix's skew is *structural and permanent*: any future re-pin must re-read the fork rev from nixpkgs, because no release tag will ever correspond.

### Reference invocations (documentation, mirroring the effective hook commands)

```
statix check                                   # whole-tree; reads statix.toml itself
NIXF=$(git ls-files '*.nix' | grep -vE '^hosts/[^/]*/hardware-configuration\.nix$|^hosts/nixos-vm/hardware\.nix$|^\.claude/worktrees')
deadnix --fail $NIXF
nixfmt --check $NIXF
shellcheck $(git ls-files '*.sh')
actionlint $(git ls-files '.github/workflows/*')
shfmt -i 2 -s -d $(git ls-files '*.sh') .envrc  # .envrc is in shfmt's configured scope
```

The `grep -vE` reproduces `statix.toml`'s three ignore globs. This is the one accepted duplication: three static globs, sitting one file away from their source, changed rarely and visibly.

### Files this change touches

1. `scripts/fetch-lint-toolchain.sh` — **new**, executable. The fetcher. Header comment ≤3 lines of *why* plus a pointer to this note; the #695/#709 incident narrative is history and belongs in the PR body, not inline (ADR-032 rule 2). Being a `*.sh` with a bash shebang, it is automatically covered by the repo's existing `shellcheck` and `shfmt` hooks — the change is gated by the very tools it fetches.
2. `docs/design/cloud-session-lint-toolchain.md` — **new**. This note; the canonical account of the tool set, the pins, the skew stance, and the treefmt drop.
3. `docs/workflow.md` — **one pointer line** alongside the existing host-side escape hatch, naming the script as the cloud-session equivalent and linking this note. This is the living-reference update the design loop requires in the same change.

Explicitly **not** touched: `parts/checks.nix`, `parts/formatter.nix`, `statix.toml`, `lib/auto-gen-paths.nix`, `flake.nix`, `flake.lock`, `justfile`, `.github/workflows/ci.yaml`, `.claude/settings.json`, `.claude/hooks/`, `.gitignore`, and `docs/ci.md` (its lint-set/CI-boundary section is #464's slot — this note points at #464 rather than opening it).

## De-risk evidence

Verified in a session container on 2026-08-02, against `main` @ `3eefd13` (clean tree), through the session proxy:

- **All four static assets download and are version-exact.** shellcheck 0.11.0 (2 559 196 B), actionlint 1.7.12 (2 353 908 B), shfmt v3.13.1 (3 117 218 B), nixfmt 1.4.0 (~4.22 MB) — all HTTP 200, all `file` → ELF x86-64 **statically linked**, stripped, all self-reporting the exact pinned version (`nixfmt --version` → `nixfmt 1.4.0`; `shfmt --version` → `v3.13.1`; `actionlint --version` → `1.7.12`; `shellcheck --version` → `0.11.0`). actionlint's published checksum matched the download byte-for-byte.
- **Both cargo routes work and are fast.** `cargo install deadnix --version 1.3.1 --locked` → exit 0 in **13.3 s**, `deadnix --version` → `deadnix 1.3.1`. `git clone` of `molybdenumsoftware/statix` + checkout `5253000…` + `cargo build --release --locked` → exit 0 in **36.5 s**. Git-over-HTTPS is the only working source channel for statix — the archive/codeload tarball endpoints 403 through the proxy.
- **Verdict parity on the current tree.** All six reference invocations exit 0 against `main` @ `3eefd13`, agreeing with that commit's green CI.
- **Absence of alternatives is established, not assumed.** `astro/deadnix` publishes **zero** GitHub releases; `molybdenumsoftware/statix` publishes zero releases; the crates.io name `statix` is an unrelated crate; cargo-quickinstall has no statix build; Arch/Alpine hosts are refused outright by the proxy (HTTP 000).
- **treefmt is inert standalone** — `treefmt --no-cache --fail-on-change flake.nix` → `Error: failed to find treefmt config file`, and neither `treefmt.toml` nor `.treefmt.toml` is committed.

**Verified at first execution (2026-08-02, post-review; evidence in the implementing PR):**

- **The script ran and installed all six** (`ok` × 6, exit 0), settling the `cargo install --git` workspace-selection question — and a review-caught transport gap: cargo's default libgit2 fetch ignores git's `url.insteadOf` rewrite, the only proxied route to github.com, so the script pins `CARGO_NET_GIT_FETCH_WITH_CLI=true` for git deps.
- **Negative controls fire with CI's exact codes** — statix **W20**, shellcheck **SC2018/SC2019/SC2016**, and `nixfmt --check` / `shfmt -i 2 -s -d` both flag mangled files — while positive parity holds (all six reference invocations exit 0 on the reference tree, the staged fetcher included).
- **Idempotence is verified at the guard level only**: each installed tool satisfies its skip condition (version self-report, or rev-stamp plus `--help` for statix). The full second run and the corrupted-checksum drill were blocked by the session's execution classifier — those two paths are covered by the adversarial static review, not by a live run.

**Still unverified — stated, not papered over:**

- **Build-provenance divergence.** Even at identical versions, the fetched binaries are different builds from CI's nixpkgs ones (different compiler, different feature flags). No divergent verdict has been observed; none has been searched for beyond the current tree.
- **statix builds dynamically linked** (PIE against `libc.so.6`, `libgcc_s.so.1`), unlike the other five. glibc 2.39 there satisfies it, but the artifact is not portable across differently-based containers.

### Verification plan (the issue's own bar: "run the fetched set against the current tree and compare verdicts with a known CI run")

1. **Fix the reference.** Take the most recent successful `ci.yaml` run on `main` and its commit `C` (at time of writing, `main` @ `3eefd13`); check out `C` with a clean tree. That run's green `checks.x86_64-linux.pre-commit` and `.treefmt` are the reference verdicts.
2. **Fetcher behaviour first, because everything else depends on it.** Run the script once and confirm all six install, `cargo install --git` included; run it a second time and confirm every tool reports `skip`; run it with a deliberately corrupted vendored sha256 for one tool and confirm nothing is installed for it, that the summary reports exactly that one `FAIL`, and that the other five still install.
3. **Positive parity.** Run all six reference invocations against the script's own installed binaries. **Parity = all six exit 0**, matching the reference run's green pre-commit + treefmt.
4. **Negative control — the load-bearing step.** In a scratch copy: (a) reintroduce the statix W20 finding from #695 and confirm `statix check` reports **W20** and exits non-zero; (b) reintroduce an SC2016 construct from #709 and an SC2018/SC2019 construct from #695 in a tracked `*.sh` and confirm `shellcheck` reports those exact codes; (c) mangle formatting in one `*.nix` and one `*.sh` and confirm `nixfmt --check` and `shfmt -i 2 -s -d` both flag them, matching what the treefmt check would have said. Parity here means **same finding codes on the same lines**, not merely same exit status.
5. **Evidence lands in the PR body** (history, not rationale), per ADR-032 rule 2.

Per [docs/workflow.md](../workflow.md) §"Peer review binds to what executes", the script gets adversarial subagent review **before its first execution**, not merely before commit.

## Drawbacks

Reasons not to do this at all:

- **It is a second, hand-maintained version table** in a repo whose lint scope is single-sourced through `statix.toml` → `lib/auto-gen-paths.nix`. Six versions, four URLs, four sha256s and a git rev, none derived from `flake.lock`. That is a genuine drift surface and the accepted-skew decision does not eliminate it, it merely bounds and announces it.
- **It downloads and executes third-party binaries** in an environment with root and repo write access. Three of four sha256s are TOFU — pinning what was downloaded on 2026-08-02, not an upstream attestation, because upstream publishes no checksum file. The statix route additionally clones an external fork and runs an unsandboxed cargo build of it (~40 transitive crates), which is *provenance-equal* to CI but not *verification-equal*: nix checks a NAR hash end-to-end, cargo checks per-crate checksums and nothing about the resulting binary.
- **It solves nothing for hosts, CI, or the fleet.** It is pure agent ergonomics; the whole value is measured in agent round-trips.
- **It is per-container cost with no caching benefit.** Because the mechanism is on-demand rather than a startup hook, the installs happen after the point the session-start skill describes as the container-caching boundary — a fresh container pays the ~50 s cold cost again.
- **The invocation can be forgotten.** The script's failure mode is silence, which is the same shape as the failure it fixes. The mitigation is a doc pointer and agent discipline, not a mechanism.

## Cost

Standing prices, none of them obvious from the design: a **~50 s cold acquisition** per container (~12 MB download plus ~50 s of cargo build); a **cargo/rustc dependency** for two of six tools, so the toolchain degrades to four tools in any container without Rust; and a **re-pinning chore** on any nixpkgs bump that moves a linter version — six versions to re-read, up to four assets to re-download and re-hash, and the statix fork rev to re-read from nixpkgs by hand.

## Rationale & alternatives

**(a) SessionStart hook fetching pinned static binaries — rejected.** It has the one advantage nothing else has: the session-start skill states container state is cached *after the hook completes*, so hook-installed binaries are the ones most likely to survive into future sessions, and it cannot be forgotten. But it loses on three hard points. First, it is **unvalidatable by its own PR** — the skill is explicit that a hook takes effect only once it is merged to the repo's default branch, so the change that introduces it cannot demonstrate it works, which collides directly with the repo's runtime-verification convention and #303's set ≠ enforced gap. Second, the **failure surface is worse and less understood**: the skill documents no sync-mode timeout and no exit-code semantics, while the container's own git-identity hook swallows all failures with a comment explaining that a broken install must not be able to wedge session startup — a first-party author designing against a risk the docs do not describe. Third, whether the local proxy listener is even up at hook time is **unverified and unverifiable from inside a running session**; if it is not, every fetch fails on every session. It also re-runs on `resume`, `clear` and `compact`, giving a network-dependent path four trigger classes instead of one, and it pays the acquisition cost for docs-only sessions that never lint. Parked, not dead — see Future possibilities.

**(b) Committed `scripts/fetch-lint-toolchain.sh`, invoked on demand — chosen.** It is the lightest rung that holds the guarantee (ADR-032): it runs inside the agent's Bash tool with a fully-initialised, demonstrably-working environment; its failures are visible, in-turn and recoverable; it cannot touch session startup; it lives in `scripts/` alongside ten existing bash tools and is linted by the repo's own hooks; and — decisively — it is **usable and verifiable the moment it exists on disk**, so the change that introduces it can execute the full verification plan above rather than asserting it. Its one real weakness, that invocation can be omitted, is a discipline problem, and ADR-032 says to buy a mechanism for it only after a lighter rung demonstrably fails. It has not been tried yet.

**(c) nix-portable — rejected, as #722 anticipated.** It would deliver true parity: the same derivations CI evaluates, no second version table, no skew, no re-pinning chore. The price is a full Nix store bootstrap and an evaluation of this flake's inputs to obtain six binaries totalling ~12 MB, in a container that will discard it. That is the heaviest available rung bought for the lightest available guarantee — the inverse of ADR-032's instruction, and disproportionate to an agent-convenience problem. It also does not obviously work here: the tarball/codeload endpoints the proxy 403s are the same class of channel a store bootstrap needs, which would have to be de-risked before nix-portable could even be evaluated.

**Doing nothing** keeps the status quo: cloud sessions push, CI fails ~8 minutes later (post-#712; ~35 when the two incidents happened) on a finding a two-second local run would have caught, twice in recent memory and increasing as more work moves to containers.

## Prior art

- **This repo's own pinning idioms**, which the fetcher deliberately mirrors: GitHub Actions pinned by full commit SHA with a version comment, and flake inputs pinned by `rev` + `narHash`. Both are pin-by-identity, never pin-by-floating-tag; the vendored sha256s and the statix git rev are the same move in a channel without Nix.
- **#583's bash-only lints and self-tests**, which established that this repo's custom lints already run in a nix-less shell — eight of nine custom hooks need nothing beyond bash/grep/git. That is why #722 is scoped to *packaged* linters only; the custom ones already work here. (The lone exception, `bundle-purity`, needs `nix-instantiate` and is out of scope for the same reason.)
- **External installer patterns** — rustup-init, `mise`/`asdf` plugin installers, `bazel`'s `tools/bazel` wrapper: pinned URL + vendored checksum + `install -m 755` into a PATH dir, idempotent via a version-string guard. The design is that shape, with nothing invented.
- **cargo-quickinstall**, surveyed and rejected as the deadnix route: its prebuilt is static, 515 KB and version-exact, but it is built by a third-party org's CI, publishes no checksum file, and its minisign signatures are unverifiable in a container with no minisign and no pinned public key. `cargo install --locked` costs 13 s and keeps the trust chain first-party.

## Unresolved questions

**Adjudicated at review (2026-08-02), recorded as decided:**

1. **Ship statix at all, given it requires cloning and building an external fork?** **Yes.** It caused one of the two motivating round-trips, the rev is byte-identical to what nixpkgs already builds in CI, and there is no other route. The residual risk that would have followed from dropping it — cloud sessions keep discovering statix findings in CI — is therefore not taken.
2. **`$HOME/.local/bin` or a gitignored repo-local `.lint-bin/`?** **`$HOME/.local/bin`** (via `$XDG_BIN_HOME`) — already first on PATH, no PATH wiring, no `.gitignore` change, no repo pollution.
3. **deadnix via cargo-quickinstall prebuilt or `cargo install --locked`?** **`cargo install --locked`** — first-party source, cargo-verified checksum, 13 s, and consistent with the statix route.
4. **Vendor sha256 uniformly, including where upstream publishes checksums?** **Yes, all four** — one mechanism, with actionlint's value transcribed from upstream `checksums.txt` and the other three TOFU-computed at pin time, marked as such in the script.
5. **Mechanical pin-sync check (flake check comparing `pkgs.<tool>.version` to a manifest)?** **No gate; warn-on-drift only.** See the sync-story rationale.
6. **Cross-platform support?** **Refuse on anything but Linux/x86_64.**

**Settled by the first execution (2026-08-02, see §De-risk evidence):**

7. **Does `cargo install --git … --rev …` resolve the statix workspace to its one binary-bearing member?** **Yes** — no package argument needed, once the fetch is routed through the git CLI.
8. **Does the negative control reproduce CI's exact finding codes** (W20, SC2016/2018/2019)? **Yes, all four codes verbatim** — no divergence observed, so the parity claim stands un-narrowed.
9. **Where the verification evidence lands.** **PR body** — it is history, not rationale.

Explicitly out of scope: a lint *runner* or justfile recipe; any change to `parts/checks.nix`, CI, or what CI enforces; the `bundle-purity` hook (needs `nix-instantiate`); host-side commit-time enforcement and the pre-commit/CI boundary documentation, both owned by #464; and aarch64/darwin support.

## Future possibilities

- **Promote to a SessionStart hook** once the script has proven itself, as a thin wrapper that calls it — capturing the container-caching benefit and removing the forgot-to-invoke failure. Trigger condition: a second incident where a cloud session shipped a finding the script would have caught but was not run. Prerequisite: empirically confirm the proxy listener is up at hook time from a merged, minimal hook before any fetch logic moves there.
- **Escalate the pin-sync warning to a flake check** if a version skew is ever observed producing a divergent verdict — that is the demonstrated failure ADR-032 requires before buying the heavier rung.
- **Derive the version table from `flake.lock`** rather than hand-maintaining it, should a nix-less way to read nixpkgs package versions become cheap. This would collapse the drift surface entirely and is the only change that would make the mechanical check free.
- **Reconsider treefmt** if `parts/formatter.nix` ever gains formatters beyond nixfmt/shfmt, at which point emitting a `treefmt.toml` from the Nix config (rather than hand-writing one) becomes the right move.
