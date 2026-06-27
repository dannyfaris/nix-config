# Design notes

The doc-before-code working-out of a non-trivial change: the problem and intent, the forces a solution must satisfy, the options weighed, the chosen decision, its architecture, the de-risk evidence, and the open items left for implementation.

Where [`decisions/`](../decisions/) records the *terse, frozen* ADR (the decision and its consequences) and [`research/`](../research/) captures *point-in-time* evidence that feeds a choice, a design note is the *fuller, proposed* working-out that sits between them — it leads with the problem, weighs the alternatives, and records the design before the code lands. A note is **Proposed / in-flight** while the work is being designed; when it lands, the direction-change is recorded as an ADR in `decisions/` and the mechanism guides the implementation.

## Conventions

- **Lead with intent.** The problem and the design objective come first; the decision and architecture come *after* the forces and the options, never before them.
- **Weigh the alternatives.** Name the options considered and why the chosen one wins against the stated forces — the choice should be legible, not asserted.
- **De-risk honestly.** Record what was verified and where; keep the open items — what is still to confirm at implementation — explicit. A design note is a proposal, not a guarantee.
- One subject per note; dated / issue-linked; soft-wrapped — as elsewhere in `docs/`.

## Index

- **[colour-conductor.md](./colour-conductor.md)** — live, reproducible, durable desktop theming: Stylix as the single theming authority, live switching across a Nix-declared menu of named themes via home-manager specialisations, Noctalia demoted to a themed-by-Nix shell. Reverses ADR-036's "Noctalia as sole theming authority" (#411 / Epic E #427).
