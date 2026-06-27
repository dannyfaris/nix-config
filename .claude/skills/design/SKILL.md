---
name: design
description: Run the repo's design loop for a non-trivial, cross-cutting, or hard-to-reverse change — frame intent before solution, weigh alternatives, de-risk the load-bearing assumption, then build the thinnest slice and reconcile the docs in the same change. User-invoked with /design. For adopting/swapping/keeping a tool, package, daemon, or service, use the selecting-tooling skill instead (a specialisation of this loop). Records the work as a design note via the doc-before-code, peer-review, squash-auto-merge cadence.
disable-model-invocation: true
---

# Design

Run the [design loop](../../../docs/design/design-loop.md) for a change worth designing before coding. The generic half — understand the problem, write good prose — is something to just do well. This skill exists for the half that **gets skipped under momentum**: leading with intent instead of a solution, genuinely weighing alternatives, and de-risking the load-bearing assumption *before* building. First-contact evidence (design-loop.md §De-risk evidence) showed those are exactly the steps an agent drops — so they are the steps this skill makes standing instructions.

This is a high-freedom guide, not a rigid script. Size the ceremony to the change (stage 2); follow where the design leads.

## When this applies

A change that is **cross-cutting, hard to reverse, or introduces a new pattern** — where getting the design wrong is expensive to undo. The design note is the doc-before-code artifact for it.

**When it does not:**
- **Tool/package/service choice** (adopt, swap, keep, compare) — use the `selecting-tooling` skill; it is this loop specialised for that decision, with the verification gotchas that class needs.
- **Local, reversible, single-file work** — just build it (with peer review). A design note for a one-line default is the over-enforcement the loop itself warns against.

## The loop

Copy this into your working notes and track it:

```
Design progress:
- [ ] 1. Intent — problem + objective first, before any solution
- [ ] 2. Size — blast-radius / reversibility triage; heavy vs just-build
- [ ] 3. Design — start the note from the template; weigh the options
- [ ] 4. De-risk — test the load-bearing assumption before building
- [ ] 5. Build — the thinnest valuable slice; abstraction only with a real consumer
- [ ] 6. Peer-review — independent adversarial review before commit
- [ ] 7. Reconcile — land the living-reference update in the same change
```

**1 — Intent.** State the problem and the objective before the mechanism. If you cannot say what is wrong and what "better" looks like without naming a solution, you are not ready to design. This is the step momentum kills; it is step one for a reason.

**2 — Size.** Triage by blast-radius and reversibility. Irreversible or cross-cutting → the full note. Local and reversible → skip to build. Most changes are the latter; spend the ceremony where undoing is expensive.

**3 — Design.** Start the note from the template — `cp docs/design/_template.md docs/design/<slug>.md` — and fill it: Summary → Motivation (problem + the *forces* a solution must satisfy) → Design → and the rest. The template's section order *is* intent-first; honour it. **Weigh the alternatives** against the stated forces — the choice must be legible, not asserted. The shape and conventions live in [`docs/design/README.md`](../../../docs/design/README.md); do not restate them here.

**4 — De-risk.** Identify the assumption the design rests on and *test it* — eval it, prototype it, read the pinned source — recording the result in the note's De-risk evidence section. State what stays unverified rather than implying coverage you do not have. A note is a proposal, not a guarantee.

**5 — Build.** The thinnest slice that delivers value. Commit an abstraction only when a real consumer exists (YAGNI). 

**6 — Peer-review.** An independent subagent reviews the note and the staged diff before commit — adversarially. Use [`peer-review-checklist.md`](peer-review-checklist.md): it checks the things the structure lint cannot (is the Motivation actually intent-first, are the alternatives genuinely weighed, is the de-risk honest).

**7 — Reconcile.** The living-reference update lands in the *same change* as the code, never in arrears (design-loop.md §The reconcile hypothesis). On acceptance the direction-change is recorded as an ADR in `docs/decisions/`; the note stays as the proposed-design record. Workflow cadence (intent-first issues, staged-diff review, draft-PR + squash auto-merge) lives in [`docs/workflow.md`](../../../docs/workflow.md) — follow it; this skill does not restate it.

## Structure self-check

Before peer review, run the structure lint on your draft — the same script CI runs (one source of truth):

```
bash scripts/lint-design-note.sh docs/design/<slug>.md
```

It gates *presence* only (sections present, in order, none left as a template prompt) — not quality. A green lint means the skeleton is sound; the judgment calls are the reviewer's job.

## Subagents

- **Peer review (stage 6):** an independent subagent, prompted adversarially, reviews the note and the staged diff against `peer-review-checklist.md`. First confirm the working tree matches the intended merge target, and scope the review to the relevant files.
- **De-risk / research (stages 3–4):** spawn a subagent to verify a load-bearing claim against the pinned source or running system; demand it be skeptical, not confirmatory.

## See also

- [`docs/design/design-loop.md`](../../../docs/design/design-loop.md) — the loop, its forces, and why each stage carries its enforcement.
- [`docs/design/README.md`](../../../docs/design/README.md) — how to write a design note; the Drawbacks≠Cost convention.
- [`docs/design/_template.md`](../../../docs/design/_template.md) — the copyable skeleton.
