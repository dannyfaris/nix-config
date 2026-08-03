---
name: design
description: Run the repo's design loop for a non-trivial, cross-cutting, or hard-to-reverse change — an operator dialogue, agreement-gated at every stage boundary through the start of build — frame intent before solution, weigh alternatives, de-risk the load-bearing assumption, then build the thinnest slice and reconcile the docs in the same change. User-invoked with /design. For adopting/swapping/keeping a tool, package, daemon, or service, use the selecting-tooling skill instead (a specialisation of this loop). Records the work as a design note via the doc-before-code, peer-review, squash-auto-merge cadence.
disable-model-invocation: true
---

# Design

Run the [design loop](../../../docs/design/design-loop.md) for a change worth designing before coding. The generic half — understand the problem, write good prose — is something to just do well. This skill exists for the half that **gets skipped under momentum**: leading with intent instead of a solution, genuinely weighing alternatives, de-risking the load-bearing assumption *before* building — and conducting the design as a dialogue with the operator rather than a solo run. First-contact and cross-repo evidence (design-loop.md §De-risk evidence) showed it is exactly the stated-but-unenforced steps an agent drops — so these are the steps this skill makes standing instructions.

This is a high-freedom guide, not a rigid script. Size the ceremony to the change (stage 2); follow where the design leads.

## When this applies

A change that is **cross-cutting, hard to reverse, or introduces a new pattern** — where getting the design wrong is expensive to undo. The design note is the doc-before-code artifact for it.

**When it does not:**

- **Tool/package/service choice** (adopt, swap, keep, compare) — use the `selecting-tooling` skill; it is this loop specialised for that decision, with the verification gotchas that class needs.
- **Local, reversible, single-file work** — just build it (with peer review). A design note for a one-line default is the over-enforcement the loop itself warns against.

## The loop

Copy this into your working notes and track it:

```
Design progress (run as operator dialogue — every stage boundary through the start of build is an operator gate):
- [ ] 1. Intent — problem + objective first, before any solution; reflect it back, confirm same-page
- [ ] 2. Size — blast-radius / reversibility triage; heavy vs just-build
- [ ] 3. Design — forks ruled in dialogue, then start the note from the template; weigh the options
- [ ] 4. De-risk — test the load-bearing assumption before building (a kill result is a first-class abandon exit)
- [ ] 5. Build — the thinnest valuable slice; abstraction only with a real consumer
- [ ] 6. Peer-review — independent adversarial review; findings + verdict to the operator before commit
- [ ] 7. Reconcile — land the living-reference update in the same change
```

**1 — Intent.** State the problem and the objective before the mechanism. If you cannot say what is wrong and what "better" looks like without naming a solution, you are not ready to design. This is the step momentum kills; it is step one for a reason. Open by reflecting the problem back to the operator — short bullets, plain language — and get explicit same-page confirmation before anything advances (§The loop is a dialogue, which governs this stage and every boundary through the start of build).

**2 — Size.** Triage by blast-radius and reversibility. Irreversible or cross-cutting → the full note. Local and reversible → skip to build. Most changes are the latter; spend the ceremony where undoing is expensive.

**3 — Design.** Rule the forks with the operator first — numbered questions, one subject per turn, each with your stated lean (§The loop is a dialogue) — then start the note from the template — `cp docs/design/_template.md docs/design/<slug>.md` — and fill it: Summary → Motivation (problem + the *forces* a solution must satisfy) → Design → and the rest. The template's section order *is* intent-first; honour it. **Weigh the alternatives** against the stated forces — the choice must be legible, not asserted. The note records the dialogue's rulings; it does not pre-empt them. The shape and conventions live in [`docs/design/README.md`](../../../docs/design/README.md); do not restate them here.

**4 — De-risk.** Identify the assumption the design rests on and *test it* — eval it, prototype it, read the pinned source — recording the result in the note's De-risk evidence section. State what stays unverified rather than implying coverage you do not have. A note is a proposal, not a guarantee. **The abandon exit is first-class:** a de-risk result that kills the design is a real outcome, not a failure — record the negative result in the design note itself, close the driving issue with it, and stop the loop there.

**5 — Build.** The thinnest slice that delivers value. Commit an abstraction only when a real consumer exists (YAGNI).

**6 — Peer-review.** An independent subagent reviews the note and the staged diff before commit — adversarially. Use [`peer-review-checklist.md`](peer-review-checklist.md): it checks the things the structure lint cannot (is the Motivation actually intent-first, are the alternatives genuinely weighed, is the de-risk honest). Findings and verdict reach the operator before any commit; the operator's "land" is the gate.

**7 — Reconcile.** The living-reference update lands in the *same change* as the code, never in arrears (design-loop.md §The reconcile hypothesis). On acceptance the direction-change is recorded as an ADR in `docs/decisions/`; the note stays as the proposed-design record. Workflow cadence (intent-first issues, staged-diff review, draft-PR + squash auto-merge) lives in [`docs/workflow.md`](../../../docs/workflow.md) — follow it; this skill does not restate it.

## The loop is a dialogue

The loop's medium is a working conversation with the operator; the note records what the conversation settled. Its standing rules — governing stage 1 through the start of build:

- **Reflect back before designing.** Open stage 1 by reflecting the problem back in short bullets and getting explicit same-page confirmation before going further.
- **Gate every stage boundary through the start of build.** Advancing takes the operator's stated agreement — "let's take it to stage 2" is the operator's line, never assumed on their behalf.
- **Forks are numbered questions with a stated lean.** One subject per turn; give a recommendation and why; record each ruling in the note. A parked subtopic is named and honoured, never silently dropped. Inside these stages the propose-order stance inverts by design (workflow.md §"Propose order; don't multi-question"): eliciting the ruling *is* the work, not stalled momentum.
- **Ground abstractions on arrival.** A coined term or new abstraction gets a one-line definition or a concrete example in the same breath — the operator should never have to ask "what do you mean by that".
- **Checkpoint in the operator's register.** Stage summaries and status are short, bulleted, plain-language; go deep on the current subject rather than broad across several, and offer depth rather than dumping it. Full design prose belongs in the note, not the conversation.
- **Draft the note after the dialogue settles it.** The note is the record of rulings made in conversation, not a draft awaiting them; render it in chat when the operator asks.
- **Handover starts change nothing.** A run kicked off from a handover brief enters stage 1 in dialogue like any other run — the handover authorises the loop, not a silent solo execution of it.

The mode's boundary: it governs design decisions. Once a slice is agreed, implementation, subagent orchestration, and fix cycles keep their momentum — per-step check-ins there would be exactly the ceremony this loop warns against.

This dialogue mode is itself encoded from cross-repo evidence; the account is in design-loop.md §De-risk evidence.

## Structure self-check

Before peer review, run the structure lint on your draft — the same script CI runs (one source of truth):

```
bash scripts/lint-design-note.sh docs/design/<slug>.md
```

It gates *presence* only (sections present, in order, none left as a template prompt) — not quality. A green lint means the skeleton is sound; the judgment calls are the reviewer's job.

## Subagents

- **Peer review (stage 6):** an independent subagent, prompted adversarially, reviews the note and the staged diff against `peer-review-checklist.md`. First confirm the working tree matches the intended merge target, and scope the review to the relevant files.
- **De-risk / research (stages 3–4):** spawn a subagent to verify a load-bearing claim against the pinned source or running system; demand it be skeptical, not confirmatory. A research run that produces a standalone report — e.g. a `deep-research` run — has its report persisted to `docs/research/<slug>.md` (dated status/provenance header, indexed, Refs-not-Closes) per [`docs/research/README.md`](../../../docs/research/README.md), never left only in the workflow transcript; fold its verdicts back into the note's De-risk evidence.

## See also

- [`docs/design/design-loop.md`](../../../docs/design/design-loop.md) — the loop, its forces, and why each stage carries its enforcement.
- [`docs/design/README.md`](../../../docs/design/README.md) — how to write a design note; the Drawbacks≠Cost convention.
- [`docs/design/_template.md`](../../../docs/design/_template.md) — the copyable skeleton.
