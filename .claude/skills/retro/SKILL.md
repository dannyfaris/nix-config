---
name: retro
description: Retrospective on the design loop itself — assess how well the loop and its harness (the /design skill, the design-note template, the structure lint, the peer-review checklist, the CLAUDE.md pointer) performed on a real run, using evidence from the Claude transcript, git history, and the checks, then recommend data-backed improvements to both the loop (design-loop.md) and the harness. User-invoked with /retro, during or after a design process. Not for reviewing a design note's content — the /design peer-review checklist does that.
disable-model-invocation: true
---

# Retro

Assess how the [design loop](../../../docs/design/design-loop.md) and its harness actually performed on a real run, and recommend **data-backed** improvements to both. This is the loop's *self-validating* force made operational — it produces the evidence the loop's own De-risk scorecard and "refute the loop if…" criteria are built to consume, so each retro feeds the next revision of `design-loop.md`.

Distinct from peer review: peer review judges *a design note's content* (the `/design` checklist). Retro judges *the loop and its machinery* — did the stages hold, did the harness catch what it should, where did the human have to step in.

## When this applies

During or at the end of a design process — or periodically across several. Most valuable right after a run where something went wrong (a step got skipped, review caught a blocker, a lint false-fired): that friction is the data.

**When it does not:** trivial work that never engaged the loop. There is nothing to retro.

## Gather the data first (no vibes)

Every claim must cite an instance. Extract the *signal*, not raw content — never paste transcript lines wholesale into the report (they may carry secrets); quote only the short phrase that evidences a finding. Pull from, in rough order of richness:

1. **The Claude transcript(s).** Claude Code stores one JSONL per session under `~/.claude/projects/<encoded-cwd>/`, where `<encoded-cwd>` is this repo's absolute path with `/` → `-` (on this host, `-Users-dbf-nix-config`) — don't hardcode it across hosts; locate it with `ls -dt ~/.claude/projects/*nix-config*/`. A run can span **several** sessions over days, so scope by date/topic across files, not just the newest. The files are large — *grep for signals*, don't read whole:
   - **Operator interrupts (the most reliable signal)** — grep the canonical marker `Request interrupted by user`; each marks a point the loop/harness failed to catch before the human stepped in. Supplement with substantive correction phrasing ("where is the problem statement", a rejected tool use), but treat the marker as primary.
   - **Solution-first openings** — the agent drafting mechanism before problem/forces (intent-first breaking).
   - **`--no-verify` overrides** — grep the transcript for `--no-verify` and the lint's failure text. This is *transcript-only* evidence: a `--no-verify` commit leaves no trace in git metadata.
   - **De-risk ordering** — was the load-bearing assumption tested before building, or after.
2. **Git history** — `git log`, the design note(s) under `docs/design/`, the PRs. Check: did the living-reference update land in the *same* commit as the code (reconcile)? How many review → fix cycles before merge?
3. **Harness signals** — did `scripts/lint-design-note.sh` fire, and catch a real defect or false-fire? Did the `/design` skill actually get invoked, or was the loop run from memory? Was the template the starting point? Peer reviews run as subagent (`Task`) calls: their *internal* transcript isn't in the session file, but each returned verdict (`BLOCKER` / `SHOULD-FIX` / `LAND-*`) is greppable inline — count the verdict tags and review calls; per-round attribution means correlating sequential reviews over the same files, so don't over-promise its precision.
4. **The yardstick** — `docs/design/design-loop.md`: its Forces, its "refute the loop if…" criteria (Unresolved questions), and its open items. Score against these, not against a fresh standard.

## Score, then recommend

Work the rubric in [`scorecard.md`](scorecard.md): a *held / broke / n-a* verdict per loop stage and per harness piece, each with a cited instance. Then:

- **Split the recommendations in two**, as the brief requires:
  - **Loop changes** — to `design-loop.md`: a stage that needs reframing, a force that never bit, a size-gate miscalibration, a refutation criterion that moved.
  - **Harness changes** — to the machinery: skill wording that an agent still skipped past, a lint rule to add/loosen, a new check, a checklist item, a template tweak.
- **Move the refutation criteria.** For each "refute the loop if…" in `design-loop.md`, say which way this run's evidence pushed it. This is how the loop earns or loses confidence.
- **Weight by evidence.** A recommendation backed by three transcript instances outranks a one-off. Call out small-N explicitly; one run is a signal, not a proof. Distinguish "held" from "no data" — an untested stage is not a passing one.

## Output

A short retro report, in this order:

- **Headline** — one or two sentences on how the loop held this run. A narrative, *not* a grade: a single score invites the falsely-rosy/damning reduction the rubric guards against.
- **Scorecard** (with citations), the **two recommendation lists** (loop vs harness), and the **refutation-criteria movement**.

The recommendations are *candidates* — they feed the next `design-loop.md` revision (via `/design` if the change is non-trivial) or new issues, closing the self-validating cycle. The retro records the evidence; it does not unilaterally rewrite the loop.

## See also

- [`docs/design/design-loop.md`](../../../docs/design/design-loop.md) — the loop under test; its Forces and refutation criteria are the yardstick.
- [`.claude/skills/design/SKILL.md`](../design/SKILL.md) — the loop's procedure; the harness this retro assesses.
