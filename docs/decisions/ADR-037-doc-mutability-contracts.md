# ADR-037: Documentation mutability contracts — facts as code, reasons as prose

**Date**: 2026-06-16
**Status**: Accepted, Implementation pending

> Classifies every documentation artifact — including the CLAUDE.md guidance files — by what would make it *wrong*, and routes content to a home that can defend it: mechanical facts to generated/checked code, reasons to single-sourced prose, a decision's lifecycle to the issue tracker, only load-bearing *why* to a frozen ADR. Applies [ADR-033](./ADR-033-eval-checks-stances-and-lib-units.md)'s eval-check instinct to documentation facts and [ADR-032](./ADR-032-proportionate-enforcement-and-rationale.md)'s single-sourcing to the prose that remains. Bound by ADR-032 Rule 1: only the grep-class lint rung is committed up front; heavier enforcement waits on evidence.

## Context

The corpus is 35 ADRs, the root CLAUDE.md, ~6 reference docs, and ~35 desktop selection docs. Implemented ADRs are immutable historical record by convention; everything else is mutable prose with no contract. #338 lists ~10 drifts, and every mechanical one is a fact the flake already knows — the host roster (CLAUDE.md §Structure omits the Darwin axis), an import fact (tailscale.md still says mercury doesn't import Tailscale, false since #205), a file location (foot.md names the wrong stylix-targets file), a doc restating an issue's status ("pending #58", long landed). ADR-032 fixed where rationale lives; ADR-033 proved a CLAUDE.md table can be an eval-check. Neither lets the corpus tell a frozen why from a fact from a decision-in-flight from living guidance — so all four rot alike, and #338 was a manual discovery, not a prevention.

## Decision

Classify every documentation artifact by what would make it wrong, and give each class a home and an anti-staleness mechanism:

1. **Frozen — the why.** ADRs, immutable once their decision is Implemented (lands in code); revisable plan-state while Proposed / Implementation-pending, per [§README](./README.md). A dated, implemented decision can't go stale.
2. **Tracked — a decision's lifecycle.** The issue tracker is canonical for a decision as it forms and for its status, threaded commentary, and dependency graph — all native there, and all of which lie the moment they're hand-mirrored into prose. A closed issue with a rationale comment is a lightweight decision record. **Promotion rule (forward-looking):** only a load-bearing, cross-cutting decision graduates to a frozen ADR; a tool or tactical choice stays a labelled closed issue plus a one-line selections-register row. Existing selection ADRs 001–008 are unchanged — the rule governs only what's written next.
3. **Generated — the facts.** Host roster, structure tree, host×capability matrix, selections register, and the structural/pointer content of CLAUDE.md files: derived from flake eval / the filesystem, emitted into marked blocks, CI-diffed, never hand-edited. A new application of ADR-033's eval-check mechanism; no such generator exists today, so it is adopted on evidence (§Enforcement).
4. **Living — the guidance.** philosophy.md, workflow.md, taxonomy.md, runbooks, the desktop selection docs, and the hand-written guidance prose in CLAUDE.md files. Mutable, single-sourced per ADR-032 Rule 2.

**Governing rule — facts to code, reasons to prose.** A line stating a *what / where / whether* is a fact: generate or check it. A line stating a *why* is a reason: a frozen ADR or single-sourced living prose. **A document that mixes the two is split, not filed whole** — the instinct of [ADR-023](./ADR-023-host-config-three-file-structure.md)'s three-file host structure. Two worked examples: the **PRD** (product intent is Living, current-state status is Tracked, file-tree facts are Generated — which is why #338 finds it self-contradicting), and **CLAUDE.md** (below).

**CLAUDE.md decomposition (in scope).** CLAUDE.md is essential, must-maintain documentation and rots like any other (the #338 §Structure drift is the proof). It is a mixed artifact and splits accordingly:

- **Nested, conditional on justification — not blanket.** The root CLAUDE.md keeps only universal guidance; a directory gets its own CLAUDE.md only where it earns one (hand-written guidance present, a composition boundary, or an inventory worth summarising) — whitelist > blanket. A directory that doesn't justify one isn't isolated; its files roll up into the parent's generated inventory, so coverage stays complete without per-leaf rot surface, and the set self-prunes as directories change.
- **Machine-owned structure, human-owned guidance, separated non-destructively.** Each file's structure and pointers are a generated, CI-checked region; its guidance prose is hand-written (Living). The two are separated non-destructively — the generator never touches the guidance (mechanism: marked regions, splice-not-rewrite, in the implementation issue) — and the generation plus checks land *with* the decomposition, not after, so these files are never hand-maintained (an un-automated or blanket stub would itself be the rot surface this ADR exists to prevent). This ADR records only the contract; mechanism and open parameters are tracked in the implementation issue.

## Enforcement

A menu, adopted lightest-first per ADR-032 Rule 1.

**Committed now — grep-class doc lints** (justified by #338): cited file paths exist; relative / ADR / issue links resolve (in docs *and* CLAUDE.md files); every `docs/desktop/*.md` is indexed. Catches the mechanical half of #338 at the lightest rung.

**Adopted on evidence:**

- **Eval assertions** — a doc capability claim equals `config`; every module imported by ≥1 host; `host-palettes` ↔ host parity. Adopt if a fact the lint can't express re-drifts.
- **Generation of currently hand-written facts** (the structure tree, the capability matrix, via `nix build .#docs`, CI-diffed) — adopt only if those facts keep drifting after the lints land. #338 is evidence for the lint, not for a generator.
- **Behavioural coverage for the *set ≠ enforced* gap** — VM tests (#303, NixOS) and macOS verification (#345, where `runNixOSTest` can't reach), per stance.

**One case is committed, not triggered:** the nested-CLAUDE.md decomposition co-lands with its generator (rung 3). Decomposing *creates* new fact-bearing files, and hand-maintaining them is guaranteed drift — not a risk to wait on. Generation-before-evidence stays forbidden for *existing* docs; for *newly-created* fact surface, the generator is the precondition for creating it at all.

## Rationale

**Why classify by failure-mode.** The corpus sorts by *topic* (decisions / desktop / runbooks), which says nothing about *how a doc rots*. "What would make this wrong?" routes each line to the mechanism that can defend it — a code change → a check; a new decision → a frozen record; nothing → leave it. A topic-pile can't answer that, which is why #338 accreted.

**Why the tracker for decisions.** Recording a decision's lifecycle as prose duplicates what the tracker maintains natively and lies the moment the issue moves. Reserving ADRs for load-bearing *why* shrinks the corpus a reader must hold and halts ADR-count growth at the tool-selection tier — directly addressing the "too many ADRs" concern that motivated this.

**Why CLAUDE.md is in scope.** It is the highest-traffic AI-facing documentation and already a demonstrated drift source (#338); excluding it would exempt the most-read doc from the contract.

**Why so little is committed.** An anti-staleness ADR that mandated a `nix build .#docs` generator for the existing corpus before evidence would violate the very Rule 1 it leans on. The grep-lint rung is justified by #338 today; every heavier rung for existing docs waits for its own evidence. (The nested-CLAUDE.md generator is the lone exception, and only because it gates the *creation* of new files — see §Enforcement.)

## Consequences

- ✓ Staleness becomes a CI signal at the introducing commit, not a periodic manual discovery.
- ✓ "What's true now?" trends toward one checked/generated artifact, not 35 files minus a supersession filter.
- ✓ Mechanical facts can't be hand-typed wrong once their lint/generator lands.
- ✓ Decisions carry native status, commentary, and dependencies; no doc lies about an issue's state.
- ✓ The most-read AI-facing docs (CLAUDE.md) get the same anti-rot contract.
- ✓ Conditional inclusion keeps the nested-CLAUDE.md set proportionate (whitelist > blanket) and self-pruning, while parent-rollup keeps coverage complete.
- ✓ Reuses ADR-032 (single-sourcing) and ADR-033 (eval-checks); only the doc-lint rung is net-new now.
- ✗ The facts-vs-reasons split is per-line judgment at the margin. Tie-breaker: if a config change could falsify the line, it's a fact.
- ✗ Routing decisions to the tracker assumes the tracker stays the durable home (accepted: issues are durable in practice, and load-bearing decisions promote to ADRs anyway).
- ✗ Existing selection ADRs 001–008 persist under a now-closed convention — a harmless old/new inconsistency, noted with a one-line index pointer, no reorganization.
- ✗ Nested CLAUDE.md adds files — bounded by conditional inclusion and kept honest only because structure/pointers are automated and self-pruned; an un-automated or blanket-per-directory stub would itself be rot surface (the reason generation must land *with* the decomposition).
- ⚠ Trigger — the tracker ceases to be the canonical decision home (e.g. a move off GitHub): re-home the Tracked class; revisit the promotion rule.
- ⚠ Trigger — hand-typed facts keep drifting after the lint rung: escalate to eval assertions, then generation, per the menu.
- ⚠ Trigger — the contributor model changes (external contributors): the value of generated/checked facts rises; adopt heavier rungs sooner.

## Implementation

Decision-only landing per [docs/workflow.md](../workflow.md) doc-before-code; each rung is a separate peer-reviewed PR citing this ADR:

1. **Evergreen pointers** (this initiative): a `§Documentation contracts` one-liner in the root CLAUDE.md and a pointer from [docs/README.md](../README.md) (Rule 2 — pointers, not restatement). philosophy.md points here; it is not edited to restate.
2. **Doc lints** (justified by #338): grep-class cited-path / link / index checks wired into `parts/checks.nix` beside the purity lints.
3. **Nested CLAUDE.md decomposition** with its generation + checks landing together — conditional inclusion, non-destructive generated regions, self-pruning. Design and open parameters tracked in the implementation issue.
4. **Heavier rungs for existing docs** (eval assertions, full `nix build .#docs`, VM/macOS behavioural tests) deferred to their own evidence.

The narrative half of #338 (the PRD's CI self-contradiction, the orphaned "Tier-N" vocabulary) is genuine prose drift, reconciled by the existing #338 sweep, not this ADR.

Cross-reference: [ADR-032](./ADR-032-proportionate-enforcement-and-rationale.md) (single-sourced rationale + proportionate enforcement), [ADR-033](./ADR-033-eval-checks-stances-and-lib-units.md) (eval-checks — the facts-as-checks precedent), [ADR-025](./ADR-025-ci-in-flake.md) (the in-flake CI framework the lints/generation extend), [ADR-023](./ADR-023-host-config-three-file-structure.md)/#128 (the auto-gen-paths config-single-sourcing lineage), [philosophy.md](../philosophy.md); issues #338 (the evidence), #303 / #345 (the behavioural-coverage rung).
