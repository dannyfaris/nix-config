# The design loop — a disciplined, self-correcting loop for design work

**Status:** Proposed — design note (`docs/design/`). Enforcement partly encoded (the design-note template, the `/design` skill + peer-review checklist, and the `design-note-structure` presence lint; the size gate and a claims-audit are still open). Describes how design work *should* move through this repo, especially in human + AI-agent collaboration; mutable by design. Its first-contact test is the colour-conductor design note (§De-risk evidence).

## Summary

A repeatable, enforcement-first loop for how design work moves through this repo — frozen research evidence → a mutable proposal → on acceptance a frozen decision record *and* a living reference. It is assembled from established disciplines (risk-driven design, two-way-doors, ADRs, Diátaxis, MVP) plus a few genuinely-novel moves — the frozen-record-vs-living-reference *separation*, the two-axis status, and *co-locate-rule-with-enforcement* — and is built to be followed by an AI agent, not just a human. The loop is itself a hypothesis under test.

## Motivation

The repo's own history shows a recurring failure mode, visible in its walk-backs: **documentation and abstraction run ahead of implementation.** Rules get asserted before their enforcement exists and are violated before the gate is built (the `bundle-purity` rule was contradicted by `foundation.nix` the day after it was written); docs drift from code and get "reconciled to reality" in arrears; abstractions are built on forecast and later torn out (the role layer, the `core/` tier). The loop *already* self-corrects — but reactively and by hand, paying for each mistake after the fact.

Underneath sits one structural cause: **a single artifact cannot be both a frozen design record and a living reference** — they demand opposite update disciplines, so blending them guarantees the "claims that don't hold" drift.

Working with agents sharpens all of this. An agent under momentum skips exactly the *stated-but-unenforced* upfront steps — lead-with-intent, weigh-the-alternatives — and relies on the human to catch it (demonstrated, live, in §De-risk evidence).

**Forces — what the loop must satisfy:**

- **Intent-first** — design starts from the problem, never the solution.
- **Proportional** — design weight scales to blast-radius / reversibility; local, reversible work skips the heavy steps. (Guards the repo's *own* over-enforcement failure mode — e.g. a bespoke tokeniser guarding an aesthetic property.)
- **Honest artifacts** — frozen records stay frozen; living references describe only what exists; proposals are mutable and marked as such.
- **Enforced, not stated** — every step carries its mechanism, because a stated-but-unenforced step gets skipped (especially by an agent).
- **Self-validating** — the loop is itself a hypothesis: run it, reconcile from contact, revise.

**Intent, restated:** move the loop's corrections from *reactive and manual* to *structural and up-front*; keep the artifact lifecycle honest (frozen ≠ living); and make each step *enforced*, not merely stated — in a form an agent reliably follows.

## Design

**Artifact lifecycle.** Frozen-to-run *research evidence* (`docs/research/`) → a mutable *design note / proposal* (`docs/design/`, **Proposed**) → on acceptance, a frozen *decision record* (ADR, `docs/decisions/`) **and** a present-tense *living reference*. Two status axes, never conflated: **Decision-state** (proposed → accepted → superseded) and **Build-state** (none → sliced → complete).

**Stages** — each names its established antecedent → and its *enforcement*:

1. **Intent** — frame the problem and objective first. *(workflow.md intent-first → enforced by the design-note template: a mandatory Summary + Motivation before any Design.)*
2. **Size** — blast-radius / reversibility triage; heavy design for irreversible/cross-cutting, just-build for local/reversible. *(Fairbanks risk-driven + Bezos two-way-doors → enforced by the size gate.)*
3. **Design** — the design note: intent → forces → options weighed → decision. *(The software-RFC form, adapted → enforced by the template + the peer-review checklist.)*
4. **De-risk** — test the load-bearing assumption before building. *(Fairbanks step 1 → enforced by a required De-risk-evidence section for heavy items.)*
5. **Build** — the thinnest valuable slice; commit an abstraction only with a real consumer. *(Lean Startup MVP + YAGNI → enforced by review.)*
6. **Peer-review** — an independent reviewer before commit. *(workflow.md → already enforced; earns its keep.)*
7. **Reconcile** — the living-reference update lands in the *same change* as the code; the status axes advance. *(Diátaxis "reference led by the product" → enforced by review + the docs-with-code rule.)*

The spine for the AI-collaborative version is **co-locate a rule with its enforcement** — because the unenforced steps are precisely the ones an agent skips (§De-risk evidence).

**The reconcile hypothesis.** Reconcile (stage 7) is the loop's least-established rung, so it carries its own hypothesis. It has a *direction* — code → reference: the living reference follows what the product does, never the reverse (Diátaxis "reference led by the product"); a *timing* — same-change: the reference update ships in the commit that changes the behaviour, not in arrears; and an *enforcement ladder*, strongest-first: **generate** the reference from the source where possible (the keybinds table generated from the registry, #457, is the live precedent), else a **claims-audit** that checks the reference against reality, else **review** remembering to update the doc. The falsifiable claim is *review-only reconcile drifts* — the repo's recurring "reconcile to reality" commits are the evidence that the weakest rung is insufficient where the stakes warrant a stronger one.

## De-risk evidence

The load-bearing assumption is the human+AI thesis: **every unenforced step is skipped by the agent and leans on the human to catch it.** The loop's first real run — the [colour-conductor design note](./colour-conductor.md) — tested it. Scorecard:

- **Held:** de-risk-first + prior-art (the load-bearing assumptions were retired before committing to a design); the artifact separation (we created `docs/design/` as the proposed-design home, distinct from ADRs and research); reconcile (three versions, each correcting a drift) — but via *human* review.
- **Broke:** intent-first and weigh-alternatives — the agent wrote the design solution-first, with no problem statement and no options weighed; caught only by the operator.
- **The validated lesson:** the steps that broke were the *stated-but-unenforced* ones — direct evidence for *co-locate-rule-with-enforcement*, and for the thesis above. The organic fix (the `docs/design/README` conventions + a peer-review that checks for intent and options) is that principle applied.

**Still unverified:** the encoded enforcement now *exists* (template + `/design` skill + structure lint), but whether it actually stops the skip is untested — the skill is user-invoked, so its first real run is the next test of the spine. Encoding is not efficacy.

## Drawbacks

Why one might not formalise a loop at all:

- **Process weight on a solo hobby repo.** A named loop is ceremony; the repo's own `philosophy.md` warns against premature structure, and an over-heavy loop is the same failure mode it claims to guard.
- **The artifact split costs bookkeeping.** Maintaining frozen-record-and-living-reference as *two* artifacts is more upkeep than one blended doc — justified only if the drift it prevents costs more.
- **Enforcement is work.** *Co-locate-rule-with-enforcement* means every rule must ship a mechanism; that raises the bar for adding a rule at all.

## Cost

The accepted standing price: an **enforcement-build tax** — by the loop's own spine, a new rule is not "done" when stated; it ships with a template slot, a lint, a checklist item, or a skill. That tax is the point (it is what makes the loop self-correcting up-front), but it is a real, recurring cost on every future rule.

## Rationale & alternatives

- **Stay ad-hoc (no explicit loop).** Rejected — the history *is* the cost of this: the reactive walk-backs in Motivation.
- **Adopt a named methodology wholesale** (Shape Up, Scrum, the IETF/RFC process, Lean Startup). Rejected — the prior-art survey found no single framework covers the integrated whole, and none the human+AI version; importing a team-scale process whole would mis-fit a solo-operator-plus-agents context.
- **Assemble the loop from established disciplines + the genuinely-novel bits, enforcement-first.** **Chosen** — what the prior-art research recommends: rename and cite the parts; the assembly is the contribution.

**Impact of doing nothing:** the reactive walk-backs continue — rules asserted before enforcement, docs reconciled in arrears, abstractions built on forecast and torn out — each paid for after the fact.

## Prior art

Most of the loop's distinctive moves map to named disciplines — risk-driven design (Fairbanks), reversibility / two-way-doors (Bezos), ADRs (Nygard), Diátaxis (Procida), MVP / Build-Measure-Learn (Ries). Genuinely under-served / ours: the **separation** of frozen-record vs living-reference into distinct artifacts, the **two-axis status**, **co-locate-rule-with-enforcement**, and the **integrated, human+AI** loop. Full map + sources: [`../research/design-loop-prior-art.md`](../research/design-loop-prior-art.md).

Within this repo, the loop is not greenfield: [`../workflow.md`](../workflow.md) already carries intent-first, doc-before-code, and peer-review; [ADR-032](../decisions/ADR-032-proportionate-enforcement-and-rationale.md) (proportionate enforcement) and [ADR-033](../decisions/ADR-033-eval-checks-stances-and-lib-units.md) (deliberate stances as eval-checks) are existing instances of *co-locate-rule-with-enforcement*. The loop **names, integrates, and extends** these.

## Unresolved questions

- **Build the enforcement, per step.** *Landed:* the design-note template, the `/design` skill + peer-review checklist, the `design-note-structure` presence lint (with its own fixture self-test), and the CLAUDE.md pointer. *Still open:* the size gate, an explicit de-risk-pass requirement, and a claims audit. By the loop's own *co-locate-rule-with-enforcement* principle, *stating* the remainder is not enough — each encodes into the `/design` skill + checks as evidence warrants, not on spec.
- **Refute the loop if:** reconcile gets routinely skipped under time pressure, *or* review-only reconcile turns out *not* to drift (making the enforcement ladder above review unnecessary); the frozen/living artifact split costs more bookkeeping than the drift it prevents; or the size gate collapses to "everything is high-stakes."
- **The design-note → ADR graduation, and a durable reference.** A note graduates into an ADR on acceptance (e.g. colour-conductor → an ADR-036 amendment), but the durable reference tying a note to the ADR it becomes is unsettled — the descriptive slug, a `DN-NNN`-style handle, or a convention of our own. Deferred deliberately; the prefix question rides on it, so neither is decided in passing.
- **What the living, accurate, in-repo reference should actually be.** Reconcile presumes a *living reference* to reconcile *to* — but the canonical shape and scope of that corpus is itself unsettled (the frozen ADR quarry vs a slim evergreen reference vs the per-area living docs). Since this determines *what* reconcile targets, the reconcile rung points straight at it. Larger than this note; deferred deliberately, recorded so it is not forgotten.
- **Unrun prior-art questions** (`../research/design-loop-prior-art.md` §6): is *co-locate-rule-with-enforcement* a rename of poka-yoke / "build quality in"? is the two-axis separation named anywhere? does Tessl's "living spec" cover the frozen-vs-living separation?

## Future possibilities

The loop enables but does not yet commit to:

- **An explore phase *before* the loop.** There is an "I'm turning an idea over" stage that precedes stage 1 — where the problem itself is still forming and formality would be premature. It sits *outside* the design loop; the open question is its shape and how it hands off into intent-first without forcing structure too early.
- **More targeted enforcement hooks.** A blanket commit-gate is ruled out as brittle (ADR-032), but narrower hooks — scoped to a specific, mechanical, correctness-severity trigger — are worth exploring *if* the advisory + presence-lint + review stack proves to still let skips through. Evidence-gated, not pre-built.
- **A claims-audit mechanism** — a periodic check that living references describe only what exists, catching drift before the next "reconcile to reality."
- **Applying the loop beyond design** — the same artifact-lifecycle + enforcement-first spine to other classes of change (e.g. host onboarding, dependency-stack moves).
