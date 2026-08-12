# Workflow conventions

How work moves through this repo: how issues are framed, how implementations are paced, how diffs reach `main`. The [philosophy](./philosophy.md) doc captures the *technical* stances that shape what we build; this doc captures the *process* stances that shape how we build it.

These conventions emerged organically across the niri desktop buildout (#69–#77) and have been articulated incrementally as operator–AI feedback. This doc collects them in one place so a fresh contributor (human or AI session) can read them cold without needing operator-side handover. AI memory files reference here rather than duplicating content, matching the pattern in [docs/README.md](./README.md) §"Audience and intent".

Each convention has a *why*: the constraint or experience that produced the rule. When a convention conflicts with convenience, the convention wins; when in doubt, prefer the option most aligned with these.

## Intent-first framing

**Rule.** Frame work in three layers — intent → scope → implementation. The *intent* is the operator's "why"; the *scope* is what work needs to happen to satisfy the intent; the *implementation* is how. Issues capture intent and scope. Implementing sessions derive the how.

**Why.** Implementations chosen at issue-creation time are made without the evidence that only surfaces during the work itself (closure costs, upstream surprises, ecosystem changes, peer-review feedback). Pre-deciding forecloses options that would only become visible at implementation time, often producing worse outcomes than a deferred decision would. Separating intent from implementation also makes issues legible to fresh contributors: the *why* survives even when the *how* changes.

**How it shows up.**

- Issue bodies open with intent (one or two sentences naming what the operator wants to be true after this work lands) before any scope or task list.
- "Open decisions for the implementing session" sections in issue bodies enumerate what is deliberately *not* pre-decided.
- Implementing sessions begin by reading the intent, then propose shape/approach to the operator before cutting code.

## Issues specify the work, not the work product

**Rule.** Issues define what needs to be decided and built. They don't pre-bake the solution. Pre-deciding implementation details (specific package selections, configuration values, ADR numbers, exact rationale) inside an issue body is doing the work of the issue prematurely.

**Why.** When an issue body contains "use package X with configuration Y for reasons Z", the implementing session can't honestly evaluate alternatives — the alternatives were excluded before evidence arrived. The implementing session either rubber- stamps the pre-decision (no real evaluation happened) or has to argue against an absent author (the operator who wrote the issue, days or weeks ago, isn't in the room). Both outcomes degrade decision quality.

**How it shows up.**

- Issue bodies say "select X" or "decide X"; not "use X".
- Sibling alternatives are named in "Open decisions" sections so the implementing session knows the consideration space without being steered to a conclusion.
- When the operator does have a strong preference, it's surfaced as a *preference* ("operator leans X; needs rationalisation"), not as a foregone conclusion.

## Documentation precedes implementation for selections

**Rule.** For every selection — tool, font, application, bind, host policy — the rationale doc lands *before* the implementing commit. Either as a preceding commit in the same PR, or as a preceding PR linked to the same issue.

**Why.** The doc captures *why* at the moment of decision; future readers follow the trail from doc → implementation. When code lands first and docs follow, the doc is written under "I've already shipped this, let me justify it" framing — a fundamentally different exercise than "I am about to ship this, let me prove the reasoning holds". The first produces marketing; the second produces honest record. The doc-first order also makes peer review meaningful: reviewers can evaluate the reasoning before the code anchors them.

**How it shows up.**

- See [docs/desktop/README.md](./desktop/README.md) §"Conventions for evolution" — selection landing with implementation = 2 commits (doc, then code); selection landing with a keybind = 3 commits (doc, code, bind manifest update). The doc commit is always first.
- Living documents (per-tool selection docs, font docs, bind docs) are amended in-place rather than rewritten when new selections land.
- Drift between doc and implementation is treated as a cadence bug: if the codebase carries a binding/font/tool not represented in the relevant doc, fix the doc.

## Peer-review staged diffs before commit

**Rule.** Every staged diff (every `git add` set en route to a commit) is reviewed by an independent subagent before the commit lands. Findings — BLOCKING, SHOULD-FIX, NICE-TO-HAVE — are passed through to the operator with recommendations. Commits wait for operator approval.

**Why.** AI agents (and humans) anchor on their own work. A fresh-context reviewer surfaces issues the implementer missed because the implementer wrote the same code minutes ago. The specific subagent pattern (independent context window, focused review prompt with the actual files + intent + scrutiny axes) catches real bugs at a rate substantially higher than self-review. The canonical class of catch is "Stylix-target wires that silently no-op under our `autoEnable = false` whitelist because an `enable = true` toggle looks redundant alongside operator-required config" — the kind of gating subtlety the implementer accepts because they're anchored to the planned shape, but a fresh-context reviewer catches in seconds. Showing the diff in chat is *not* the same as peer review; the diff displayed in conversation gets the operator's eyes, not an independent reviewer's.

**How it shows up.**

- Implementing sessions invoke a subagent with the full prompt shape: files in scope, intent, build-verification status, scrutiny axes (doc-implementation lockstep, closure correctness, head-comment quality, lint surface, etc.), and output format (numbered findings + severity + verdict).
- Peer-review findings reach the operator before any commit fires. The operator's "land" or "fix-then-land" decision is the gate.
- Verdicts are calibrated: LAND-AS-IS, FIX-THEN-LAND, NEEDS-DISCUSSION. NEEDS-DISCUSSION pauses the work for operator input rather than guessing.

**Verifying the lint surface locally.** `nix flake check --no-build` *evaluates* the `pre-commit` and `treefmt` check derivations but never *runs* them, so statix / nixfmt / deadnix violations on new or edited files pass locally and only fail in CI. To run the hooks for real before pushing, build the check derivation directly: `nix build .#checks.<system>.pre-commit --no-link` (e.g. `.#checks.aarch64-darwin.pre-commit`), and likewise `.#checks.<system>.treefmt`. Catches the empty-pattern / formatting class of failure that `--no-build` waves through.

**In a nix-less cloud container** neither that build nor the linters it runs are available, and the cloud-session equivalent is `bash scripts/fetch-lint-toolchain.sh`, which installs the pinned linter set into `$HOME/.local/bin` so the same verdicts are reachable before pushing — mechanism, pins and the accepted version skew in [docs/design/cloud-session-lint-toolchain.md](./design/cloud-session-lint-toolchain.md).

## Peer review binds to what executes, not what's committed

**Rule.** Peer review attaches to what will *run* on a host — whether by the operator or by the agent on their behalf — not only to what lands in a commit. Any script, command sequence, or choreography destined to execute on a host — a one-liner handed over in chat, a script left in a session scratchpad, an activation or migration step embedded in a PR body, a command the agent runs in its own shell — gets the same adversarial subagent review as a staged diff (§"Peer-review staged diffs before commit"), *before* it executes. Root execution, or any surface on the auth or boot path, makes this non-waivable — the artifact's size or apparent triviality earns no exemption. Incident response *raises* this bar rather than suspending it. Boot- or auth-path changes additionally require a runtime rehearsal — a VM reboot at minimum — before activation on hardware; build or eval verification alone does not qualify.

**Why.** The staged-diff rule binds review to artifact *type*: code and docs travel to `main` through `git add`, so they get reviewed; operational glue handed over out-of-band does not, so it escapes. But blast radius tracks what *executes with what privilege*, not whether the bytes were committed. The highest-risk artifact is frequently the one that never enters the tree — a root script that reaches into the auth or boot path — while a mere document *about* recovery collects the full adversarial battery. Reviewing the safe artifact and waving through the dangerous one inverts the scrutiny that risk warrants. Incident response is exactly when this inversion bites hardest: mid-incident the operator is under pressure, the affected box may be the only one reachable, and the fix runs as root against the very surface whose failure locks them out — so an unreviewed root script does its most damage precisely when the temptation to skip review is strongest. And a boot- or auth-path change can build green yet still wedge the next reboot (the set ≠ enforced gap, [#303](https://github.com/dannyfaris/nix-config/issues/303)), so a throwaway-VM reboot is the cheapest place to discover the wedge before hardware does. See [#553](https://github.com/dannyfaris/nix-config/issues/553)'s 2026-07-30 incident comments for the lockout that produced this rule.

**How it shows up.**

- An operational artifact — a `sudo` one-liner, a scratchpad script, PR-body activation steps, or a command the agent is about to run itself — is routed to a subagent with the same prompt shape as a staged diff (the exact commands, the intent, the host and privilege they run under, the scrutiny axes) before it executes.
- Root or auth/boot-path surface is review-mandatory: there is no "too small to review" carve-out, and an active incident tightens the gate rather than relaxing it.
- Boot- or auth-path changes are rehearsed on a VM — an actual reboot, not just a build — before they run on hardware, and the rehearsal outcome is reported alongside the peer-review verdict.

## Negative claims about upstreams carry their check

**Rule.** A negative external claim in an issue's evidence — *abandoned*, *unmaintained*, *unblessed*, *cannot do X*, *stalled* — carries a link to what was checked and the date it was checked, or it is phrased as a question. A blanket "re-verify rather than trust" header does not discharge this: it reads as a waiver, not a control.

**Why.** These claims eliminate options, and an eliminated option is never revisited, so the claim is never checked again. [#763](https://github.com/dannyfaris/nix-config/issues/763) is the worked example: its evidence asserted that a maintained fork was "unblessed by sodiboo" and that "11 of its last 12 commits are bot lockfile updates". Both were checkably false at authorship — the fork's announcement had been pinned in the upstream repo three days earlier, and 32 of its last 100 commits are human, from four contributors. The claims were written in a nix-less session, restated in the operator ruling the next day, and restated again as uncited fact inside the design note, whose own unverified-claims list omitted them while cataloguing softer ones. A full design loop, two built slices and nineteen review subagents all ran on top; an outside commenter caught it. The design-loop amendments that followed ([design-loop.md](./design/design-loop.md) §De-risk evidence) bind at the *ruling*; this one binds where the claim is authored, which is a day earlier and one glance cheaper.

**How it shows up.** "Upstream looks stalled — last merge 2026-05, PRs #1849/#1850 closed unmerged (checked 2026-08-10)" rather than "upstream is abandoned". Where the check is genuinely not available — a nix-less container, no network — the claim is a question the implementing session must answer, not a finding it may consume.

## Runtime claims are probe-verified

**Rule.** A change asserting runtime, security, network-posture, or CI behaviour is done when that behaviour has been observed live, not when it merges. The probe is designed *before* the change lands: name in advance the observation that would falsify the claim, and the result that would abort rather than confirm it. The record then separates observation from projection, so an unverified assertion stays labelled as one, not promoted to fact. [CLAUDE.md](../CLAUDE.md) §"Claims about runtime behaviour need runtime verification" owns the rule and the set ≠ enforced gap it closes ([#303](https://github.com/dannyfaris/nix-config/issues/303)); this is the choreography that discharges it.

**Why.** Design review, implementation review, and adversarial verification all read the *declared* state; only a probe reads the enforced one. One CI campaign ran every change through all three; its probes still caught two defects all three had passed: a cheap-path pre-step that could not evaluate against its own cold store (#699), and a classifier whose diff basis froze at PR-creation time, so its short-circuit stopped firing once `main` advanced (#703). The same pass surfaced a third case — a documented per-run cache refresh that PR runs are structurally incapable of performing, so the declaration and the enforcement had to be re-scoped to match ([#702](https://github.com/dannyfaris/nix-config/issues/702)).

**How it shows up.**

- Probes ride throwaway pull requests: drafts titled `probe(#N): … — DO NOT MERGE`, the scope mapping a stray branch back to its issue, closed unmerged. Undeletable branches are named in the verification comment for an operator sweep.
- An ordering-sensitive probe is re-triggered by an empty commit, forcing GitHub to recompute the merge ref against the *current* base — never `gh run rerun`, which replays the SHA already recorded. The before/after claim is banked as a counterfactual pair: frozen basis versus live, against identical SHAs.
- Assertions are designed for retrievability: the log tooling may only tail, so assert where the record is readable — log *ends*, short logs — and state the coverage window, not an implied end-to-end read.
- A state-machine change — a cache, a save/restore cycle — is verified over **cycle pairs**: two complete cycles, untouched legs as controls, expectations pre-stated as in-band ranges, an abort threshold and its revert cost fixed before cycle 1, and, where the design inverts what a healthy run looks like, the inverted assertions — which lines must now be *absent*, which deletions are expected.
- Anything needing a real `nix` or an authed `gh` becomes an operator gate: an exact command block, adversarially reviewed before it executes (§"Peer review binds to what executes, not what's committed"), carrying up front the observation that means abort, and gated on the numbers reported back.
- Rendering/theming probes use **instrumented discrimination, never aesthetic similarity**: inject sentinel values no palette would produce (garish colours) and assert their presence or absence — pixel-sample where possible — rather than judging whether two windows "look the same". Similarity judgments confabulate: the #771 probe read stock Adwaita as a followed palette because both windows matched *each other*; the #777 garish/pixel-sampled re-probe overturned it.
- Probes on a live session leave no residue: app-level experiments isolate under a scratch `XDG_CONFIG_HOME` instead of touching real config; spawned apps are killed **by PID** (`pkill -f` self-matches the probing shell's own command line); any runtime state the probe re-pointed (theme symlinks, dconf keys) is restored *and the restore verified* before the probe reports — an unrestored symlink from an earlier #777 probe step survived two experiments unnoticed.

**Worked examples** as history, not rationale: the #412 probe series and its two caught defects on PR #695; the stale-base choreography on PR #706; the cycle pairs and pre-declared threshold that stopped a first attempt on [#712](https://github.com/dannyfaris/nix-config/issues/712).

## Sense-check `main` before implementing a planned slice

**Rule.** Before implementing a planned slice — especially when the plan was drafted in a prior session or across hours of elapsed time — pull `origin/main` and re-read the plan-relevant files. Surface drift before coding.

**Why.** Plans go stale silently. `main` advances; the file the plan touches may have been refactored since; dependencies the plan assumed may have shifted; sibling work merged in the interim may overlap with the planned slice. Catching drift before the first `git add` saves writing code against the wrong state of the world.

**How it shows up.**

- Implementing sessions begin with `git checkout main && git
  pull --ff-only origin main`, then `Read` the files named in the plan.
- If drift is found, the implementing session names it ("the plan assumes X but `main` now has Y") and proposes how to resolve before cutting code.
- For long-running sessions where the implementing-session branched off main hours ago, periodic rebases against `origin/main` keep the working state honest.

## Dependencies via linked issues, not phase numbering

**Rule.** Issue titles don't carry "Phase #N" signifiers. Sequencing between issues is expressed through linked dependencies (GitHub's "Depends on" line in the body, or explicit cross-references), not encoded in the title.

**Why.** Phase numbers age badly. Phase 3 of an epic that later expands becomes "Phase 3 (of 7)" then "Phase 3 (of indeterminate)"; the number stops carrying useful information once the scope shifts. Linked-issue dependencies, by contrast, remain accurate as the graph evolves — adding a new dependency or removing a satisfied one just edits the relationship. Phase numbering also implies a rigid linearity that the actual work rarely respects: parallel slices, abandonment of branches, re-ordering of priorities all undermine the numbering. Titles focused on the *thing* (e.g. "fnott notification daemon") read accurately at any point in the graph's life.

**How it shows up.**

- Recent issue titles: "fuzzel launcher (Mod+Space)" (#73), "fnott notification daemon" (#74), "waybar status bar" (#75) — none carry phase numbers.
- Dependencies use the issue body's "Depends on" footer ("Depends on #71, #70" — #76's body) which GitHub renders as a relationship.
- Epics (the mac-mini onboarding epic #11, for instance) use a parent-epic-with-child-issues shape; the parent enumerates children, the children link back, no phase numbers.

## Bundle vs single-PR cadence

**Rule.** Foundational sweeps that affect multiple files across the repo may bundle multiple PRs under one issue, with an explicit "this issue closes when all listed PRs have merged" acceptance. Per-tool, per-doc, and per-selection issues are typically a single PR.

**Why.** Some work has natural multi-PR cadence — for instance, a foundation refactor that touches the system layer, the home layer, and the host composition layer benefits from being three small PRs each with focused peer review, rather than one unreviewable mega-PR. Each PR's diff stays small enough to review meaningfully; the parent issue tracks the umbrella. Conversely, per-tool selections are a single coherent unit — splitting them would scatter the rationale across PRs and obscure the cause-effect link between the selection doc and the implementing module.

**How it shows up.**

- ADR-028 foundation sweep landed across PRs #42, #44, #55, #60, #62 — each focused on one layer; the parent epic tracked completion.
- Per-tool selections (foot #72, fuzzel #73, fnott #74, waybar #75, firefox #76) each landed as a single PR with a 2-commit doc-then-code cadence.
- The acceptance section of the parent issue lists the required PRs explicitly so close-out criteria are clear.

## Operator approval before bulk action

**Rule.** Drafts of multi-step or destructive operations — issue bodies, plan files, peer-review verdicts, batch deletions, force-push proposals — are presented to the operator for approval before any action is taken. The default is "show, then ask"; the operator's "go" is the gate.

**Why.** Bulk operations have outsized blast radius. A wrongly- worded issue body broadcasts to anyone who reads it; a mis-targeted branch deletion loses commits; a force-push overwrites upstream. The cost of pausing to confirm is small (one extra round-trip in the conversation); the cost of an unwanted bulk action can be large (lost work, public miscommunication, hard-to-reverse state changes). Even when the operator has authorised a category of action ("clean up stale branches"), the specific instances often deserve a one-line surface ("these 15 are PR-merged; these 2 carry unique commits not on main — delete those too?") before execution.

**How it shows up.**

- Draft issue bodies are shown in chat before `gh issue create` fires.
- Peer-review verdicts (LAND vs FIX-THEN-LAND) are surfaced to the operator before the commit, not just included in the agent's summary.
- Branch deletions with unique commits are paused for explicit confirmation even under "do a full cleanup" authorisation.
- See also CLAUDE.md §"Deliberate stances" for the technical posture (no-mutable-users, key-only SSH, whitelist-not-blanket) that pairs with these process stances.

## Propose order; don't multi-question

**Rule.** When the next steps are non-exclusive and clearly beneficial — that is, when each step stands on its own and they don't trade off against each other — propose an order and proceed. Reserve multi-select questioning (AskUserQuestion or chat-level multi-option prompts) for genuine tradeoffs where the operator needs to pick one path over another. One deliberate exception: within the `/design` loop's design stages (intent through the start of build), this autonomy inverts — advancing takes the operator's stated agreement, and eliciting rulings *is* the work, not stalled momentum ([docs/design/design-loop.md](./design/design-loop.md) §"The dialogue contract").

**Why.** Treating additive next steps as a multi-select question imposes decision overhead for no payoff: each step would land anyway, so framing them as alternatives wastes the operator's attention and slows momentum. Genuine tradeoffs deserve the extra ceremony of explicit choice; routine accretive work doesn't. The implementing session is doing the operator a service by *not* manufacturing decisions where none exist.

**How it shows up.**

- "Should I open the PR, then enable auto-merge, then close the linked issue?" → just do it; report results.
- "Two valid wirings, A and B; A is faster but B is more general — which do you prefer?" → genuine tradeoff, ask.
- When in doubt, propose the order ("I'll do A then B then C — flag if you want a different order"); proceed if no objection arrives.

## PRs land via squash auto-merge

**Rule.** After `gh pr create`, run `gh pr merge <num> --auto
--squash` to enable auto-merge. The PR squash-merges itself once required checks pass.

**Why.** Squash gives main a clean, linear history where each commit corresponds to one issue/PR. Auto-merge removes the manual-merge step from the loop while still gating on CI.

**How it shows up.**

- All landed PRs in this repo's `git log` show as `<scope>: <action> (#issue) (#pr)` — the squash subject the GitHub UI generates.
- Local branches deleted after merge (manually via `git branch
  -D`, since squash doesn't show as merged via `git branch
  --merged`).
- See also CLAUDE.md §"Conventions" for the same instruction surfaced to AI sessions.

## Markdown is soft-wrapped

**Rule.** All markdown in the repo — docs, ADRs, this file, READMEs — is soft-wrapped, bar the generated `docs/desktop/keybinds.md` (below): one line per paragraph, no hard newlines mid-paragraph. Tracked `.md` files are formatted to this shape by dprint via treefmt (`nix fmt`), the mechanism selected in [ADR-046](./decisions/ADR-046-markdown-formatter.md) and wired in #435 PR B (#738). Issue and PR *bodies* stay hand-authored soft-wrapped — the formatter cannot reach `gh` descriptions. List items, table rows, and fenced code keep their natural line structure. This is true soft-wrap, not semantic line breaks (one sentence per line).

**Why.** Hard-wrapping prose buys nothing on GitHub: GFM collapses a single newline *within a paragraph* into a space, so hard- and soft-wrapped markdown render identically. What it costs is reflow churn: a one-word edit early in a hard-wrapped paragraph reflows every following line, burying the real change under wrapping noise in the diff. Soft-wrap trades that for paragraph-granularity diffs, which read cleanly under GitHub's rendered diff and `git diff --word-diff`. The line-level-diff benefit hard-wrap nominally offers rarely bites here: prose is edited at paragraph scale, review happens over rendered/word diffs and content-focused peer review, and blame/bisect on prose is rarely load-bearing. Mechanizing the shape (rather than leaving it a hand-authored habit) is what stops the convention drifting silently into mixed-wrap files — the [ADR-046](./decisions/ADR-046-markdown-formatter.md) decision.

**How it shows up.**

- The formatter (dprint via treefmt) reflows every tracked `.md` to one line per paragraph on `nix fmt` — bar `docs/desktop/keybinds.md`, excluded whole-file in `parts/formatter.nix`: its generated hyper-bindings region is byte-diffed against the registry emitter, so the file keeps its emitted shape, hard wraps included. The one-off tree-wide reflow landed with the wiring (#435 PR B, #738). The earlier "no tree-wide reflow PR" reservation is retired — mechanizing the convention made the one-off reflow the point, not a hazard.
- Helix renders markdown soft-wrapped via the per-language entry in `home/shared/editor.nix`; it is display-only and never alters file bytes.
- Issue and PR bodies are authored soft-wrapped by hand, since the formatter does not reach them.

## Rationale lives in one place

**Rule.** Decide *where* a rationale lives before writing it, keyed on length: a one- or two-line *why* stays inline beside the setting; anything longer is authored into a single canonical home — the relevant ADR or `docs/<area>/` doc — and the code points to it. The length-tiering itself is defined once in [ADR-032](./decisions/ADR-032-proportionate-enforcement-and-rationale.md) (Rule 2); this section is the process habit that applies it — write the doc, then point, rather than letting the same *why* accrete in a comment *and* a doc *and* an ADR.

**Why.** Duplicated rationale drifts exactly like duplicated state, and the drift is silent — it surfaces only when the two copies disagree. Tiering by length keeps each *why* findable (long-form reasoning in the doc designated for it) and the modules readable (configuration, not essays). The full reasoning, and the companion rule that enforcement machinery earns its weight by what it guards, live in [ADR-032](./decisions/ADR-032-proportionate-enforcement-and-rationale.md).

**How it shows up.**

- A module carries a one-line `# see docs/<area>/<tool>.md` pointer where a per-tool doc owns the detail, rather than an inline essay duplicating it.
- Decisions with alternatives and consequences are ADRs; the code points to the ADR number, not a paragraph re-deriving it.
- Drift between a doc and the code it explains is a cadence bug, fixed by reconciling to the single source — the same treatment selection-doc drift gets above.
- Incident provenance — a PR-number root cause, a dated "observed" note, a timing measurement — stays in the PR/commit (or an ADR §History), not inline. A comment gives the evergreen *why the setting is what it is*; `git blame` reaches the *how we found out*. The test: does the sentence say what would break if the setting changed, or only how someone once found out it breaks? The latter is history — route it out, keep at most a one-line pointer. See [ADR-032](./decisions/ADR-032-proportionate-enforcement-and-rationale.md) (Rule 2 corollary).

## See also

- [docs/philosophy.md](./philosophy.md) — the technical principles that shape *what* we build (declarative, whitelist, single source of truth, etc.). This doc's process principles sit alongside.
- [docs/desktop/README.md](./desktop/README.md) §"Conventions for evolution" — the doc-before-code commit cadence applied specifically to desktop-env selections.
- [docs/decisions/](./decisions/) — Architecture Decision Records: where individual technical decisions are recorded. Conventions here govern *how* ADRs and selection docs are produced; ADRs themselves capture the *what*.
- [CLAUDE.md](../CLAUDE.md) — the AI/contributor entry point. Points here for process conventions; carries the operational stances (mutableUsers, SSH posture, etc.) in its own §"Deliberate stances" section.
