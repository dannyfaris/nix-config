# Step-change review — four rounds of ambition-level ideation and the resulting program (2026-07-06)

Status: **point-in-time review artifact, not a decision.** Captured 2026-07-06 — an operator-requested ideation review by Claude (Fable 5), explicitly briefed to pursue step changes rather than incremental improvements, run as four successive passes with the operator directing continuation after each. **Deliberate scope exclusion at operator request:** documentation volume and process/ceremony weight were actively excluded from consideration; absence of commentary on those axes is not endorsement or critique. Method: per round, an evidence sweep of the flake, modules, docs corpus, and the full open-issue backlog (76 open issues at start), with load-bearing claims verified against the actual files before being asserted, at working tree `66f73c1` (then-current `main`) (the metis no-LUKS rationale, the tailscale `trustedInterfaces` posture, the niri.cachix trusted key, the migration-trigger census, the single-user posture on metis); candidate ideas were generated wide and killed hard — roughly half of round 3's candidates and three-quarters of round 4's did not survive the filter. Feeds: issues #551–#566 and #568–#572 (21 issues), each framed intent-first with an "open decisions" section and a /design-loop verdict, plus ~50 cross-reference comments wiring the new issues into the pre-existing backlog bidirectionally. Companion artifact: [engineering-review-2026-07-06.md](./engineering-review-2026-07-06.md), the same-day code-quality review — that one audits what exists; this one proposes what should.

## Executive summary

The review's central finding: **the declarative axis of this repo is essentially maxed out.** Five hosts built in CI, stances asserted at eval, a capability registry with generated docs and collision lints, weekly lockfile bumps, purity linters, a disciplined decision corpus. Further investment there yields polish, not level shifts. The step changes all live on adjacent axes the repo barely touches, and the four rounds each attacked one stratum:

1. **Operations** (#551–#555): the fleet deploys itself (pull-based GitOps with rollout rings), proves its own claims (stances generating eval checks, VM tests, and live probes from one datum), enforces its state discipline (ephemeral root), rehearses its recovery (scheduled resurrection drills), and gains a disposable virtual host class (microVM sandboxes).
2. **Boundaries** (#556–#561): the perimeter was found softer than the philosophy — the real firewall (tailnet ACLs) lives outside git, disks sit unencrypted on a trade-off TPM sealing has made obsolete, and SSH trust is heading toward an N×N static-key matrix. Plus: the desktop gets CI, mutable state gets a roaming tier, and the fleet gets an agent-queryable API.
3. **Metabolism** (#562–#566): the project's own decision loop gets automated — recorded migration triggers become machine-watched, the weekly bump arrives pre-diagnosed, the fleet becomes one logical store and its own CI engine, a chartered unattended maintainer drafts fixes for review, and the recovery path stops assuming GitHub exists at disaster time.
4. **Reflexive** (#568–#572): the program audits itself — the convergence autopilot built in rounds 1–3 is, unmitigated, a supply-chain delivery mechanism (#568 is its mandatory counterweight); the program's new automated loops (probes, rings, drills, canaries, pollers, mirrors, charters) need liveness monitoring because the fleet's alerting detects failure but not absence; and the two oldest conventions never promoted to boundaries (the work/personal split, the operator as single point of failure) get their promotion.

Four discoveries anchor the program in evidence rather than taste, and are worth restating because each was verified against the working tree:

- **The fleet's real network boundary is not in the repo.** `modules/nixos/tailscale.nix` records (per the #336 investigation) that tailscale's `ts-input` chain pre-empts the NixOS firewall — the actual gate is the tailnet ACL policy, which lives solely in the Tailscale admin console: unversioned, unreviewed, restorable by nobody. (#556)
- **metis's no-LUKS trade-off is obsolete technology.** `hosts/metis/disko.nix` trades encryption away for unattended boot after power loss; TPM2-sealed LUKS provides both at once. A physical, shared work+personal box holds its data in plaintext for a reason that no longer exists. (#557)
- **The corpus's tripwires have no watchers.** Two dozen ADRs (24 at capture) record ⚠ migration triggers, and `docs/philosophy.md` stakes the evergreen model on them — but ADR-006's atuin trigger ("multi-machine setup → reconsider") fired hosts ago and was noticed only by accident during this review. (#562, #560)
- **The autopilot widens the supply-chain blast radius.** Once #552/#564/#565 land, a malicious commit in any flake input converges to the whole fleet as root, hands-free, within the week — and the trust surface already includes a moving branch pin (noctalia `legacy-v4`), a third-party binary cache key (niri.cachix.org), and whole-repo `flake = false` inputs (homebrew taps). (#568)

## The program

Twenty-one issues, all labelled `roadmap`, all intent-first, none pre-deciding implementation. Design-loop verdicts are recorded per issue; the table gives the one-line intent.

### Round 1 — operations (#551–#555)

| # | Intent | /design |
|---|--------|---------|
| #551 | Stances as executable contracts: one registry generating eval assertions, CI VM tests, and live-host probes | Full note — registry shape is load-bearing for at least six later issues |
| #552 | Pull-based GitOps convergence: merge-to-main deploys the fleet through rollout rings | Full note — must reconcile with #419 (push model) and gate on #568 |
| #553 | Ephemeral root with an explicit persist whitelist — reprovision-from-source enforced, not asserted | Mandatory, heaviest — destructive failure mode; audit-first on-ramp |
| #554 | Scheduled resurrection drill: rehearse the nixos-anywhere bootstrap end-to-end in CI | Light note, scoped to secrets fidelity |
| #555 | Disposable declarative microVMs as flake outputs — isolation for agents and experiments | Note scoped to the isolation boundary (secrets/identity inside guests) |

### Round 2 — boundaries (#556–#561)

| # | Intent | /design |
|---|--------|---------|
| #556 | Tailnet ACLs as code — the real firewall under version control, stanced and probed | Full note — lockout failure mode; read-only-export on-ramp |
| #557 | TPM-sealed disk encryption + signed boot, metis first — the trust chain reaches silicon | Full note, heaviest of round 2 — brick risk; rehearse in VM first |
| #558 | Identity, not key lists — decide SSH CA / Tailscale SSH / static matrix before #524 ships the matrix | Mostly design loop; expect an ADR |
| #559 | The desktop gets CI — headless compositor tests, capability registry as executable spec | Medium note (registry schema + golden-frame flakiness policy) |
| #560 | The roaming layer — one policy tier for operator-following mutable state; ADR-006's atuin trigger has fired | Thin note — vocabulary + store inventory + identity semantics |
| #561 | An agent-operable fleet API — read-first MCP surface over live fleet state | Full note scoped to read/write boundary; sequences after #551/#552 |

### Round 3 — metabolism (#562–#566)

| # | Intent | /design |
|---|--------|---------|
| #562 | Executable migration triggers — machine-watch the corpus's recorded tripwires | Thin note — classification vocabulary + registry carrier (with #441) |
| #563 | One logical store — peer substitution, meshed remote builds, nix-native CI; dissolves #418 | Full note — trust topology + the CI-engine decision before #545–#547 |
| #564 | The bump arrives pre-diagnosed — canary builds, closure/CVE/size deltas in the PR | No standalone note; feeds #552's auto-merge decision |
| #565 | The repo gains a maintainer — chartered recurring agents, draft-PR output only | Scoped note on containment before the first unattended run |
| #566 | Rebuild the fleet without the internet — designed, drilled recovery self-sufficiency | Note scoped to dependency-chain analysis + the ADR-034 boundary |

### Round 4 — reflexive (#568–#572)

| # | Intent | /design |
|---|--------|---------|
| #568 | Supply-chain input trust tiers — the counterweight the convergence autopilot needs | Full note, sequenced before #552's auto-merge decision |
| #569 | The dead-man's layer — every automated loop declares a heartbeat; silence becomes signal | Thin note — registry shape + who watches the watchdog |
| #570 | The work/personal split gets a threat model — convention to enforced boundary on shared hosts | Full note, threat model first |
| #571 | Curation by evidence — a local-only, whitelisted usage ledger for tools and capabilities | Thin note, almost entirely the privacy stance |
| #572 | The bus-factor protocol — escrow + a successor runbook, drilled | Full note — custody/release design before any key material is duplicated |

## Structural observations

Three hubs emerged from the cross-linking pass itself, and they matter more than any single issue:

- **metis is becoming the fleet's load-bearing wall.** At least six program items want it as substrate: probe/report receiver (#551), sandbox hypervisor (#555), desktop-CI capacity via the runner leg (#559/#546), the build fabric's heavy-lifter and store server (#563), the recovery mirror (#566), plus the pre-existing homelab ambitions (#386/#387). Recommendation: arbitrate metis capacity once, inside #387's re-role design, rather than letting six issues each assume a slice of the same box. Note the concentration risk is also a security observation — the program stacks the fleet's brains on the one physical box #557 exists to encrypt.
- **#526 is quietly the fleet's key-custody keystone.** Five issues now defer their key stories to it: #557 (TPM-bound host keys), #558 (CA custody), #563 (fabric signing key), #566 (the surviving credential at network-dark recovery), #572 (the escrowed artifact). When #526 goes through design it is no longer a sops cleanup; it should be treated as the identity-architecture ADR.
- **#551's registry shape is the program's most depended-upon decision.** Direct consumers: #553 (state-audit probe), #556 (applied-vs-declared tailnet probes), #557 (encryption/secure-boot stances), #559 (rung 2 at pixels), #561 (probe results as API surface), #568 (binary-key whitelist stance), #554 (drill verification). Getting the `{description, eval assertion, runtime probe}` datum right is worth slow deliberation; getting it wrong is worth seven refactors.

Two decide-once collisions were flagged rather than resolved, deliberately: #552 (pull) vs #419 (push) is one decision with two open issues, and #558 explicitly counter-proposes #524's direction — both should be settled in their design notes before either side cuts code.

## Recommended prioritisation and sequencing

The dependency structure suggests waves, not a queue. Within each wave items can start independently (two intra-wave couplings are noted where they occur); across waves the ordering is load-bearing.

**Wave 0 — decisions before code (design notes only).** Three decisions gate everything and cost no implementation: the **#568 trust-tier note** (a hard prerequisite for #552's auto-merge — the autopilot must not ship before its counterweight is at least designed); the **#558 identity decision** (before #524 builds the key matrix it would replace); and the **#552 vs #419 pull/push reconciliation**. Add the **#551 registry-shape note**, because seven consumers hang off it.

**Wave 1 — cheap foundations with outsized trust returns.** Five items are small, independent, and each retires a whole class of risk: **#569** (the dead-man's layer — the best effort-to-trust ratio in the program; every later loop registers into it from birth); **#556's on-ramp** (export the tailnet ACL file read-only, diff weekly — drift visibility before enforcement); **#553's on-ramp** (the nightly state-audit probe, no destructive rollback yet); **#560's archetype** (atuin with self-hosted sync — the fired ADR-006 trigger answered, and the single largest daily quality-of-life win); and **#566's measurement step** (`nix flake archive` the current lock and weigh the recovery bundle — one command that sizes the whole idea).

**Wave 2 — the enforcement spine.** **#551** lands the registry with one template probe (sshd password-auth refusal) through all three rungs; **#554** lands the drill skeleton (which #557 and #566 will later reuse); **#559's walking skeleton** (boot metis headless, one golden frame) rides #551's machinery. After this wave, "set ≠ enforced" (#303's lineage) has its architecture landed and proven on one stance; coverage then accretes per ADR-032 proportionality.

**Wave 3 — the autopilot, safely.** **#552** ships rings with manual merge first, canary-only convergence, then widens; **#564** feeds it evidence; **#568's mechanics** (quarantine lags, range-diff sections) land alongside; auto-merge is the *last* switch flipped, not the first. **#563** proceeds in parallel once the #545–#547 engine decision is made — it improves the economics of everything but blocks nothing.

**Wave 4 — capstones and completions.** **#561** (fleet API) once #551/#552 emit things worth querying; **#565** (first charter: bump triage) once #564 gives it material and #569 watches it; **#555** (sandboxes) when agent autonomy or #570's mechanism demands it; **#557** (TPM/secure boot) after its VM rehearsal path exists via #554; **#553's destructive half** after a month of audit data; **#570/#571/#572** as their design notes mature — none blocks the others.

If forced to a top five by leverage alone: **#568** (the safety case for everything already logged), **#551** (the most depended-upon shape), **#569** (cheapest trust), **#552** (the operating-model change the rest orbit), **#556** (the largest honesty gain per unit effort).

A pacing note, offered plainly: this program is 21 issues deep on top of a 76-issue backlog with live desktop epics. The waves are deliberately front-loaded with cheap on-ramps so the program can be paused after any wave and still have paid for itself; and some issues *should* die in their design notes — that is the design loop working, not the program failing.

## Considered and rejected

Recorded so the filter is auditable, and so future sessions don't re-litigate: a unified fleet CLI (its query surface is #561's territory; its invocation surface the #442 palette); a central typed "fleet model" (contradicts the recorded no-central-platform-record stance from #541); runtime intrusion detection (disproportionate behind #556 + #551 + #553's audit); hedging against Nix itself (destroys the repo's value to insure it); property-based/formal verification (ADR-033 ruled it out on evidence); fleet-level boot auto-rollback (real, but already an open decision inside #552); observability dashboards as a standalone item (subsumed by #561's read surface and ntfy); generalising the repo as a template (contradicts PRD §2.2).

## Closing

Rounds were run to the point of diminishing returns by design, and the fourth round's candidates were mostly killed before presentation. The honest assessment at the end: with these 21 issues plus the pre-existing roadmap, the step-change space visible from the current vantage is exhausted — what remains is execution, and the program is structured so that execution itself (drills, probes, triggers, heartbeats) keeps generating the evidence that would reveal the next vantage.
