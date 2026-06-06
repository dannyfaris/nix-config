# ADR-032: Proportionate enforcement and single-sourced rationale

**Date**: 2026-06-06
**Status**: Accepted, Implemented

> This ADR turns the repo's own proportionality principles — [philosophy.md](../philosophy.md) "No premature abstraction" and "Single source of truth" — inward, onto the repo's *meta-layer*: its enforcement machinery (linters, CI guards) and its rationale prose (comments, docs). It adds no new architecture; it constrains how that meta-layer is allowed to grow. Precedent: [ADR-027](./ADR-027-foundation-and-bundles.md) walked back an over-built abstraction once it had data; this generalises the same instinct to guardrails and documentation.

## Context

A maturity review (2026-06-06) scored architecture, Nix correctness, and security highly, but marked two axes lower: **proportionality** and **maintainability**. Both trace to one root. The repo applies its proportionality principles rigorously to *config data and code* — the operator record, host palettes, and the `statix.toml`-derived auto-gen list are all single-sourced; `lib/mk-host.nix` and the foundation/bundle model avoid speculative abstraction — but it does **not** apply those same principles to its own meta-layer. Two patterns recur:

- **Enforcement heavier than the severity it guards.** `scripts/lint-bundle-purity.sh` is a ~140-line bash reimplementation of a Nix-AST shape check — it shells out to `nix-instantiate --parse`, then hand-rolls a paren-depth tokeniser and a duplicate-entry detector. It guards an aesthetic/idempotent property — an inline setting in a bundle still *works*; duplicate imports in Nix are idempotent, not a correctness bug — at a cost larger than the property's severity. The CI transient-retry step (`.github/workflows/ci.yaml`) is a 19-branch stderr regex that is brittle in both directions: it can mask a real failure whose log happens to match, and miss a transient signature it doesn't enumerate.
- **Rationale living in more than one place.** `modules/darwin/homebrew.nix` carries a ~120-line per-cask update-behaviour essay — in an otherwise 300-line, mostly-comment module — whose content duplicates the per-tool `docs/desktop/*.md` files the same module already points to line-by-line. The same "why" therefore lives inline *and* in a doc (and sometimes an ADR). That duplication is precisely where the review found drift: a dangling `TODO` reference in PRD §2.2 (the file was retired in `8f7b424`) and `docs/desktop/` entries marked "pending" that are actually complete.

Each individual mechanism was built deliberately and works. The problem is aggregate: the meta-layer is the one part of the repo exempt from the repo's own restraint, and it is the part most prone to silent staleness.

## Decision

Adopt two evergreen rules, both framed as the existing proportionality principles applied to the meta-layer.

**Rule 1 — Proportionate enforcement.** Enforcement machinery earns its weight by the severity of what it guards. Prefer the lightest mechanism that holds the guarantee, escalating only when a lighter rung demonstrably fails:

> convention → reviewer/agent attention → `grep`-class lint → an upstream-provided check → bespoke parser/harness

Reserve mechanical *gates* for correctness-severity issues (platform leakage, secret exposure, build breakage). Do not gate aesthetic or idempotent properties. **A guardrail that needs a bespoke parser or tokeniser to do its job is a smell** — the mechanism is too clever; simplify it until a grep-class check (with at most a few fixtures) suffices, or downgrade the rule to a convention.

**Rule 2 — Single-sourced rationale.** "Single source of truth" governs prose, not only data. Where a rationale lives is tiered by its length:

- **Inline comment** — the *why of this one setting*, ≤ ~3 lines.
- **Anything longer** — a decision with alternatives, a multi-host or multi-app matrix, multi-step reasoning — lives in exactly **one** canonical home (an ADR, or a `docs/<area>/*.md`), and the code carries a one-line pointer to it.
- **No rationale paragraph appears in more than one place.** Secondary surfaces (CLAUDE.md, philosophy.md, README) carry one-liners and pointers, never restatements.

This ADR is bound by its own Rule 2: it is the canonical home for these two rules, and the evergreen surfaces will point here rather than restate. It is kept deliberately short for the same reason.

## Rationale

**Why a corollary, not a seventh principle.** Rule 1 applies the YAGNI instinct behind "No premature abstraction" to guardrails — build the gate before there's evidence you need it and you've paid for an abstraction speculatively — and leans on "Tight from the start" for its anti-staleness half (a stale essay is the "TODO: refactor later" that principle forbids). Rule 2 extends "Single source of truth" from data to prose; philosophy.md's own closing bullet already makes `docs/` canonical and has other surfaces point rather than duplicate. What is *new* here is not either principle but their operationalisation — the length-tiering that fixes *where* a given rationale must live. Minting fresh axioms to describe existing ones would inflate a list the repo deliberately keeps at six; recording these as applications keeps the philosophy honest and stable.

**Why not just leave it.** The drift is observed, not hypothetical, and it compounds: without a written rule, every refactor regrows. The `homebrew.nix` essay returns on the next cask; the next convention that feels worth enforcing spawns the next bespoke linter. The rule is the thing that makes a one-time cleanup durable — exactly the doc-before-code ordering `docs/workflow.md` already mandates.

**Why this is relocation, not reduction.** Those high scores came *from* rigor — applied to data. Nothing here removes that. Rule 1 explicitly keeps the load-bearing guards (`lint-shared-purity.sh` is pure `grep` against a genuine silent bug; it stays). Rule 2 deletes no knowledge — it moves rationale into the one place the taxonomy already designates as canonical. The goal is right-sizing and single-sourcing, not less documentation.

**The cost is judgment.** A reflexive "always build the gate" needs no thought; "which rung is enough?" does. Tie-breaker: **when unsure, choose the lighter mechanism and let a real, repeated failure justify escalation.** Escalating after evidence is cheap; tearing out an over-built gate after the fact is the churn this ADR exists to prevent.

## Consequences

- ✓ Lower maintenance surface: fewer bespoke mechanisms that can break on a transitive upstream change (e.g. `nix-instantiate --parse` output format) in hard-to-debug ways.
- ✓ Rationale has a single home, so drift becomes a single-source-of-truth violation — visible, and cheaply CI-checkable with a link/path checker rather than vigilance.
- ✓ Modules read as configuration, not essays; a reviewer sees the whole module on one screen.
- ✓ The repo's existing rigor is preserved exactly where it is load-bearing (correctness-severity gates, data single-sourcing) and trimmed only where it is not.
- ✗ Requires per-case judgment ("which rung?") that a reflexive gate-everything stance avoided. Mitigated by the documented tie-breaker.
- ✗ A rule downgraded from gate to convention can be violated without CI catching it. Accepted for aesthetic/low-severity rules; **not** for correctness ones, which stay gated.
- ✗ Relocating inline essays into docs is a one-time churn cost spread across several modules.
- ⚠ **Migration trigger — a convention proves insufficient.** If a convention-not-gate rule is violated in practice across ≥ 2 PRs (e.g. bundles repeatedly accrue inline config), that is the evidence Rule 1 asks for: re-escalate to the lightest mechanism that holds.
- ⚠ **Migration trigger — the contributor model changes.** The cost/benefit of mechanical gates is computed for a single operator plus agents. If external contributors arrive, the value of gates rises; revisit which conventions deserve promotion.

## Implementation

Decision-only landing, per `docs/workflow.md` doc-before-code. This ADR is the canonical record; each item below is a separate peer-reviewed PR that cites it. Landing this ADR also adds its own row to the `docs/decisions/README.md` index (and backfills the ADR-031 row, currently missing).

1. **Evergreen pointers** (next, this initiative): one-liners in `CLAUDE.md` §Conventions; a `§"Rationale lives in one place"` section in `docs/workflow.md`; the enforcement-weight corollary appended to "No premature abstraction" in `docs/philosophy.md`. Pointers only — no restatement (Rule 2).
2. **`modules/darwin/homebrew.nix`** — relocate the per-cask essay into the existing `docs/desktop/*.md`; the module keeps the per-line pointers it already has.
3. **`scripts/lint-bundle-purity.sh`** — simplify (drop the paren-tokeniser and the duplicate-entry detector, which guard an idempotent non-issue) or downgrade to a convention; remove its self-test harness for whatever survives. `lint-shared-purity.sh` (grep) is unaffected.
4. **`.github/workflows/ci.yaml`** — replace the 19-branch transient regex with a bounded *blind* retry on the `fetchGit`-prone step (the failure class `ci.yaml` itself documents `download-attempts` does **not** cover), using Nix's `download-attempts` only for the HTTP-fetch subset it does cover.

A separate doc-hygiene pass — not part of this ADR — reconciles the stale PRD §2.2 `TODO` reference and the inaccurate "pending" markers in `docs/desktop/`.

Cross-reference: [philosophy.md](../philosophy.md) ("No premature abstraction", "Single source of truth"); [ADR-027](./ADR-027-foundation-and-bundles.md) (precedent — walking back an over-built abstraction on data); [ADR-025](./ADR-025-ci-in-flake.md) (the lint + CI framework items 3–4 touch).

## History

### Implemented (2026-06-06)

All four Implementation items landed: #285 (the ADR itself plus item 1, the evergreen pointers), #286 (item 2, homebrew essay relocation), #287 (item 3, lint-bundle-purity narrowed to the shape check — Option A "lean gate"), #288 (item 4, CI blind retry). The separate doc-hygiene pass (this entry's PR) then reconciled the stale PRD §2.2 `TODO` reference and the `docs/desktop/` "pending" markers.

The four `PRD §8.1 #4` cross-references inside [ADR-027](./ADR-027-foundation-and-bundles.md)'s §History/Consequences narrative were considered and **deliberately left**: they are period-accurate (bundle-purity occupied row #4 when those dated entries were written; it later renumbered to #3), and one of them refers to the long-removed `role-purity` rule that genuinely was #4. Renumbering them would falsify the historical record rather than fix a live pointer — the live pointers were corrected in #287.
