# Fleet service placement — criticality, failure domains, and the re-role arbitration

**Status:** Proposed — design note (`docs/design/`). Not built. #387 — the arbitration its comments asked the design note to carry ("candidate shapes to weigh… none selected"); sibling of [fleet-service-isolation.md](./fleet-service-isolation.md) (the isolation axis); jointly they are the "central homelab ADR" #387 names. Adjacent #547, #552, #557, #566, #569, ADR-030, ADR-034. Drafted 2026-07-07. Expect an ADR on acceptance.

## Summary

*Where* a service runs — which host, in which failure domain — is the second axis of #387's service architecture, orthogonal to how sandboxed it is. The operator's own comments already arbitrated capacity (always-on metis / bursty tower / Pi sentinel); what they left open, deliberately, is the products class. This note develops that open question into **conditional decision rules with triggers rather than placements**, honouring the recorded "open input, not a decision" instruction. Three findings drive it. First, the comment record self-corrects when read in order: the 09:26 always-on/bursty split (bursts move to the tower) retired the noisy-neighbour scenario the 08:57 products-isolation case was built on, leaving **maintenance-cadence coupling** — the weekly bump's kernel updates versus an uptime-expecting co-tenant — as the real surviving residual, which is ADR-030's trigger-3 with a concrete mechanism. Second, on inspection **the "products tier" largely dissolves as a placement category**: Home Assistant is sui generis (hardware coupling + uptime expectation), and the remaining members decompose into per-service facts the isolation rule and the backup seam already answer — offered as a lean to test, not a conclusion. Third, the fleet **violates the watcher rule today**: every host's failure alerts terminate at metis's own ntfy, so metis-down means fleet-wide silence, including about metis — the placement rule this note formalises is needed now, not at some future scale.

## Motivation

#387's comments (2026-07-06) did substantial arbitration: three criticality classes (accelerators — degraded-not-broken; watchers/last-resorts — must live in a different failure domain than what they guard; products — uptime-expected, stateful, externally coupled), a role map (always-on metis, bursty tower, #547 Pi sentinel), a hardware direction (~64GB tower), and a parked, trigger-watched inference selection. None of that is relitigated here — it is this note's input. What was left open, explicitly ("**architecture deliberately unresolved** — the re-role design should treat it as an open input, not a decision"), is the products class's shape: co-tenant on headless metis, dedicated host(s), guests on a metis hypervisor (#555), or a hybrid — with three tensions named for early attention (update cadence, a second automation plane, products state).

Since those comments, fleet facts moved: the operator's 2026-07-07 target fleet (recorded in [fleet-ssh-identity.md](./fleet-ssh-identity.md) §target shape, ADR-042) retires mercury and nixos-vm and adds **two** new service-tier boxes — the M720q (name and role TBD) alongside the Pi — meaning "provision a new host for products" may already be a *role assignment* rather than a purchase. And the placement question is not hypothetical even today: metis already hosts fleet infrastructure (ntfy receiver, unit-failure fan-in), and the first stateful service (keeper, #386) is queued behind the re-role.

The objective, stated solution-free: **a service's host and failure domain should be derivable from declared rules when the service becomes real — decided by its properties and the fleet's topology, not by whichever box is handy on the day.** The failure mode this prevents is live now (De-risk): the alert path was placed by convenience and self-watches as a result.

Forces:

1. **P1 — Failure-domain honesty.** A watcher must not share a failure domain with what it watches; a last-resort must survive the disaster it exists for (#566, #569). This is the class the operator called "only worth having in a different failure domain."
2. **P2 — No host becomes a gate.** Fleet *functions* must not acquire a single-host dependency; pull-based convergence (#552) already guarantees deploys don't, and placement must not reintroduce one elsewhere.
3. **P3 — Uptime-expectation vs maintenance cadence.** The fleet's weekly `nixos-unstable` bump (ADR-030) regularly carries kernel updates; a host applying them needs reboots (uptime blips for every co-tenant) or runs stale kernels (drift the evergreen stance dislikes). A service with real uptime expectations makes that choice visible — ADR-030's own trigger-3.
4. **P4 — Physical coupling is not schedulable.** USB radios (HA's Zigbee/Z-Wave), disks, and displays pin a workload to a box in a way no software placement can move.
5. **P5 — Capacity is not the driver.** The operator's arbitration already established the always-on class is single-digit-GB light; on this fleet, placement decisions are about fate-sharing and cadence, not gigabytes. A rule that reaches for "more capacity" is answering the wrong question.
6. **P6 — Decide when real (accrete).** Placements land when their service does; this note produces rules and triggers, not a service map. The operator's "open input, not a decision" instruction is a constraint on this note, honoured by construction.
7. **P7 — Hardware plans are inputs, not commitments.** The tower and M720q have no arrival dates (RAM market); rules must degrade gracefully if the topology arrives late or different.

## Design

**The classes and the standing role map (operator's, restated as input).** Accelerators → metis (always-on; degraded-not-broken if down). Bursty/schedulable → tower (interactive, may sleep; zero always-on services). Watchers/last-resorts → the Pi sentinel (different failure domain; must not accrete other roles). Products → open, this note's subject.

**Correction 1 — the comment record, read in order.** The 08:57 case for a dedicated products host was isolation: "a nix build burst must never take down the heating automation." At 09:26 the always-on/bursty split moved every burst to the tower — the noisy neighbour left the building. What survives on always-on metis is steady, light co-tenants; the strongest surviving co-tenancy residual *this reading finds* is **P3's cadence coupling** (smaller residuals — administrative blast radius, disk contention — may survive too; Drawback 4 exists precisely so the operator can assert them): metis switches weekly, kernel updates accumulate, and either reboots blip every co-tenant (HA down, Zigbee re-initialising, while the heating decides) or the kernel goes stale. That residual is real but different in kind — it argues about *metis's maintenance posture*, not about neighbours, and its remedies are posture remedies (ring position, kernel-update discipline, or a stable channel for the services host — ADR-030 trigger-3, which the operator already flagged as fired in this direction) before they are buy-a-box remedies.

**Correction 2 — the products category, inspected member by member.** HA: hardware-coupled (P4), uptime-expected (P3), breaking-cadence upstream — three promoting properties, one of them physical; HA is *sui generis* and will force a real placement decision on its own facts. n8n: stateful, webhook/OAuth-coupled, no hardware, uptime that matters only as its automations become load-bearing — the isolation rule (container, image-pinned) plus the backup seam answer it; its genuinely novel tension is being a *second automation plane* (flagged below), not its placement. keeper: light, tailnet-only, personal-facing — an ordinary metis co-tenant under the isolation rule. **The lean this note offers for endorsement: dissolve "products" as a placement category.** The category, not its members, was generating the buy-a-host question; individually, every current member except HA places trivially under the rules below, and HA deserves a decision at its own arrival with its own facts. If products later arrive as a wave, the category reconstitutes — that is R6's trigger.

**The rules.** Conditional, trigger-carrying, in precedence order — a service takes the first rule whose property it has:

- **R1 — Watchers place across the domain boundary.** Anything that watches, alerts on, or is the last resort for X must not run on X — prefer the Pi; any independent domain qualifies. *Live application:* the alert path violates this today (De-risk); when the Pi lands, the ntfy receiver or a #569-style heartbeat receiver is its first tenant, and until then the violation is a recorded, accepted gap — not an unknown one.
- **R2 — Hardware-coupled services place with their hardware,** and the coupling is the placement decision: box-with-the-USB-stick, or a guest with passthrough if #555's seam has matured by then. Never the tower (interactive, sleeps), never the Pi (sentinel purity, operator-recorded).
- **R3 — Uptime-expecting services fire the posture question before the purchase question.** The first service on metis with a real uptime expectation triggers the ADR-030 trigger-3 evaluation for metis (ring position last, kernel-update discipline, or stable channel), and only if the answer is "the posture can't stretch" does it escalate to R4. Cheap remedy before hardware remedy.
- **R4 — New always-on roles are assignments before purchases.** The M720q exists in the target fleet with no role; a service that outgrows co-tenancy (via R3) or wants domain separation short of the Pi is a candidate *assignment* for it. What the M720q is for is the operator's open decision — this rule only establishes that assignment precedes purchase in the escalation order.
- **R5 — Everything else lands on metis** at whatever tier the isolation sibling gives it. The default is boring by design.
- **R6 — Reconstitution trigger.** If ≥3 uptime-expecting services accumulate (a products wave), the dissolved category reconstitutes and the dedicated-products-host question reopens with evidence in hand — the 08:57 comment's shapes get re-weighed then, not before.

**Sequencing couplings (time-sensitive, so named here rather than deferred).** The tower's first provisioning is the program's golden insertion point (operator, 09:26 comment lineage): TPM-sealed LUKS + secure boot (#557) and a persist whitelist (#553) enrol at first provision, skipping the re-provision cost those issues budget. metis's own window is the re-role disk rebuild — the migration note should bundle #557 + #553 into that single rebuild ("one scary day, not two"). The M720q and Pi likewise enrol #557-class posture at bring-up if their hardware supports it. These are placement-*timing* facts; the mechanisms stay with their issues.

**The automation-plane flag (named, not designed).** If n8n is adopted, the fleet gains a second scheduler beside systemd timers/CI/#565 charters; before its first load-bearing automation, a one-paragraph boundary (which plane owns what class of job) needs recording, or the fleet grows two uncoordinated cron planes. That is a future small decision, attached here so it is not lost.

How the design meets the forces: P1 (R1, with the live violation named), P2 (R1/R4 keep functions off single points; nothing here makes metis a gate), P3 (R3 makes the cadence question explicit and cheap-first), P4 (R2), P5 (no rule reaches for capacity; R4 is about domains, not gigabytes), P6 (rules and triggers only; zero placements decided), P7 (every rule degrades: no Pi → R1 records the gap; no M720q → R4 falls through to purchase-with-evidence; no tower → nothing here assumed it).

## De-risk evidence

Verified against `main` and the fleet, 2026-07-07:

- **The watcher-rule violation is live, not hypothetical:** `modules/nixos/unit-failure-notifier.nix` targets the ntfy instance on metis, and its importers are mercury, metis, and nixos-vm (`grep -rln`, this session) — metis reports its own failures to itself, and metis-down silences the fleet's alerting entirely. Darwin hosts have no failure notifier at all (#346), so the Macs are silent regardless. R1 is grounded in a demonstrated present-tense gap.
- **The comment chronology supporting Correction 1:** the products-isolation case (08:57:25Z) predates the always-on/bursty split (09:26:26Z) on #387's own thread — the later comment materially changed the earlier one's premise, and no recorded text reconciles them; this note is that reconciliation.
- **The two new service-tier boxes are operator-recorded, not invented:** the 2026-07-07 target fleet in [fleet-ssh-identity.md](./fleet-ssh-identity.md) (ADR-042) lists the M720q (name TBD) and the Pi as sinks in the service tier; nothing else about the M720q (specs, role, timing) is known, and this note deliberately assigns it nothing.
- **metis's current always-on inventory** (census, this session): ntfy receiver, unit-failure fan-in, tailscale, btrfs-scrub, plus the desktop/dev pile-up the re-role sheds — consistent with the "steady, light co-tenants" premise of Correction 1.

Unverified, stated rather than implied:

- **Kernel-update cadence on `nixos-unstable`** — "regularly carries kernel updates" is qualitative; the actual reboot pressure per month is unmeasured. R3's trigger does not depend on the exact rate, but the ADR should not quote a number until one is measured.
- **HA's actual requirements** (USB specifics, tolerable blip duration, container-vs-native fitness) — verified at its arrival, per R2/R3; everything said about HA here is from general knowledge and is marked as such.
- **The dissolution lean's durability** — it holds for the currently-named members (HA, n8n, keeper); a member with properties outside this analysis, or a wave (R6), revises it. That is what the trigger is for.

## Drawbacks

- **Rules-with-triggers rot if nothing watches them.** #562 (executable triggers) is unbuilt; until it exists, R3/R6's triggers live in prose and fire only if a human remembers. The mitigation is honest: the rules are few, and each is attached to an event (a service arriving) that forces the file open anyway — but a trigger missed at exactly such a moment is this design's failure mode.
- **The dissolution lean could be wrong cheaply or expensively.** Cheaply if products trickle in (R6 catches the wave); expensively if HA arrives *first and urgently* — the fleet would face its hardest placement (hardware + uptime + cadence) with the least accumulated evidence. The hedge is R3's posture-before-purchase ordering, which gives HA a workable interim (co-tenant with adjusted metis posture) while the real decision is made.
- **Deferring placements means the first mover still sets precedent under pressure** — the exact failure the live alert-path violation demonstrates. The rules reduce this (R5 gives a boring default; R1 names the exception class) but a rule set is only as good as the session that consults it.
- **This note leans on operator-recorded reasoning it then corrects.** Correction 1 re-reads the operator's 08:57 case in light of their own 09:26 split; if the operator's intent was that the isolation case *survives* the split (e.g. residual concerns beyond bursts), Correction 1 overreaches and the products-host case is stronger than presented. Flagged for exactly that check at review.

## Rationale & alternatives

- **A0 — no rules; place each service at arrival.** The status quo that produced the self-watching alert path. Fails P1 today and P6's spirit (each arrival becomes an unframed debate). Rejected on demonstrated evidence, not taste.
- **A1 — select the products shape now.** Directly violates the operator's "open input, not a decision" instruction, and would decide against pending facts (M720q role, tower timing, #555 maturity, HA's real requirements). Rejected as both unfaithful and premature.
- **A2 — hypervisor-cloud placement (everything a guest on metis).** Answers placement by making it moot — one box hosts all. Re-couples every fate to metis (P1, P2), depends on the unbuilt #555 seam, and was rejected on the isolation axis for the same reasons (sibling note, A3). Rejected.
- **A3 — conditional rules + triggers (chosen).** The operator's own recorded style (frontrunner-not-resolved, watch conditions, decision-rules-when-triggers-fire — the inference-appliance comments are the house pattern); honours P6 by construction; converts the products question from "pick a shape" into "know which rule fires when." Its cost is Drawback 1 (prose triggers until #562); accepted knowingly. Doing nothing keeps A0's demonstrated failure mode.

## Prior art

- **In-repo, primary:** #387's comments 3–6 are the arbitration this note integrates and corrects — the criticality classes, role map, and hardware direction are theirs; ADR-030 trigger-3 (uptime-critical workload → reconsider posture) is the operator's own pre-registered hook that R3 pulls; ADR-034's fired trigger (keeper's Postgres) shapes what "stateful co-tenant" means; the inference-appliance comments model the lean+trigger+decision-rule form this note adopts wholesale.
- **In-repo, negative:** the alert path (unit-failure-notifier → metis's own ntfy) is the worked example of placement-by-convenience; #569's dead-man framing ("the fleet's alerting detects failure but not absence") is the program-level statement of the same gap.
- **Industry:** "don't monitor from the monitored box" and "don't co-tenant the pager with the servers" are as old as operations; home-automation communities converge on the same split (HA near its radios, on hardware that reboots rarely) — corroborating R1/R2 from outside.

## Unresolved questions

- **The M720q's role** — operator's decision, open; R4 only establishes assignment-before-purchase. Its specs and timing are similarly unknown.
- **metis's posture answer when R3 first fires** (ring position vs kernel discipline vs stable channel) — decided then, with ADR-030 amended per its own trigger; this note only guarantees the question is asked before hardware is bought.
- **Whether the dissolution lean survives contact with HA's real facts** — R2/R3 structure that decision; they do not pre-make it.
- **Where the rules live once accepted** — prose in the ADR vs a small `lib/` datum the future #551 registry could assert against (each placed service declaring class + host + justifying rule); leans data-eventually, prose-first.
- Out of scope: the isolation tier of any service (sibling note); ingress/TLS and the backup mechanism (their own seams); #555's substrate; the re-role migration mechanics (downstream note — carrying the #557+#553 bundling named in Sequencing); naming executions (#368).

## Future possibilities

- **#562 watches R3/R6's triggers** once executable triggers exist — this note is a live specimen of the parked-with-triggers pattern it would machine-read.
- **The Pi's first tenant** is the alert-path fix (R1): a receiver off the watched domain, probably alongside #569's heartbeat layer — turning the recorded violation into the sentinel's founding purpose.
- **A placement stance, ADR-042-shaped,** once ≥2 services are placed: every hosted service declares its class, host, and the rule that put it there; drift (a watcher co-tenant with its target) fails eval. The set≠enforced closure for this axis.
- **The re-role migration note** inherits the Sequencing couplings: metis reborn (re-disko + #557 + #553) as one rebuild, the tower enrolling #557-class posture at first provision, and the desktop/dev duties relocating per #387's arc.
