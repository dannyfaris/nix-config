# Documentation density refactor - right-sized repo memory with agent evals

**Status:** Proposed - design note (`docs/design/`). Build-state: not built. No issue yet. ADR relationship: none expected by default; ADR only if the accepted design creates or reverses a durable decision boundary.

## Summary

This note proposes an end-to-end documentation refactor on a discrete branch, evaluated against `main` with repeatable agent tasks. The goal is not to document less for its own sake; it is to keep critical knowledge durable while moving it to the lowest retrieval depth that still prevents loss. The refactor should produce a smaller always-on agent surface, clearer artifact roles, risk-tiered process rules, and an eval pack that demonstrates whether agents work better against the refactored corpus than they do against today's corpus.

## Motivation

The current repository deliberately over-documents because lost rationale has been expensive: host transitions, runtime behavior, auth and boot-path gotchas, CI edge cases, and agent handover state all need to survive across machines and sessions. That instinct is sound. The downside is that documentation and process discipline can become their own drag: hot files accumulate long narrative comments, ADRs feel too heavy for iterative implementation, and agents may treat every change as if it deserves the same ceremony.

The design loop was introduced to let documentation co-exist with implementation while facts are still emerging. The frustrating part is not the loop itself; it is the pressure for every completed design to leave behind too much permanent record, especially ADRs. ADRs are useful when a decision boundary needs to be frozen, but they are a poor primary artifact for implementation knowledge that should evolve with the system and then collapse into current-state references.

The refactor must answer a concrete question rather than relying on taste: what documentation density makes future humans and agents more effective? The operator wants to see the proposed end state next to the current state and test agent behavior in both versions before adopting the new shape.

Forces:

- **Preserve critical memory.** The refactor must not discard knowledge needed to safely operate, debug, recover, or change the fleet six months later.
- **Reduce ambient load.** Always-on docs and hot implementation files should not force every contributor or agent to read historical context that is only sometimes relevant.
- **Scale process by risk.** Boot, auth, secrets, persistence, networking, security, CI behavior, and fleet-wide changes still earn heavier design, review, and runtime verification. Local reversible changes should stay boring.
- **Prefer current truth over transcript.** Living references and runbooks should describe what is true now. Historical reasoning belongs at lower retrieval depth unless it constrains future work.
- **Keep artifacts honest.** Design notes are mutable working records; ADRs are frozen decision records; runbooks are procedures; research and reviews are point-in-time evidence; root agent instructions are operating rules and pointers.
- **Make agent behavior testable.** The result must include evals that compare agent outcomes across `main` and the refactor branch using fixed tasks and a scoring rubric.
- **Do not rebuild the whole process on speculation.** New checks, hooks, or generated docs should be added only where the evals or repo history show real drift or repeated agent failure.

## Design

Run the work as a branch-local experiment with two side-by-side worktrees:

```bash
git worktree add ../nix-config-main main
git worktree add -b docs/documentation-density-refactor ../nix-config-docs-refactor
```

`../nix-config-main` remains the control corpus. `../nix-config-docs-refactor` carries the proposed documentation architecture and the eval pack. The branch should not preserve the old corpus in copied form; Git already provides the side-by-side comparison.

The target documentation architecture is organized by retrieval depth:

- **Always-on root instructions:** `CLAUDE.md` and, if adopted later, `AGENTS.md` or an import/symlink bridge. These hold repo-wide agent rules, critical stances, risk-tier rules, and pointers. They should be short enough that an agent can retain and follow them every session.
- **Living references:** current-state docs under `docs/<area>/` such as CI, desktop, identities, agent surfaces, and host/fleet conventions. These answer "what is true now?" and should be the default destination for implementation-era findings that remain operationally relevant.
- **Runbooks:** ordered procedures for bootstrap, recovery, migration, activation, and incident response. These should be procedural, sharp, and current, with rationale only where it changes an operator choice under pressure.
- **Design notes:** active or recent design workspace. They evolve while implementation is moving, record forces and de-risk evidence, and should not automatically graduate into ADRs. At closeout, their current truth is reconciled into living references; the note remains as proposed-design history or is explicitly marked complete/historical.
- **ADRs:** frozen records only for durable decision boundaries: a reversal, a cross-cutting invariant, a tradeoff likely to be relitigated, or a constraint that future work must not silently undo.
- **Research and review notes:** point-in-time evidence and audits. They are retained when expensive to recreate or when they explain a rejected path, but they are not normal reading-path docs.
- **Inline comments:** local hazards and non-obvious setting rationale only. A comment should usually answer "why this line exists" in one to three lines. Alternatives, incident chronology, measurements, and migration history belong elsewhere.

The migration proceeds in three thin slices:

1. **Policy slice:** update the design-loop/workflow/agent-facing guidance to state the artifact roles, risk tiers, ADR threshold, and "docs unchanged: behavior and rationale unchanged" escape hatch for low-risk changes.
2. **Corpus slice:** refactor one or two representative high-friction areas, likely CI/check wiring and one host or desktop bundle, moving long narrative from hot files to the right living reference or lower-depth historical note while keeping local hazards inline.
3. **Eval slice:** add a repeatable eval pack under a path such as `docs/evals/documentation-density/` or `tests/agent-docs/` with task prompts, branch setup instructions, scorecards, and recorded results from `main` versus the refactor branch.

The eval pack is part of the design, not an afterthought. It should include a fixed task battery, run in fresh agent sessions against both worktrees with the same model/tooling where practical:

- **Tiny/local change:** a typo, small comment correction, or one-host local reversible edit. Expected: no design note, no ADR, minimal docs.
- **Normal config change:** a single module or host-local setting. Expected: nearby or living-doc update only if behavior or rationale changes.
- **Shared behavior change:** shared helper, bundle composition, host constructor, or generated registry. Expected: finds canonical docs, updates living reference, runs relevant checks.
- **High-risk operational change:** SSH, secrets, boot, persistence, firewall, runtime security, or CI classifier/cache behavior. Expected: slows down, designs the probe, invokes review, avoids casual edits.
- **Ambiguous cleanup request:** "simplify this module" or "clean up docs." Expected: scopes conservatively, does not churn unrelated records.
- **Retrieval task:** "Why is X configured this way?" or "What must I read before changing Y?" Expected: reaches the right canonical source quickly without treating historical notes as current truth.

Each run is scored with the same rubric:

```text
Task:
Branch: main | docs-refactor
Outcome: pass | partial | fail
Risk classification:
Correct canonical docs found:
Unnecessary ceremony:
Missing ceremony:
Critical rationale preserved:
Files touched:
Tool calls / elapsed time / token use if available:
Checks run:
Would accept diff:
Notes:
```

Success means the refactor branch causes agents to produce smaller diffs for low-risk work, create fewer unnecessary ADR/design artifacts, still slow down for high-risk surfaces, find canonical rationale faster, and preserve critical operational knowledge. The branch does not win merely because it is shorter.

This design meets the forces by separating current truth from history, routing long rationale to the right retrieval depth, and making the proposed density change falsifiable through A/B agent evals.

## De-risk evidence

Verified locally in this design pass:

- The repo already has the artifact vocabulary this design relies on: `docs/design/README.md` distinguishes design notes, ADRs, research notes, and living references; `docs/workflow.md` carries rationale placement and runtime-verification rules; `CLAUDE.md` carries agent-facing conventions.
- The repo-local `/design` skill explicitly says ceremony must be sized by blast radius, design work must be dialogue-gated, and ADR creation happens on acceptance only when there is a direction-change. That supports using this note as a proposed working artifact rather than immediately changing implementation rules.
- A quick corpus scan showed a large documentation footprint relative to code: 159 Markdown files and 157 Nix files, plus long comments in CI/check and host configuration paths. This supports investigating density as a real maintenance concern rather than a purely aesthetic preference.
- External prior art supports the ingredients but not the exact integrated design: Diataxis/topic typing for artifact roles, ADRs for frozen decisions, risk-driven architecture for process sizing, topic-based authoring for retrieval, docs-as-code and prose linting for mechanical enforcement, and agent instruction files/hooks/skills for durable agent behavior.

Still unverified:

- Whether agents actually behave better with a shorter always-on surface and clearer artifact thresholds.
- Which corpus areas produce the biggest return from refactoring.
- Whether `AGENTS.md`, `CLAUDE.md`, nested rules, skills, or hooks should be the final durable agent mechanism for this repo.
- Whether any new lint/check is warranted, or whether the right answer is mostly prose policy plus evals.

The load-bearing assumption is: **documentation density and artifact-role clarity measurably affect agent behavior.** The eval pack is the test. A result showing no improvement, or worse high-risk behavior, should kill or significantly narrow the refactor.

## Drawbacks

This can become another layer of process about reducing process. A documentation-density refactor that adds a taxonomy, eval harness, new rules, and new maintenance files without deleting or compressing anything would worsen the problem it is meant to solve.

The A/B evals may be noisy. Agent runs vary by model, context, prompt wording, branch state, and tool availability. The result will not be a statistically rigorous benchmark unless the project invests much more machinery than this decision likely warrants.

Moving history down a retrieval layer can feel like losing it. Even when knowledge remains in git, PRs, research notes, or historical design notes, it is less visible than a long comment beside the setting. That is the point, but it is also the emotional risk that caused the over-documentation habit in the first place.

The branch may be hard to review if it tries to right-size the entire corpus in one pass. The refactor should start with representative slices and evals, not a wholesale rewrite.

## Cost

The standing cost is maintaining the eval pack and periodically re-running it when the agent instruction surface changes. If the evals are not kept cheap enough to run, they will become performative documentation.

There is also a review cost: reviewers must distinguish "knowledge deleted" from "knowledge moved to a lower retrieval depth." That requires clear commit structure and good before/after pointers.

## Rationale & alternatives

**Chosen: branch-local documentation refactor plus A/B agent evals.** This directly addresses the operator's requirement: see the end state alongside the current state, and decide from observed agent behavior rather than faith. It lets the project test a smaller always-on surface without risking `main`.

**Alternative: edit policy first, then gradually clean opportunistically.** This is lower effort, but it does not answer whether the new policy works. It also risks leaving the corpus in a half-old, half-new state where agents receive contradictory signals.

**Alternative: wholesale rewrite of docs without evals.** This may feel cleaner, but it is taste-driven. It could delete useful context, weaken high-risk caution, or merely move the same prose around.

**Alternative: keep current density and add more lints.** This preserves memory, but it does not solve ambient load. More enforcement may make the drag worse unless tied to demonstrated failures.

**Alternative: move most historical material out of repo.** Rejected for now. The repo's operating model depends on Git as durable cross-host memory. The problem is not that the knowledge is in Git; it is that too much of it sits at high visibility and in hot paths.

**Impact of doing nothing:** the repo keeps accumulating durable but high-friction context. Agents remain biased toward over-ceremony because the always-on instructions and nearby comments make heavy process look normal even for small changes.

## Prior art

This design assembles prior art rather than adopting one framework wholesale:

- **Diataxis** separates documentation by user need: tutorials, how-to guides, reference, and explanation. The relevant lesson is artifact role clarity: do not make one document serve every purpose. See <https://diataxis.fr/> and <https://diataxis.fr/start-here/>.
- **GitLab topic types** are a practical large-project example of concept/task/reference/troubleshooting separation and prose linting discipline. See <https://docs.gitlab.com/development/documentation/topic_types/concept/> and <https://docs.gitlab.com/development/documentation/testing/vale/>.
- **Michael Nygard ADRs** support small, modular, persistent decision records that remain when superseded. The relevant limit is that ADRs freeze decisions; they should not become the primary co-evolving implementation artifact. See <https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions>.
- **Risk-driven architecture** supports scaling design effort to actual risk rather than applying uniform ceremony. See <https://www.georgefairbanks.com/software-architecture/risk-driven-model/> and <https://www.georgefairbanks.com/book/>.
- **Every Page is Page One and topic-based authoring** support self-contained, specific-purpose pages that readers and agents can enter directly, with links for depth. See <https://everypageispageone.com/the-book/> and <https://docs.oasis-open.org/dita/v1.0/archspec/topics.html>.
- **Docs-as-code** supports keeping docs versioned, reviewed, and checked beside implementation. See <https://www.doctave.com/docs-as-code>.
- **Agent instruction files and scoped rules** support the durable-agent side of the design: short always-on guidance, scoped rules, on-demand skills, and deterministic hooks where judgment-free enforcement is needed. See <https://agents.md/>, <https://code.claude.com/docs/en/memory>, <https://code.claude.com/docs/en/features-overview>, <https://docs.cursor.com/context/rules>, and <https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions>.
- **Poka-yoke / mistake proofing** maps to the repo's existing "enforced, not stated" instinct: use checks or hooks where a repeated error is costly and mechanically detectable. See <https://www.lean.org/lexicon-terms/poka-yoke/> and <https://asq.org/quality-resources/mistake-proofing>.

Within this repo, the closest prior art is `docs/design/design-loop.md`, `docs/workflow.md` "Rationale lives in one place", ADR-032's proportionate enforcement stance, ADR-037's doc mutability contracts, and the generated/checkable keybind and host-census precedents.

## Unresolved questions

1. **What is the branch acceptance bar?** Candidate: accept only if the refactor branch beats `main` on low-risk ceremony reduction without regressing high-risk caution or rationale retrieval.
2. **Where should the eval pack live?** Candidate: `docs/evals/documentation-density/` if the primary output is evidence and scorecards; `tests/agent-docs/` only if it grows executable harnesses.
3. **What is the always-on agent file strategy?** Candidate: keep `CLAUDE.md` as the current Claude-facing entry point and consider `AGENTS.md` only as a compatibility bridge once the content is compressed.
4. **How much current corpus should the first branch refactor?** Candidate: two representative areas only, enough to test the pattern without making review unbounded.
5. **What happens to completed design notes?** Candidate: keep them in place with clear status, but make living references the current-truth target and stop treating ADR graduation as default.
6. **Should a new lint enforce density?** Candidate: no for the first slice. Use eval results and reviewer feedback before adding mechanical enforcement.

## Future possibilities

- A small `docs/evals/README.md` convention for future human+agent eval packs.
- A repo-local skill for documentation-density reviews, invoked when a change touches `CLAUDE.md`, `docs/workflow.md`, ADRs, or long module comments.
- A periodic claims-audit that samples living references against implementation, narrower than a whole-corpus coherence sweep.
- A generated index of current-truth docs versus historical notes if agents continue to confuse point-in-time research with present operating truth.
- A cross-agent instruction bridge where `AGENTS.md` is canonical and `CLAUDE.md` imports it with Claude-specific additions, if multi-agent support becomes more important than preserving the current Claude-first entry point.
