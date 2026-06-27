<!--
Design-note template. Copy this file to docs/design/<descriptive-name>.md and fill each section, replacing the *italic prompts*. Delete a section only if the note explicitly says why it is N/A; the one section you may simply omit is **Cost** (see its prompt). See docs/design/README.md for when to write a design note and how it moves through the loop.
-->

# <Title — what it is + the one-line value>

**Status:** <Proposed | Accepted | Superseded> — design note (`docs/design/`). <Build-state: not built | sliced | complete>. <issue links> · <ADR relationship, if any>.

## Summary

*One paragraph: what this proposes, in plain terms, before any why. The TL;DR a reader skims first.*

## Motivation

*The problem in detail, with background and concrete use cases — then the forces / constraints any solution must satisfy. Why are we doing this, what is the expected outcome, and what must any design honour? State the forces explicitly: the Rationale section weighs the chosen design against them, so they have to be named here.*

## Design

*The mechanism in enough detail to implement: how it works, how it interacts with what already exists, corner cases by example. One explanation — no separate "teach it" vs "spec it" levels. Close with how the design meets the forces from Motivation.*

## De-risk evidence

*The load-bearing assumptions, tested* before *building — what was verified, where (file/rev/host), and the result. A design note is a proposal, not a guarantee; this section is where it earns confidence. State what is still unverified rather than implying coverage you do not have.*

## Drawbacks

*Why we might not do this at all. Adversarial, and it carries the most weight while the note is Proposed. Distinct from Cost: this is reasons-against the whole direction; Cost is the price of the direction once chosen.*

## Cost

*Optional — include only when the chosen direction carries a non-obvious standing price (recurring build cost, capability given up, ongoing maintenance). Omit the section entirely if there is nothing non-obvious to record; do not pad it with restated drawbacks.*

## Rationale & alternatives

*Why this design over the others, weighed against the stated forces. The options considered and why each loses. The impact of doing nothing.*

## Prior art

*What comparable efforts — other tools, other communities, this repo's own history — did, good and bad, in relation to this proposal. Cite `docs/research/` notes where the survey lives rather than restating it.*

## Unresolved questions

*What you expect to resolve during review, what during implementation, and what is explicitly out of scope. Honest open items, not a wish list.*

## Future possibilities

*Natural extensions and evolution, parked here so they do not pollute the Decision. Free space for "later" ideas the design enables but does not commit to.*
