# Record-coherence sweep — the corpus vs. the moved fleet (2026-07-07)

Status: **point-in-time review artifact, not a decision.** Captured 2026-07-07 by Claude (Fable 5), operator-requested. Method: three parallel read-only Sonnet sweeps over disjoint corpus slices — the 42 ADRs, the 12 design notes + 2 review artifacts, and the evergreen reference docs (CLAUDE.md, PRD, philosophy, taxonomy, workflow, identities, runbooks) — each seeded with the same 2026-07-07 "movement" lens and asked to flag two things with verbatim quotes: migration triggers whose condition the movement has met, and current-state assertions the movement has falsified. A Fable adjudication pass then cross-referenced the candidates against the movement and the day's open PRs, dropped the false positives (recorded below, so they are not re-flagged), and dispositioned each survivor. Companion to [engineering-review-2026-07-06.md](./engineering-review-2026-07-06.md) (code quality) and [step-change-review-2026-07-06.md](./step-change-review-2026-07-06.md) (ambition) — this one audits whether the record still tells the truth.

The prompting instinct: today's design loops kept discovering, *by accident*, that the corpus contradicted itself — a recovery doc pointing at a retiring key, a comment silently rewriting an earlier comment's premise, ADR-006's atuin trigger fired hosts ago and noticed only in passing. This sweep does that deliberately and once, so the "bank decisions for later execution" strategy rests on a record that is coherent rather than quietly rotted.

## Executive summary

**One root cause, many surfaces.** Almost every finding traces to a single fact: the fleet is mid-transition — mercury and nixos-vm retiring, saturn added, metis's desktop→homelab re-role pending (#387), three hosts (jupiter, M720q, Pi) incoming — and the *living* docs have not caught up. The **frozen** records (ADRs) are, correctly, frozen; the drift is concentrated in the documents that are supposed to describe the present.

**CLAUDE.md is the crown-jewel casualty.** The AI/contributor entry point — loaded into every session and explicitly declared to *override* default behaviour — still says "Four live hosts," names the two retiring hosts as current, **omits saturn entirely**, describes the pre-ADR-042 SSH posture, and lists break-glass for hosts that are going away. No PR in today's five touched it, despite ADR-042 (SSH model), the retirements, and the re-role all landing or being decided. That is the highest-severity vein in the corpus and the highest-value fix.

**The deepest finding is structural, not any single line:** CLAUDE.md's host census drifts because *nothing keeps it current*. It is exactly the class ADR-037 (doc-mutability-contracts) calls "facts that should be generated or checked," yet it is hand-maintained prose with no lint or generation binding it to `hosts/`. Fixing this instance without fixing the mechanism guarantees a re-drift by the next host event.

**Honest scorecard:** the corpus is in good shape where it is *supposed* to be frozen (the ADR decision bodies are accurate history) and where it was *written this week* (the five design notes landed today are internally coherent and movement-current — they cross-reference correctly and none contradicts another). The rot is real but narrow: it lives in the entry-point and reference docs, it is one root cause, and roughly a third of the raw flags were false positives that a careless remediation would have turned into new damage.

## Adjudication principles (what was dropped, and why — so it is not re-litigated)

Three classes of raw flag were rejected on inspection. Recording them is the point of an auditable filter:

1. **ADR decision bodies are frozen history — not staleness to fix.** The ADR sweep flagged ~13 ADRs (ADR-001/002/004/005/008/009/020/021/022/023/025/031/041) for naming `mac-mini`, "three-host fleet," or mercury-as-current. These are *correct records of what was true when the decision was made*. Editing them to match today's fleet would falsify the historical record — the opposite of the goal. The legitimate mechanisms for a superseded ADR are a `docs/decisions/README.md` index status note or an appended `§History` line (as ADR-010 already received for ADR-042), never a body rewrite. So these invert from "13 docs to fix" to "13 correctly-frozen records; the actionable residue is the index/§History supersession notes plus the eventual decommission sweep of *live config*." This is the sweep's most important adjudication: **do not 'fix' the ADRs.**
2. **`#552` fleet-convergence auto-merge ≠ GitHub PR squash auto-merge.** The evergreen sweep flagged CLAUDE.md's `gh pr merge --auto --squash` instruction as stale ("auto-merge deferred"). It conflated two unrelated things: the *fleet-convergence* auto-merge of #552 is deferred indefinitely; the *GitHub PR squash* auto-merge is the live PR-landing workflow (used on every PR today). The CLAUDE.md instruction is correct. Dropped.
3. **nixd is parametrised, not hardcoded.** ADR-005 was flagged for a `hostName = "nixos-vm"` nixd config. The live config (`home/shared/editor.nix`) derives `hostName` from `hostContext` per-host (`inherit (hostContext) flakePath hostName`); only the ADR *body* mentions nixos-vm, as history. No live-config staleness. Dropped.

## Findings by theme

### T1 — The fleet transition (dominant; ~20 surface manifestations)

The single movement — two hosts retiring, one added, one re-roling, three incoming — manifests across the living docs. Disposition splits three ways:

- **Fix-now (correct regardless of transition timing):** the items that are simply *wrong today*, independent of when hosts come or go. In CLAUDE.md: saturn's total omission (it is merged and in `hosts/`); "greetd, once landed" (greetd *has* landed — the conditional is false); the SSH stance describing the pre-ADR-042 posture with no ADR-042 reference; and a `(retiring)` flag on mercury and nixos-vm. These are the crown-jewel fixes and they do not wait on anything.
- **Fix-at-transition (a decommission / provisioning sweep):** the full re-census — dropping mercury and nixos-vm entirely, adding jupiter/M720q/Pi, re-describing metis's role — should land *when the hosts actually move*, not now. Rewriting CLAUDE.md/PRD/taxonomy to "three hosts" today would erase configs that still exist and invent hosts that do not, minting fresh staleness within the week. The right carrier is the decommission PR (removing mercury/nixos-vm from `hosts/`, `.sops.yaml` — the last already handled by #581 — nixd/docker imports, break-glass) and each provisioning PR. Docs affected: CLAUDE.md §host-list + §break-glass; PRD §1.2/§5.5/§11.6; taxonomy fleet table; `runbooks/headless-bootstrap.md` §Mercury.
- **Do-not-fix (frozen history):** the ~13 ADR bodies, per adjudication principle 1.

### T2 — metis loses the desktop to jupiter

A distinct sub-movement of the re-role: the desktop role migrates from metis to the incoming jupiter (#387). This invalidates, or soon will, several artifacts that assume metis-is-the-desktop:

- **`remote-desktop-access.md`** — its *entire subject* is remote control of "the metis niri desktop." Once the re-role lands, the target is jupiter. Disposition: a status note now (the note is Proposed/not-built), re-target at implementation. Gated on #387 (PR #580 in-flight).
- **`colour-conductor.md`** §"on-metis console verification" and **`lib/display-profiles.nix`**'s repo-global `active` knob (the engineering review already flagged the latter as "belongs on hostContext the moment a second desktop host lands" — jupiter is that moment). Disposition: fix-at-transition, urgency elevated.
- **CLAUDE.md** "Desktop environment lands on metis" — directionally stale; fix-at-transition.
- **ADR-028 trigger-3 / ADR-029 trigger-2** both frame the "mothership arrives" moment as *additive* (a new desktop host joins). The reality is a *role swap* (jupiter gains it, metis sheds it) — net-neutral desktop-host count, not additive. Disposition: #387's design should reconcile the two ADRs' additive framing with the swap reality (a §History note on each at re-role time); not a body rewrite now.

### T3 — Fired migration triggers

The triggers whose conditions the movement has met. Most already have a tracking home; the value is confirming that, and finding the one that does not:

- ADR-006 (atuin, "multi-machine → reconsider") — **fired**, tracked by #560. ✓
- ADR-010 (SSH-out workflows) — **fired**, superseded by #524/ADR-042; §History already updated. ✓
- ADR-018 (headless workload consuming rotating credentials) — **fired** by keeper (#386); custody covered by #526/#581. ✓
- ADR-030 trigger-3 (uptime-critical workload on a services host) — **firing** as headless metis approaches; explicitly carried by `fleet-service-placement.md` (#580, rule R3). ✓
- ADR-034 (irreplaceable local-only data — "notably a local-only database") — **fired** by keeper's Postgres + `ENCRYPTION_KEY`. **This is the gap:** the #387 comment record itself says "when this tier lands, the ADR-034 re-examination should become its own issue," and no such issue exists. #566/#553/#386 are adjacent (recovery, persist-whitelist, the service) but none re-opens the *no-backup stance*. **The sweep's one net-new actionable issue.**

### T4 — Point-in-time review drift (expected, fix by forward-link not rewrite)

The `step-change-review-2026-07-06.md`'s recommendations have been overtaken by the day's decisions: its Wave-0 / top-five leans on #558 (now resolved → ADR-042), #568 (now deferred), #552 auto-merge (deferred indefinitely), and #570 (now rejected). This is *expected* snapshot-drift — a dated review is a photograph, not a living plan. The correct treatment is a one-line forward banner at its head ("partially superseded by 2026-07-07 decisions: #558→ADR-042, #570 rejected, #568 deferred; see this sweep"), **not** a body rewrite — the same frozen-record principle as the ADRs. Its structural observations (#526 as the key-custody keystone; #551 as most-depended-upon) were *acted on*, not falsified — #526 is now designed (#581).

### T5 — Pre-existing internal incoherence (movement-independent)

One finding predates the transition: **`colour-conductor.md`**'s status header states (per ADR-041) that §Design items 1 and the per-tool halves of item 5 are obsolete and "should be reworked before implementation," but the body items themselves were never struck or updated — the header instructs a rework the body doesn't reflect. Disposition: strike/annotate the affected items in the body to match the header. Small, real, and the one finding not caused by the fleet moving.

## Disposition table

| # | Finding | Severity | Action | Home |
|---|---------|----------|--------|------|
| 1 | CLAUDE.md: "Four live hosts", saturn omitted, two retiring named as current | High | **fix-now** (saturn + retiring-flags) then fix-at-transition (full re-census) | CLAUDE.md |
| 2 | CLAUDE.md break-glass: retiring-host entries; "greetd, once landed" false; saturn absent | High | **fix-now** (greetd + saturn) then fix-at-transition | CLAUDE.md |
| 3 | CLAUDE.md SSH stance: pre-ADR-042 posture, no ADR-042 ref, "(neptune)" as sole darwin | High | **fix-now** (ADR-042 ref + saturn) | CLAUDE.md |
| 4 | CLAUDE.md census has no currency enforcement (structural) | High | **file-issue** (generation/lint of host census; ADR-037/#562 hook) | new issue |
| 5 | ADR-034 no-backup stance fired by keeper's Postgres, no re-examination issue | Medium | **file-issue** (the sweep's one net-new) | new issue |
| 6 | remote-desktop-access targets "the metis desktop"; metis loses it to jupiter | Medium | note-now, re-target at #387 | design note |
| 7 | PRD §1.2/§5.5/§11.2/§11.6: neptune "incoming", saturn "planned", Determinate-installer contradiction, false ADR-028 conditional | Medium | fix-at-transition; §11.2 (Determinate vs runbook) is a genuine cross-doc contradiction — fix-now-safe | PRD |
| 8 | colour-conductor status-header vs body (items 1/5 obsolete, not struck) | Medium | fix (movement-independent) | design note |
| 9 | ADR-028/029 "mothership additive" framing vs metis role-swap | Low-Med | reconcile at #387 (§History note) | ADRs / #387 |
| 10 | taxonomy fleet table + headless-bootstrap §Mercury: no retirement flags | Low | fix-at-transition (decommission sweep) | docs |
| 11 | wiki.md / claude-session-sync.md list nixos-vm as a sync peer | Low | note-only (both unbuilt; fix at implementation) | design notes |
| — | ~13 ADR bodies naming old fleet / mac-mini | — | **do-not-fix** (frozen history) | — |
| — | CLAUDE.md PR-auto-merge; ADR-005 nixd hostName | — | **dropped** (false positives) | — |

Already covered by open PRs (no new action): `.sops.yaml` recovery comment + darwin sops rationale (#581); the ntfy watcher-rule violation (named in #580); the atuin trigger (#560).

## The fix-now batch (correct regardless of transition timing)

Offered for operator approval as one small CLAUDE.md PR, separate from this diagnostic so the crown-jewel edit is reviewed on its own:

1. Host list → acknowledge **saturn**; flag **mercury** and **nixos-vm** as `(retiring)`; keep both until their configs are removed (the full re-census is the decommission PR's job).
2. "all four hosts" → "every live host."
3. Break-glass → drop the stale `once ADR-028 lands` conditional on metis (greetd has landed); add a saturn entry (Apple keyboard at local login); flag the mercury/nixos-vm entries `(retiring)`.
4. SSH stance → add the ADR-042 reference (the trust model is now the declared edge whitelist) and note saturn as a second darwin host so the `(neptune)` framing no longer implies a single darwin box.

The PRD §11.2 Determinate-vs-runbook contradiction is the other fix-now-safe item (the runbook is the operational correction; the PRD should point to it).

## Structural recommendation (the highest-leverage output)

The instance fixes above will re-rot at the next host event unless the census stops being hand-maintained prose. Two options, in ADR-032's escalation order:

- **Lightest:** a `grep`-lint that the set of host names in CLAUDE.md's census equals the set of directories under `hosts/` (minus a retiring-allowlist) — catches "saturn is missing" mechanically, the exact failure this sweep found.
- **Fuller:** generate the census block from `hosts/` + each host's `hostContext` (role, arch, status), the way keybinds.md is generated from the capability registry — the ADR-037 "facts as code" treatment applied to the entry-point doc.

Either belongs on #562's radar (executable triggers) or as its own small issue; the sweep recommends filing it (table row #4), because the entry-point doc drifting silently is the single most consequential coherence failure a session-loaded, behaviour-overriding document can have.

## Considered and rejected

Recorded so future sweeps do not re-flag: rewriting ADR decision bodies (falsifies history — principle 1); rewriting the point-in-time reviews (snapshot drift is expected — T4); "fixing" CLAUDE.md to the target fleet now (mints new staleness before the hosts move — T1); treating the PR-auto-merge instruction as stale (conflation — principle 2). A full audit of *code* comments for fleet references was out of scope (the engineering review covers code; this is the doc corpus) — but the same census-lint would catch the load-bearing ones.

## Closing

The corpus is coherent where it is frozen and where it is fresh; it has drifted where it is living and unenforced, from one root cause, with CLAUDE.md the acute case. The remediation is small and mostly deferred to the transition it describes — but the *mechanism* fix (census-as-checked-fact) is what keeps the next host event from reopening this exact report. The sweep's concrete outputs: one crown-jewel fix-now PR, two issues to file (the census lint; the ADR-034 re-examination), a forward banner on the step-change review, and a set of at-transition items whose natural carrier is the decommission and provisioning PRs already implied by the fleet's move.
