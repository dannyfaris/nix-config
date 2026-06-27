# Software design-loop prior art — is the RFC-001 hypothesis novel?

Status: **research note, not a decision.** Captured from a deep-research run (5 angles, 23 sources fetched, 104 claims extracted → 25 adversarially verified via 3-vote, 21 confirmed / 4 killed) on 2026-06-25; run ID `wf_e4947220-d16`. Asks one question for the design-loop work (RFC-001 — the design-loop hypothesis, placement pending): is an *integrated*, hypothesis-driven software **design loop** — especially one built for human + AI-coding-agent collaboration — established prior art, or genuinely nascent? And for each of RFC-001's eight claims, is there a named antecedent? The run was deliberately biased toward *refuting* novelty (find the prior art if it exists). Feeds RFC-001. Survey-bounded — see §7.

## 1. Verdict

**You're reinventing the parts, but the assembly is yours.**

There is **no established, named, integrated design loop** that unifies all eight RFC-001 claims, and the specifically human + AI-coding-agent version is **genuinely nascent** — frontier-2026 academic sources flag it as an underdeveloped gap, not a solved problem. But the run strongly **refutes novelty at the rung level**: at least seven of the eight individual mechanisms have well-established, primary-sourced names that RFC-001 is reinventing. The genuinely under-served, RFC-001-distinctive contributions are (a) the **separation** of frozen-record vs. living-reference into distinct artifact types governed by opposite tense/update disciplines (ADR practice recognises the immutable-vs-living tension by name but resolves it *within* one artifact, not by separation), and (b) the **integration** of all eight rungs into a single loop, especially one architected for human + coding-agent collaboration.

## 2. Landscape — each claim → closest prior art → match

| RFC-001 claim | Closest established prior art | Match |
|---|---|---|
| 3 — blast-radius-proportioned design | Risk-driven design (Fairbanks 2010); reversible/irreversible "Type-1 / Type-2 doors" (Bezos 2015) | **Served** |
| 5 — de-risk the load-bearing assumption first | Risk-driven model, step 1 — identify & prioritise risks (Fairbanks 2010) | **Served** |
| 1 (frozen record) + 2 (decision-state axis) | Architecture Decision Records (Nygard 2011) | **Served** (decision-state only) |
| 1 (tense / one-artifact-one-purpose) + 7 (reference led by code) | Diátaxis (Procida) | **Partially served** |
| 6 (thin slice) + 8 (process-as-hypothesis) | Lean Startup — MVP, Build-Measure-Learn, validated learning (Ries 2011) | **Served** (as concepts) |
| 4 — co-locate a rule with its enforcement | None surfaced (poka-yoke / "build quality in" / docs-as-code "lint the rule" are cousins, unverified) | **Open** |
| 1 (separation into *distinct* artifacts) + 2 (two-axis decision ⊥ build) + the eight-rung integration | None | **Open / distinctive** |

## 3. Findings in detail

**F1 — Claims 3 (blast-radius) and 5 (de-risk first) are the established risk-driven approach crossed with reversibility framing.** Confidence: high. Vote: 3-0 (×3 merged: Fairbanks risk-driven, Bezos Type-1/2, Bezos failure-mode); Shape Up appetite 3-0 as partial antecedent.
Fairbanks' book is subtitled *"A Risk-Driven Approach"*: *"There is no need for meticulous designs when risks are small, nor any excuse for sloppy designs when risks threaten your success"* — a 1:1 match to proportioning design effort to risk, formalised as a named three-step model. Bezos's 2015 shareholder letter splits decisions into Type 1 (irreversible "one-way doors," deliberate/slow) vs Type 2 (reversible "two-way doors," fast/small-group), and **names RFC-001's failure mode verbatim**: using *"the heavy-weight Type 1 decision-making process on most decisions, including many Type 2 decisions … slowness, unthoughtful risk aversion, failure to experiment sufficiently, and consequently diminished invention."* Shape Up's "appetite" (*"fixed time, variable scope"*) is a related but partial antecedent — it bounds *total* effort to value, not *design* effort to reversibility.
Sources: [Fairbanks — *Just Enough Software Architecture*](https://www.georgefairbanks.com/book/), [Bezos 2015 letter](https://s2.q4cdn.com/299287126/files/doc_financials/annual/2015-Letter-to-Shareholders.PDF), [Shape Up appendix 06](https://basecamp.com/shapeup/4.5-appendix-06).

**F2 — Claim 1's frozen-decision-record discipline and Claim 2's decision-state axis are exactly ADRs.** Confidence: high. Vote: 3-0 (×2 merged: frozen-record discipline, Status lifecycle).
Nygard's originating 2011 article states verbatim *"If a decision is reversed, we will keep the old one around, but mark it as superseded"* and lists the Status values *"proposed, accepted, deprecated, superseded."* Corroborated by Fowler (*"Once an ADR is accepted, it should never be reopened or changed — instead it should be superseded"*), AWS Prescriptive Guidance, and Microsoft Azure Well-Architected (*"append-only log … write a new record that supersedes the original"*). **Scope note:** ADRs serve the *decision-state* axis of Claim 2 but do **not** implement Claim 2's distinctive *separation* of decision-state from build-state — that separation remains an RFC-001 contribution.
Sources: [Nygard 2011](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions), [ADR org README](https://github.com/architecture-decision-record/architecture-decision-record/blob/main/README.md).

**F3 — Claim 1's tense discipline and Claim 7 are partially served by Diátaxis; the "one artifact can't serve two purposes" intuition is named for docs.** Confidence: high. Vote: 3-0 (×6 Diátaxis constructive + ×1 ADR immutable-vs-living tension); one over-strong "Diátaxis serves none of it" null-claim refuted 1-2.
Diátaxis splits documentation on user-need axes (*action vs cognition* × *acquisition vs application*) — explicitly **not** a lifecycle/tense axis. But it asserts the general mixing-degrades principle verbatim (*"Crossing or blurring the boundaries … is at the heart of a vast number of problems in documentation"*), which is prior art for "one artifact cannot serve two purposes" applied to docs; and it defines Reference as *"information-oriented … led by the product it describes"* and endorses auto-generating reference *"to ensure it remains faithfully accurate to the code"* — prior art for Claim 7's "living reference may never lead the code." Critically, the frozen-vs-living tension **is** named in ADR practice (*"In theory, immutability is ideal. In practice, mutability has worked better … a living document that we all can update"*) — but ADRs resolve it as a per-team choice of immutable **or** living *within one artifact*, not by RFC-001's separation into distinct frozen-record + living-reference artifacts.
Sources: [Diátaxis](https://diataxis.fr/start-here/), [Diátaxis — Reference](https://diataxis.fr/reference/), [Diátaxis — Explanation](https://diataxis.fr/explanation/), [ADR org README](https://github.com/architecture-decision-record/architecture-decision-record/blob/main/README.md).

**F4 — Claim 6 (thin valuable slice / YAGNI) and Claim 8 (process-as-hypothesis) map to Lean Startup's MVP, Build-Measure-Learn, and validated learning.** Confidence: high. Vote: 3-0 (×3 merged).
MVP is defined as *"developing a minimum viable product (MVP) to begin the process of learning as quickly as possible"* — and (per Ries's own org) it is a learning-maximisation, not a code-minimisation, device, which directly counters the common YAGNI-misread. Build-Measure-Learn is a named integrated cycle (MVP → actionable metrics → pivot-or-persevere). *"Every startup is a grand experiment that attempts to answer a question … Should this product be built?"* with validated learning as *"the unit of progress"* anticipates Claim 8. **Calibration (the genuine residue):** Lean Startup frames the *product/business* as the hypothesis; RFC-001 Claim 8 is more reflexive — the development *process itself* as hypothesis with explicit refutation criteria, which Lean Startup does not state. MVP also covers the "thin slice to learn" half but only partially the "commit an abstraction only when a real consumer exists" (YAGNI-in-code) half.
Source: [The Lean Startup — Principles](https://theleanstartup.com/principles).

**F5 — Claim 5 (de-risk first) is the risk-driven model's first step.** Confidence: high. Vote: 3-0.
Fairbanks' model is *"a straightforward three-step cycle: (1) identify and prioritize risks, (2) select and apply a set of techniques, and (3) evaluate risk reduction,"* governed by the rule to do architecture *"until the risk of technical failure is lower than non-technical risks."* Step 1's explicit *prioritise* plus the questioning frame (*"What are my risks? What are the best techniques to reduce them?"*) maps to de-risking the top assumption before building. Caveat from verification: the model guides *how much* design better than *which specific technique*, and risk perception varies between people — application limits, not refutations.
Source: [Fairbanks — *Just Enough Software Architecture*](https://www.georgefairbanks.com/book/).

**F6 — Bucket B: eval-driven development is real and named, formalised academically as EDDOps — but on a different axis.** Confidence: high. Vote: 3-0 (×2 merged).
EDDOps (*"Evaluation-Driven Development and Operations"*, Lu/Zhu/Xia et al., CSIRO Data61, v3 Nov 2025) is *"the disciplined use of evaluation evidence, both offline and online, to prioritize and govern targeted changes during agent runtime and subsequent (re)development"* — a genuine integrated closed loop (Define Evaluation Plan → Develop Test Cases → Conduct Offline/Online Evaluations → Analyze & Improve, step 4 closing back to step 1). "Eval-driven development" is also a named industry practice (Braintrust, Vercel, Anaconda). **But** targeted verification confirmed EDDOps does **not** discuss decision-state tracking, documentation tense, or co-locating rules with enforcement — its axis is *evaluation of a deployed agent-as-product*, not RFC-001's design discipline. This is the single strongest "something already does an integrated AI loop" candidate, and it confirms the axis is different.
Source: [EDDOps — arXiv 2411.13768v3](https://arxiv.org/html/2411.13768v3).

**F7 — The gap / verdict: no peer-style source names an integrated human + AI-agent design loop; spec-driven & orchestration practices appear only as nascent principles.** Confidence: medium. Vote: 2-1 (Alenezi "no named loop") + 3-0 (roadmap "orchestration is an open challenge"); three over-strong companion readings refuted (see §6).
Alenezi, *"Rethinking Software Engineering for Agentic AI Systems"* (April 2026), names no unified design loop — its closest construct is an unbranded *"verification-first, human-in-the-loop model"* — and affirmatively flags the gap: *"standards for prompt versioning, agent capability declaration, and audit-ready development logs remain underdeveloped."* The GenAI research roadmap (Feb 2026, 13 authors) frames *"A5. Workflow integration and orchestration"* as a research **challenge**; orchestration platforms appear only as 2030 predictions, not current practice. The strongest potential refuter — Spec-Driven Development (GitHub Spec Kit, AWS Kiro, BMAD, Tessl) — **is** a named, increasingly-integrated loop, but every authoritative source independently calls it nascent (Thoughtworks *"emerging … no standardized workflows"*; Fowler *"still in flux"*; the SDD arXiv *"nascent," "BDD with branding," "not an established standard with consensus"*), and it covers only a *subset* of the eight rungs. **Confidence is medium** because this rests on a single-author preprint (Alenezi), a 2-1-voted claim, and absence-of-evidence reasoning; SDD's rapid 2025–2026 evolution makes this the most time-sensitive finding.
Sources: [Alenezi — arXiv 2604.10599v1](https://arxiv.org/html/2604.10599v1), [GenAI roadmap — arXiv 2510.26275](https://arxiv.org/pdf/2510.26275), [Fowler — SDD tools](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html), [Thoughtworks — SDD 2025](https://www.thoughtworks.com/en-us/insights/blog/agile-engineering-practices/spec-driven-development-unpacking-2025-new-engineering-practices).

**F8 — Claim 4 (co-locate a rule with its enforcement) has no established named antecedent surfaced by this survey.** Confidence: low (absence of evidence). Vote: no confirmed claim (gap in coverage).
No source survived verification naming the specific principle "a rule asserted in prose without its mechanism is silently violated before the gate exists." Adjacent named concepts exist — Lean/TPS poka-yoke (error-proofing), jidoka / stop-the-line, *"build quality in"*; docs-as-code's *"lint the rule"* — but none was confirmed as a named match. **This is absence of evidence, not confirmed absence**: poka-yoke and "build quality in" are strong conceptual cousins and a targeted follow-up would likely find partial antecedents. Alongside the artifact-*separation* and the eight-rung *integration*, this is the clearest candidate for a genuinely RFC-001-original contribution — but "we didn't find it" must not be read as "it doesn't exist."

## 4. Refuted claims (killed in verification)

These tempting readings were proposed and **refuted** by the 3-vote adversarial layer — important because their death is *why* the surviving verdict can be trusted as the modest, not the motivated, reading:

- *"Diátaxis addresses none of the tense/lifecycle discipline, so it does not serve Claim 1"* — **refuted 1-2** (Diátaxis is a partial antecedent, not null). [src](https://diataxis.fr/start-here/)
- *"The paper asserts PROCESS design, not model capability, is the primary determinant of reliability — endorsing the RFC-001 premise"* — **refuted 0-3**. [src](https://arxiv.org/html/2604.10599v1)
- *"Current GenAI-augmented development is unsystematic/ad hoc, supporting the hunch"* — **refuted 1-2**. [src](https://arxiv.org/pdf/2510.26275)
- *"Integration of AI agents with an end-to-end SDLC is explicitly identified as missing — the whole loop is unserved"* — **refuted 0-3**. [src](https://arxiv.org/pdf/2510.26275)

## 5. Caveats

**Source quality.** Findings F1–F6 are high-confidence — multiple primary sources (Fairbanks, Bezos 2015, Nygard 2011, Ries, Procida, the EDDOps paper), unanimous 3-0 votes, and adversarial refutation attempts that consistently *confirmed* rather than weakened the claims. Finding F7 (the central "is the integrated AI loop nascent?" question) is the weakest link: a single-author arXiv **preprint** (Alenezi, not formally peer-reviewed), a 2-1-voted claim, and absence-of-evidence reasoning.

**Not-found vs confirmed-absent.** It can be stated with confidence that the eight-rung *integration* and the AI-collaborative version are **not established** (multiple frontier sources affirmatively flag the gap). It **cannot** be stated that they are *confirmed absent* — the agent-tooling space (Spec Kit, Kiro, BMAD, Tessl, Cursor/CLAUDE.md/AGENTS.md rules conventions) moves faster than any survey can fix.

**Time-sensitivity.** Bucket B is highly time-sensitive; Spec-Driven Development and agent-rules conventions evolve month-to-month in 2025–2026. This verdict has a short shelf-life — re-run rather than trust if relied on past mid-2026.

**Under-surveyed (explicit).** (a) Claim 4 "co-locate rule with enforcement" — poka-yoke / jidoka / "build quality in" / docs-as-code "lint your conventions" were **not** run to ground. (b) Bucket A candidates named in the brief but not surfaced as confirmed claims: Shape Up betting-table/circuit-breaker/scopes (only "appetite" verified), Cynefin (Snowden), spikes / tracer-bullets (XP / Pragmatic Programmer), README-driven development, Amazon Working Backwards / PR-FAQ, "Living Documentation" (Martraire), set-based concurrent engineering, the spiral model. Their absence reflects survey coverage, not confirmed irrelevance. (c) Claim 2's two-axis (decision-state separated from build-state) was matched to no source — only the decision-state axis alone (ADRs).

**Scope-integrity.** Each individual claim maps to prior art that serves **one** rung; verifiers were careful that no single framework was claimed to serve the integrated whole — that distinction is load-bearing for the verdict.

## 6. Open questions

1. Is Claim 4 (co-locate a rule with its enforcement) genuinely original, or a renaming of poka-yoke / "build quality in" (Lean/TPS) or the docs-as-code practice of linting one's own conventions? The single biggest coverage gap — warrants a targeted follow-up on poka-yoke, "executable conventions," and "lint-the-rule" before any originality claim.
2. Does anyone name Claim 2's specific two-axis separation (decision-state proposed/accepted/superseded tracked *separately* from build-state none/sliced/complete)? ADRs name decision-state and agile boards name build/workflow state, but the deliberate orthogonal separation was not matched.
3. Among the named-but-nascent AI loops (Spec-Driven Development via Spec Kit / Kiro / BMAD / Tessl, and EDDOps), does any single one cover *more* of the eight rungs than assessed here — particularly **Tessl's "living spec"** / spec-anchored direction, which Fowler singled out and which sounds closest to RFC-001's frozen-record-vs-living-reference separation?
4. Is there a named principle for RFC-001's strongest residue — the *separation* of a frozen decision record from a living present-tense reference into **distinct** artifacts with opposite update disciplines (as opposed to ADRs' within-one-artifact immutable-or-living choice, or Diátaxis's by-user-need split)? This deserves a dedicated search rather than the analogical mappings found so far.

## 7. Implication

- **Rename and cite, don't re-derive.** Recast RFC-001's claims against established names: Claim 3 → risk-driven design (Fairbanks) + Type-1/Type-2 reversibility (Bezos); Claim 5 → risk-driven model step 1 (Fairbanks); Claims 1-frozen + 2-decision-state → ADRs (Nygard — already in use here); Claims 1-tense + 7 → Diátaxis (Procida); Claims 6 + 8 → MVP / Build-Measure-Learn / validated learning (Ries). This shrinks the prose, raises credibility, and isolates what is actually new.
- **Learn from blueprints.** EDDOps (the AI-agent integrated-loop *structure*, different axis) and Spec-Driven Development (Spec Kit / Kiro / BMAD / **Tessl's living-spec**) are the nearest neighbours to study before building.
- **Genuinely ours to develop** (pending the §6 follow-up): the **separation** of frozen-record vs living-reference into distinct artifacts (strongest residue), the **two-axis** decision ⊥ build status, **Claim 4** (co-locate rule + enforcement), and the **integration** of all eight rungs into one loop architected for human + agent collaboration.

## Sources

Primary (highest weight):
- [Fairbanks — *Just Enough Software Architecture: A Risk-Driven Approach*](https://www.georgefairbanks.com/book/) — F1, F5.
- [Bezos — 2015 Amazon shareholder letter](https://s2.q4cdn.com/299287126/files/doc_financials/annual/2015-Letter-to-Shareholders.PDF) — F1 (Type-1/2 doors, failure mode).
- [Nygard — Documenting Architecture Decisions (2011)](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions) — F2.
- [Diátaxis — start / reference / explanation](https://diataxis.fr/start-here/) — F3.
- [The Lean Startup — Principles](https://theleanstartup.com/principles) — F4.
- [EDDOps — arXiv 2411.13768v3](https://arxiv.org/html/2411.13768v3) — F6.
- [Alenezi — Rethinking SE for Agentic AI Systems, arXiv 2604.10599v1](https://arxiv.org/html/2604.10599v1) — F7.
- [GenAI research roadmap — arXiv 2510.26275](https://arxiv.org/pdf/2510.26275) — F7.

Secondary / industry:
- [Shape Up — appendix 06 (appetite)](https://basecamp.com/shapeup/4.5-appendix-06) — F1.
- [ADR org README (immutable-vs-living tension; Status lifecycle)](https://github.com/architecture-decision-record/architecture-decision-record/blob/main/README.md) — F2, F3.
- [Fowler — Spec-Driven Development tools](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html) — F7.
- [Thoughtworks — Spec-Driven Development, 2025](https://www.thoughtworks.com/en-us/insights/blog/agile-engineering-practices/spec-driven-development-unpacking-2025-new-engineering-practices) — F7.
- [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) — F7.

---

Provenance: deep-research run `wf_e4947220-d16`, 2026-06-25 — 5 angles, 23 sources fetched, 104 claims extracted, 25 verified (21 confirmed, 4 killed), 8 findings after synthesis, 105 agent calls. This is a living research note per the [docs/research convention](./README.md): update it as the landscape moves — as the §6 open questions are run down, and as Bucket B (spec-driven / agent-loop tooling) evolves, since the verdict is time-sensitive past mid-2026.
