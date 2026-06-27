# The design loop — a disciplined, self-correcting loop for design work

**Status:** Proposed — design note (`docs/design/`). Describes how design work *should* move through this repo, especially in human + AI-agent collaboration. Its first-contact validation is the colour-conductor design note (§Validation).

## Problem & intent

**Intent.** A repeatable, legible loop for design work — one that produces honest, reproducible artifacts, self-corrects, and an AI agent can follow — so decisions are made well and recorded without drift.

**The problem (why this is needed).** The repo's own history shows a recurring failure mode, visible in its walk-backs: **documentation and abstraction run ahead of implementation.** Rules get asserted before their enforcement exists and are violated before the gate is built (the `bundle-purity` rule was contradicted by `foundation.nix` the day after it was written); docs drift from code and get "reconciled to reality" in arrears; abstractions are built on forecast and later torn out (the role layer, the `core/` tier). The loop *already* self-corrects — but reactively and by hand, paying for each mistake after the fact.

Underneath sits one structural cause: **a single artifact cannot be both a frozen design record and a living reference** — they demand opposite update disciplines, so blending them guarantees the "claims that don't hold" drift.

**The AI-collaboration amplifier.** Working with agents sharpens all of this. An agent under momentum skips exactly the *stated-but-unenforced* upfront steps — lead-with-intent, weigh-the-alternatives — and relies on the human to catch it (demonstrated, live, in §Validation).

**Intent, restated.** Move the loop's corrections from *reactive and manual* to *structural and up-front*; keep the artifact lifecycle honest (frozen ≠ living); and make each step *enforced*, not merely stated — in a form an agent reliably follows.

## Forces (what the loop must satisfy)

- **Intent-first** — design starts from the problem, never the solution.
- **Proportional** — design weight scales to blast-radius / reversibility; local, reversible work skips the heavy steps. (Guards the repo's *own* over-enforcement failure mode — e.g. a bespoke tokeniser guarding an aesthetic property.)
- **Honest artifacts** — frozen records stay frozen; living references describe only what exists; proposals are mutable and marked as such.
- **Enforced, not stated** — every step carries its mechanism, because a stated-but-unenforced step gets skipped (especially by an agent).
- **Self-validating** — the loop is itself a hypothesis: run it, reconcile from contact, revise.

## Options considered

- **Stay ad-hoc (no explicit loop).** Rejected — the history *is* the cost of this: the reactive walk-backs above.
- **Adopt a named methodology wholesale** (Shape Up, Scrum, the IETF/RFC process, Lean Startup). Rejected — the prior-art survey found no single framework covers the integrated whole, and none the human+AI version; importing a team-scale process whole would mis-fit a solo-operator-plus-agents context.
- **Assemble the loop from established disciplines + the genuinely-novel bits, enforcement-first.** **Chosen** — what the prior-art research recommends: rename and cite the parts; the assembly is the contribution.

## The loop

**Artifact lifecycle.** Frozen-to-run *research evidence* (`docs/research/`) → a mutable *design note / proposal* (`docs/design/`, **Proposed**) → on acceptance, a frozen *decision record* (ADR, `docs/decisions/`) **and** a present-tense *living reference*. Two status axes, never conflated: **Decision-state** (proposed → accepted → superseded) and **Build-state** (none → sliced → complete).

**Stages** — each names its established antecedent → and its *enforcement*:

1. **Intent** — frame the problem and objective first. *(workflow.md intent-first → enforced by the design-note template: a mandatory Problem section.)*
2. **Size** — blast-radius / reversibility triage; heavy design for irreversible/cross-cutting, just-build for local/reversible. *(Fairbanks risk-driven + Bezos two-way-doors → enforced by the size gate.)*
3. **Design** — the design note: intent → forces → options weighed → decision. *(The software-RFC form → enforced by the template + the peer-review checklist.)*
4. **De-risk** — test the load-bearing assumption before building. *(Fairbanks step 1 → enforced by a required de-risk pass for heavy items.)*
5. **Build** — the thinnest valuable slice; commit an abstraction only with a real consumer. *(Lean Startup MVP + YAGNI → enforced by review.)*
6. **Peer-review** — an independent reviewer before commit. *(workflow.md → already enforced; earns its keep.)*
7. **Reconcile** — the living-reference update lands in the *same change* as the code; the status axes advance. *(Diátaxis "reference led by the product" → enforced by review + the docs-with-code rule.)*

The spine for the AI-collaborative version is **co-locate a rule with its enforcement** — because the unenforced steps are precisely the ones an agent skips (§Validation).

## Prior art

Most of the loop's distinctive moves map to named disciplines — risk-driven design (Fairbanks), reversibility / two-way-doors (Bezos), ADRs (Nygard), Diátaxis (Procida), MVP / Build-Measure-Learn (Ries). Genuinely under-served / ours: the **separation** of frozen-record vs living-reference into distinct artifacts, the **two-axis status**, **co-locate-rule-with-enforcement**, and the **integrated, human+AI** loop. Full map + sources: [`../research/design-loop-prior-art.md`](../research/design-loop-prior-art.md).

## Validation — first contact (the colour-conductor run)

The loop's first real run was the [colour-conductor design note](./colour-conductor.md). Scorecard:

- **Held:** de-risk-first + prior-art (the load-bearing assumptions were retired before committing to a design); the artifact separation (we created `docs/design/` as the proposed-design home, distinct from ADRs and research); reconcile (three versions, each correcting a drift) — but via *human* review.
- **Broke:** intent-first and weigh-alternatives — the agent wrote the design solution-first, with no problem statement and no options weighed; caught only by the operator.
- **The validated lesson:** the steps that broke were the *stated-but-unenforced* ones — direct evidence for *co-locate-rule-with-enforcement*, and for the human+AI thesis that **every unenforced step is skipped by the agent and leans on the human to catch it.** The organic fix (the `docs/design/README` conventions + a peer-review that checks for intent and options) is that principle applied.

## Open items / refutation criteria

- **Build the enforcement, per step** — the design-note template, the size gate, the de-risk-pass requirement, the reconcile-in-same-change rule, a claims audit. By the loop's own *co-locate-rule-with-enforcement* principle, *stating* these here is not enough; the next phase encodes them into `CLAUDE.md` + skills so the agent follows them.
- **Refute the loop if:** reconcile gets routinely skipped under time pressure; the frozen/living artifact split costs more bookkeeping than the drift it prevents; or the size gate collapses to "everything is high-stakes."
- **Unrun prior-art questions** (`../research/design-loop-prior-art.md` §6): is *co-locate-rule-with-enforcement* a rename of poka-yoke / "build quality in"? is the two-axis separation named anywhere? does Tessl's "living spec" cover the frozen-vs-living separation?

## Relationship to existing practice

Not greenfield: [`../workflow.md`](../workflow.md) already carries intent-first, doc-before-code, and peer-review; [ADR-032](../decisions/ADR-032-proportionate-enforcement-and-rationale.md) (proportionate enforcement) and [ADR-033](../decisions/ADR-033-eval-checks-stances-and-lib-units.md) (deliberate stances as eval-checks) are existing instances of *co-locate-rule-with-enforcement*. The loop **names, integrates, and extends** these — adding the artifact-lifecycle separation and the enforcement-first spine for working with agents.
