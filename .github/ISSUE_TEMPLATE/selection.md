---
name: Selection (doc-before-code)
about: Choose a tool / font / app / policy whose rationale is recorded before code.
title: "<area>: select <thing>"
---

<!--
Doc-before-code selection. The rationale doc (docs/<area>/<thing>.md)
lands BEFORE the implementing commit — the doc captures *why* at the
moment of decision, not as post-hoc justification. See docs/workflow.md
§"Documentation precedes implementation for selections":
https://github.com/dannyfaris/nix-config/blob/main/docs/workflow.md
Delete the guidance comments before submitting.
-->

### Intent

<!-- What capability or decision is needed, and why now. -->

### Candidates to evaluate

<!-- Name the options in the consideration space. Don't pre-pick a winner — that's the work of the issue. Record an operator *preference* as a preference ("operator leans X; needs rationalisation"), not a foregone conclusion. -->

-

### Selection criteria

<!-- What the decision hinges on: closure size, maintenance/liveness, Stylix-target support, niri/Wayland fit, cross-platform parity, etc. -->

-

### Acceptance

- [ ] Rationale recorded in `docs/<area>/<thing>.md` (Selection / Rationale / Alternatives considered) before the implementing commit.
- [ ] Implementation lands per the doc-before-code commit cadence — doc commit first. See docs/desktop/README.md §"Conventions for evolution".
- [ ]

### Relates to

<!-- Linked issues, docs, modules. Use a "Depends on #N" line for hard dependencies. -->

-
