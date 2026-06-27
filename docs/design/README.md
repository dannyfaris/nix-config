# Design notes

The doc-before-code working-out of a non-trivial change: the problem and intent, the forces a solution must satisfy, the options weighed, the chosen decision, its architecture, the de-risk evidence, and the open items left for implementation.

Where [`decisions/`](../decisions/) records the *terse, frozen* ADR (the decision and its consequences) and [`research/`](../research/) captures *point-in-time* evidence that feeds a choice, a design note is the *fuller, proposed* working-out that sits between them — it leads with the problem, weighs the alternatives, and records the design before the code lands. A note is **Proposed / in-flight** while the work is being designed; when it lands, the direction-change is recorded as an ADR in `decisions/` and the mechanism guides the implementation.

## Writing a design note

1. **Copy the template.** Start from [`_template.md`](./_template.md) — `cp _template.md <descriptive-name>.md` — and fill each section, replacing the inline *italic prompts*. The template is the artifact's shape; this README is when and how to use it; [`design-loop.md`](./design-loop.md) is the *why* behind the loop the note moves through.
2. **Lead with intent.** Write the Summary and Motivation first — the problem and the forces — before any mechanism. Solution-first drafts are the failure mode the loop exists to catch.
3. **De-risk before you commit to the design.** Test the load-bearing assumption and record the result in De-risk evidence. A note is a proposal, not a guarantee; an unverified claim is stated as unverified.
4. **Weigh the alternatives.** Name the options and why the chosen one wins *against the stated forces*. The choice should be legible, not asserted.
5. **Peer-review before commit**, as elsewhere in the repo (see [`../workflow.md`](../workflow.md)).
6. **On acceptance it graduates.** A landed note's direction-change is recorded as an ADR in [`decisions/`](../decisions/) (the frozen *what*), while the note's mechanism guides the implementation and the living reference is reconciled in the *same change* as the code. The note itself is left in place as the proposed-design record; its Status header tracks where it sits on the two axes (decision-state ⊥ build-state).

## Conventions

- **Lead with intent.** The problem and the design objective come first; the decision and architecture come *after* the forces and the options, never before them.
- **Weigh the alternatives.** Name the options considered and why the chosen one wins against the stated forces — the choice should be legible, not asserted.
- **De-risk honestly.** Record what was verified and where; keep the open items — what is still to confirm at implementation — explicit. A design note is a proposal, not a guarantee.
- **Drawbacks and Cost are distinct.** Drawbacks are reasons-against the whole direction (strongest while Proposed); Cost is the standing price of the direction once chosen, and is optional — omit it when there is nothing non-obvious to record.
- One subject per note; dated / issue-linked; soft-wrapped — as elsewhere in `docs/`.

## Index

- **[colour-conductor.md](./colour-conductor.md)** — live, reproducible, durable desktop theming: Stylix as the single theming authority, live switching across a Nix-declared menu of named themes via home-manager specialisations, Noctalia demoted to a themed-by-Nix shell. Reverses ADR-036's "Noctalia as sole theming authority" (#411 / Epic E #427).

- **[design-loop.md](./design-loop.md)** — the repo's own design loop: how design work moves (intent → forces → options → decision → de-risk → reconcile), the artifact lifecycle (frozen record vs living reference vs proposal), and the enforcement-first spine for human + AI-agent collaboration. *Proposed; mutable by design.*
