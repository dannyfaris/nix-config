# Retro scorecard

Score each row *held* / *broke* / *n-a (no data)*, with a cited instance
(transcript line, commit, PR, or check result). "Broke" is not failure — it
is the data the loop exists to surface. An honest *n-a* beats a guessed pass.

## Loop stages (yardstick: design-loop.md §The loop)

| Stage | Signal that it held | Signal that it broke |
|-------|---------------------|----------------------|
| 1 Intent | Note/PR opened with problem + forces before any mechanism | Agent drafted the solution first; human asked "where's the problem?" |
| 2 Size | Ceremony matched blast-radius (heavy note for cross-cutting; just-build for local) | A one-line change got a full note, or a cross-cutting change skipped design |
| 3 Design | Options weighed against the stated forces; choice legible | Decision asserted; no real alternative; a force stated but never used |
| 4 De-risk | Load-bearing assumption tested *before* building, result recorded | Built first, discovered the assumption was wrong later |
| 5 Build | Thinnest slice; abstraction only with a real consumer | Abstraction built on forecast; scope beyond the note |
| 6 Peer-review | Independent review ran before commit; caught real issues | Skipped, or rubber-stamped; blockers found post-merge |
| 7 Reconcile | Living-reference update landed in the *same* change as the code | Docs reconciled in arrears, or not at all |

## Harness pieces (the machinery under test)

| Piece | Held | Broke |
|-------|------|-------|
| `/design` skill | Invoked; its stages were followed | Loop run from memory; skill ignored or never loaded |
| Design-note template | The note started from it; structure came for free | Authored ad-hoc; sections missing/misordered |
| `lint-design-note.sh` | Caught a real structural defect | Never fired when it should have, or false-fired on a valid note (→ harness change) |
| Peer-review checklist | Surfaced a judgment issue the lint can't see (intent-first, weigh-alternatives) | Not used; the judgment checks went unmade |
| CLAUDE.md pointer | The loop was recognised and entered | Design work happened without the loop being recalled |

## Quantify where you can

Cheap counts that make the report data-backed, not anecdotal:

- Operator interrupts (`Request interrupted by user`) in the transcript, and which stage each maps to.
- Peer-review verdict tags (`BLOCKER` / `SHOULD-FIX` / `LAND-*`) and review (`Task`) calls — a falling blocker count across successive reviews = the loop converging; a flat one = review doing the loop's job. Per-round attribution needs correlating sequential reviews over the same files; don't over-claim precision.
- `--no-verify` overrides, counted from the *transcript* (not git — it leaves no commit-metadata trace).
- Lint catches vs false-fires.
- Commits where code and its living-reference update were *separate* (reconcile drift).

## Refutation-criteria movement (design-loop.md §Unresolved questions)

For each standing "refute the loop if…", state the direction this run pushed:

- *Reconcile routinely skipped under pressure* — did it land same-change, or slip?
- *Review-only reconcile doesn't drift* — any evidence either way?
- *Frozen/living split costs more than the drift it prevents* — bookkeeping burden observed?
- *Size gate collapses to "everything is high-stakes"* — did proportionality hold?

## Recommendations (split, evidence-weighted)

- **Loop changes** (→ `design-loop.md`): _…each tied to its scorecard evidence._
- **Harness changes** (→ skill / lint / check / checklist / template): _…each tied to its evidence._

Rank by evidence strength; flag small-N. One run is a signal, not a proof.
