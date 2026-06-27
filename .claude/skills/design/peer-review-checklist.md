# Design-note peer-review checklist

For the independent reviewer (stage 6). The structure lint already gates
*presence* — sections present, ordered, non-empty. Your job is the half a
grep cannot judge: **whether the thinking is honest**. Be adversarial; the
loop exists because these are the steps that get skipped under momentum, and
review is their backstop.

## The judgment checks (what the lint can't see)

- **Intent-first, not solution-first.** Does Motivation state the *problem* and the *forces* before any mechanism? Could the Summary be understood by someone who doesn't yet know the solution? A note that opens by describing the fix has skipped stage 1 — send it back. *(This is the failure that broke at first contact.)*
- **Alternatives genuinely weighed.** Does Rationale name real options and say why each loses *against the stated forces* — or does it assert the choice and list a strawman? At least one option should have been a live contender.
- **Forces actually drive the decision.** Are the forces in Motivation the same ones Rationale weighs against? A force stated but never used, or a decision resting on an unstated force, is a tell.
- **De-risk is honest.** Does De-risk evidence test the *load-bearing* assumption (not an easy one), cite where it was verified, and state what remains unverified? "Green" with no provenance is not de-risked.
- **Drawbacks ≠ Cost, and both honest.** Are Drawbacks genuine reasons-against the direction (not the satisfied constraints dressed up), and is Cost a real standing price (not a restated drawback)? Is anything that should be a drawback hidden in Cost, or vice versa?
- **Thinnest slice / YAGNI.** Does the Design commit only what a real consumer needs now, or does it build abstraction on forecast?
- **Reconcile in the same change.** If code lands with this, does the living-reference update land *with* it — not promised for later?

## Provenance and accuracy

- **Cross-references resolve** and point to the right place (the canonical home, not a restatement).
- **Numbers are measured or cited, stated once** — a figure repeated across the note and an issue drifts.
- **Rationale single-sourced** — the *why* lives in one home (ADR or `docs/<area>/`) with a pointer, not duplicated inline (CLAUDE.md §Conventions).

## Convention fit

- **Soft-wrapped** (one line per paragraph), one subject, issue-linked.
- **Scope discipline** — does the diff implement *only* what the note designs, with no unrequested extras?

## Verdict

Tag findings `[BLOCKER]` / `[SHOULD-FIX]` / `[NIT]` with a concrete fix, and
end with `LAND-AS-IS` / `LAND-WITH-FIXES` / `NEEDS-REWORK`. A note that fails
intent-first or weigh-alternatives is at least LAND-WITH-FIXES — those are
the loop's load-bearing steps, not nits.
