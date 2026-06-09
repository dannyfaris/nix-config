# ADR-030: nixpkgs channel — track `nixos-unstable`

**Date**: 2026-05-31
**Status**: Accepted, Implemented

## Context

`flake.nix:5` pins `nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"`. This is the largest deliberately-unstated decision in the repo — there is no ADR explaining the choice between `nixos-unstable` and the current stable channel (`nixos-25.11`). The choice has touched several follow-on decisions ([ADR-025](./ADR-025-ci-in-flake.md)'s flake-lock cadence, [ADR-028](./ADR-028-stylix-foundation-and-desktop-env.md) §Consequences naming the unstable risk for Stylix targets) but has never itself been recorded. This ADR closes that gap.

The shape of the fleet drives the question. Three NixOS hosts today (one aarch64 VM, one x86_64 headless AWS, one x86_64 desktop), with macOS hosts pending under epic #11. Several flake inputs themselves track `nixos-unstable` upstream — notably `stylix` (visual identity surface that spans every Nix-managed tool from helix to niri's chrome) and `niri-flake` (the compositor itself). Their authors target unstable on the assumption their consumers do too. Pinning the consumer to stable while the input tracks unstable invites option-name mismatches the consumer's lock can't catch until upgrade time. `home-manager`'s release is tied to nixpkgs's major number — any channel choice that diverges from home-manager's release line gets the same problem from a different direction.

The `flake-lock.yaml` workflow runs weekly (Mondays 04:00 UTC) and opens a PR rather than auto-merging. Green CI proves structural correctness (every host still builds); the manual merge is the forcing function for a brief eyeball on the per-input commit range URLs surfaced in the PR body. Cadence and channel are two sides of the same decision: a stable channel implies infrequent bumps with broad surface area; unstable implies frequent bumps with narrow surface area.

A residual `nixpkgs-stable` rev is present in `flake.lock` as a transitive consequence of `sops-nix`'s own `nixpkgs-stable` follower. It is not used by anything in this repo — only by sops-nix's internal testing surface — and is dragged along by `inputs.sops-nix.url`. Mentioned here so the lock's contents read truthfully; it is not a second channel this repo consumes.

## Decision

**Track `nixos-unstable`** on `inputs.nixpkgs.url`. Weekly cadence on `flake-lock.yaml` (Mondays 04:00 UTC), manual merge after green CI on the bump PR. No hybrid pin — every flake input that takes a `nixpkgs` follows `inputs.nixpkgs` (verified by the pattern `inputs.nixpkgs.follows = "nixpkgs";` repeated through `flake.nix`).

This is a decision-only landing — the configuration already implements it. The ADR exists to make the choice legible to a reviewer reading the repo cold and to anchor a migration trigger so the decision is revisitable rather than load-bearing-by-inertia.

## Rationale

**Why unstable over stable.** Stylix and niri-flake both target `nixos-unstable` upstream and ship option schemas tested against it. Pinning this repo to stable while the inputs track unstable creates a known failure category — option renames, removed defaults, schema drift — that the consumer's `flake.lock` can't paper over because the source-of-truth lives in the input flake's `nixpkgs`. Tracking unstable removes that category entirely. The cost is the inverse: home-manager option churn lands on this repo's CI rather than waiting for the next stable cycle. That cost is paid weekly in small increments under flake-lock CI gating rather than annually in a single stable-bump cliff, which is the failure mode the maturity-review explicitly flagged as worse.

**Why not stable.** `nixos-25.11` would be principled in a different repo. The deal-breakers here:

- **Stylix mismatch.** Stylix's master targets unstable; running stylix-on-stable would mean either cherry-picking Stylix to stable (defeating the point of a stable pin) or running an old Stylix tag that hasn't caught up with niri-flake's chrome surface (defeating the point of Stylix being source-of-truth).
- **Reduced freshness for agent-CLI tooling.** The day-to-day workflow leans on `claude-code`, `cursor`, `helix`, `nh`, and friends — packages whose unstable cadence delivers material fixes (not just version churn). Stable would lag these by months.
- **No materialised win.** The classical reason to choose stable is uptime-critical workloads on long-lived hosts. None of the three current hosts is uptime-critical in that sense; the headless dev host (mercury) and the desktop (metis) tolerate ~5-minute rebuilds with `nh os switch`, and the VM (nixos-vm) is a refinement target where breakage is the point.

**Why not hybrid (`nixpkgs` stable + `nixpkgs-unstable` overlay for hot packages).** A hybrid pin would add a second nixpkgs revision to reason about and force per-package "which channel does this come from?" decisions on every edit. The hybrid would earn its place if one or two specific packages were genuinely load-bearing for the workflow and a stable channel was otherwise the right default — but the previous bullet rules out the second condition. Two pins to maintain in service of zero on-stable packages.

## Consequences

- ✓ **No source-of-truth mismatch** between this repo and the flake inputs that themselves track unstable (Stylix, niri-flake). Option schemas line up; lock semantics line up.
- ✓ **Fresh agent-CLI and editor tooling** — fixes land at upstream cadence, not at stable's backport-and-pray cadence.
- ✓ **No quarterly stable-bump cliff.** Churn is distributed across weekly small bumps with named per-input commit ranges in each PR body — easier to debug a regression to a specific input than to a six-month range of stable changes.
- ✓ **Home-manager release alignment.** home-manager's master tracks nixpkgs master; staying on unstable keeps this repo's `home-manager.url` pointing at the matching release line without per-bump fixups.
- ✗ **Per-input upstream breakage lands on this repo's CI.** A home-manager option rename, a NixOS service whose defaults shifted, a `programs.X` upstream regression — each surfaces here before it would on stable. Weekly flake-lock CI is the mitigation: every bump is gated by every host building cleanly.
- ✗ **No "set and forget" stability.** Reviewing the weekly flake-lock PR is non-optional. Skipping it for ~a month and merging a backlog at once defeats the per-input attribution that makes regression diagnosis cheap.
- ⚠ **Migration trigger 1 — repeated Stylix breakage.** If a Stylix-master bump breaks two consecutive flake-lock PRs without an upstream fix landing in the same week, the trust assumption above (that Stylix's master is close enough to this repo's nixpkgs that breakage is rare and quickly fixed) is wrong. Revisit: pin Stylix to a specific stable rev, or switch the channel.
- ⚠ **Migration trigger 2 — Darwin lands.** macOS hosts via nix-darwin (epic #11) will introduce a fourth platform with its own release-line considerations. nix-darwin tracks nixpkgs's release branches; if the Darwin host's stability expectations differ materially from the Linux fleet, the right shape may be a per-host channel pin via flake-parts, not a fleet-wide one. Revisit at Darwin onboarding time.
- ⚠ **Migration trigger 3 — uptime-critical workload lands.** If any host onboards a workload where a broken `nh os switch` is materially costly (production service, long-running compute the operator doesn't want to lose), the unstable channel's "weekly small breakage" profile becomes the wrong default. Revisit per-host rather than fleet-wide. *Examined proactively for Mercury on 2026-06-09 — decision held (stay unstable); see §History.*

## Implementation

No code change. The configuration already implements this decision:

- **`flake.nix:5`** — `inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";`.
- **`flake.nix` repeated `inputs.<X>.inputs.nixpkgs.follows = "nixpkgs";`** — every input that takes a nixpkgs follows the single root pin.
- **`.github/workflows/flake-lock.yaml`** — weekly schedule (Mondays 04:00 UTC), opens a PR; merge is manual after green CI. See ADR-025's narrative for the rationale on manual merge.

Cross-reference: [ADR-025](./ADR-025-ci-in-flake.md) §Implementation (flake-lock workflow), [ADR-028](./ADR-028-stylix-foundation-and-desktop-env.md) §Consequences (the existing acknowledgement of the unstable risk for Stylix targets).

## History

### Per-host stable channel evaluated for Mercury — decision held (2026-06-09)

Prompted by the operator's intuition that long-lived hosts wanting predictable uptime — Mercury first (work-only headless AWS box), Metis later — might warrant `nixos-25.11` while only a future desktop stays on unstable. This is the per-host revisit that §Consequences "migration trigger 3" anticipated, examined proactively rather than on a costly workload actually landing.

**The evaluation upheld the original decision: stay on `nixos-unstable` fleet-wide.** What it changed is emphasis. §Rationale lists "reduced freshness for agent-CLI tooling" as one of several reasons against stable; it is in fact *the binding one*. Running the latest `claude-code`, `cursor`, `helix`, `nh` and peers at all times is why the fleet is on unstable, and Mercury — a work box that imports `agent-clis.nix` — is no exception. The uptime worry weighed against it needs no stable pin to address: `flake-lock.yaml` is manual-merge, each bump carries per-input attribution for triage, and break-glass is per-host (EC2 Instance Connect). A hybrid (stable base + unstable overlay for the agent CLIs) fails on the same logic the §Rationale "why not hybrid" already gives — once the tooling tracks unstable anyway, the cadence-decoupling that would justify a split collapses, leaving only its maintenance overhead.

Metis is explicitly not settled by this entry. Mercury is headless, so it sidesteps the Stylix/niri deal-breaker; Metis *is* the niri desktop, where a stable pin would reintroduce the Stylix-on-stable mismatch §Rationale rejects. If revisited it is a separate, harder decision — not a foregone extension of this one.
