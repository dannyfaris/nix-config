# Conditional calendar sync — a CalDAV hub on electra with a rules-driven projection daemon

**Status:** Proposed — design note (`docs/design/`). Not built. #386 · research: [`../research/calendar-sync-prior-art.md`](../research/calendar-sync-prior-art.md) · ADR to follow on acceptance.

## Summary

Self-host the operator's calendar life on electra as a hub-and-spoke system: a Radicale CalDAV server holds the canonical calendars (and becomes the personal calendar's home, served to iOS over the tailnet), vdirsyncer moves events bidirectionally between the hub's staging collections and each provider (Google via its CalDAV v2 endpoint, Microsoft 365 via DavMail's Graph backend), and a small purpose-built projection daemon — Python, one-shot, its rules declared in Nix-generated TOML, its state in SQLite — applies the operator's conditional routing and privacy-shaping rules between staging and canonical collections. Everything is declarative, tailnet-internal by construction, and polling-based with no public surface. The daemon is built as a standalone project in its own repository and consumed here as a flake input.

## Motivation

The operator's events are scattered across providers — Google Calendar, Microsoft 365 (work), Apple/personal — and none sees the others; double-bookings and hand-mirroring are the daily symptom. Existing sync tools are all-or-nothing: they mirror everything or busy/free-strip everything. The requirement is *conditional* propagation — operator-defined rules decide which events cross which boundary and **in what form** (M365 may see only a busy block, or full details, depending on conditions), bidirectionally, surviving the hard cases (recurring series with `RRULE`/`RECURRENCE-ID` exceptions, edits originating on any side), and surfacing as a first-class read-write calendar on iOS. Writing both busy blocks *and* full-detail events into M365 is essential to the project, not optional.

Forces any solution must satisfy:

- **Conditional routing and shaping** — per-event rules (content, calendar, attributes) choosing destination *and* projection form; no existing tool's preset modes suffice.
- **Bidirectional with recurrence fidelity** — `RRULE` propagation and exception handling without duplicates or corruption; edits flow from any surface, including full-detail writes into M365.
- **First-class iOS client** — the hub is a normal read-write CalDAV account on the phone, not a dashboard.
- **Self-hosted, declaratively owned** — data, secrets, and rules on operator hardware (electra), composed by this repo like any other service; rules live in git (explicit > implicit).
- **Minimal exposure** — tailnet-internal wherever the design allows; public surface only where genuinely required (ruling: nowhere — see Design §Exposure).
- **Personal-critical state handled as such** — the hub becomes the calendar's home; backup and electra-down behaviour are first-class, not afterthoughts.

## Design

**Topology (fork 2 — hub-and-spoke, hub is source of truth).** Radicale on electra holds two tiers of collections: *canonical* (the operator's real calendars; iOS points here) and *staging* (one per provider spoke, holding that provider's view verbatim). All provider sync happens hub↔provider through staging; the projection daemon is the only writer that crosses the staging/canonical boundary. Sync complexity is linear in providers; adding a spoke later is one new vdirsyncer pair plus rules. The personal calendar's home moves from iCloud to the hub — viable because of the tailnet and operator ownership of the hub.

**Exposure (fork 1 — polling-first, nothing public).** Change detection from providers is polling on systemd timers using incremental sync (cheap, quota-friendly). The three things that appeared to force internet exposure all dissolve: OAuth redirects are browser-mediated (the provider never calls the callback; Tailscale Serve HTTPS on `electra.<tailnet>.ts.net` satisfies the HTTPS-redirect-URI requirement), iOS reaches the hub over the tailnet, and provider push webhooks — the only genuine public-surface driver — are declined in favour of polling. The sanctioned upgrade path if poll latency ever grates: a webhook receiver exposed via Tailscale Funnel, recorded here and expected never to be needed.

**Transport (fork 3 — CalDAV-everywhere, battle-tested movers).** Every spoke speaks CalDAV/iCalendar, so events stay in iCalendar end-to-end and no provider-model translation is hand-written: Google via its CalDAV v2 endpoint (OAuth, self-registered client), M365 via DavMail's Graph backend running as a local gateway on electra (EWS is blocked by Microsoft from 2026-10-01; the Graph backend is the only forward path), iCloud natively when its spoke lands (phase 2 — fork 5). vdirsyncer runs each provider↔staging pair with its own per-pair state and conflict handling; it is in author-declared wind-down, so the design carries a named successor watch — migrate to pimsync when it ships Google CalDAV + OAuth at ≥ v1.0 (De-risk §transport-pick probe). Unattended M365 auth uses DavMail's TOTP support with the secret in sops.

**The projection daemon (fork 6).** A small standalone Python project (fork 7 — own repository, own CI, consumed here as a flake input) that projects events between staging and canonical collections under the operator's rules:

- **One-shot execution** — chained systemd units (vdirsyncer sync → project → write-back) plus a path unit on canonical collection directories catching hub-originated edits; every run starts from disk, does its projection, exits. Crash-only, journal-observable, testable by running it.
- **Rules as data, engine as code** — conditions (hashtag, calendar, attributes) → actions (route, busy-only shape, full-detail, drop) declared in a TOML file generated from the NixOS module's options; the operator's rules live in this repo and diff in PRs. The daemon is a generic engine that knows no specific rule.
- **Typed shell, verbatim core** — Pydantic validates the edges (rules file, mapping records, transfer objects); event bodies stay in `icalendar`'s component model end-to-end so properties the daemon doesn't understand survive round-trips untouched. Events are normalised before comparison (guarding against false-change echoes from cosmetic reserialisation).
- **State in SQLite** — one file beside the collections: source↔destination UID mappings with content hashes and per-side etags/sequence numbers for echo suppression (recognising our own writes coming back), plus provenance markers on every event the system creates (UID suffix, or category where custom UIDs are disallowed — the verified keeper.sh pattern) driving push/delete/stale-cleanup decisions.
- **Write safety** — a dry-run mode logging intended writes precedes first contact with any real calendar; malformed inbound data (a documented M365→Radicale hazard) is quarantined in staging rather than propagated.
- **Test posture (operator requirements)** — property-based coverage via Hypothesis over generated VEVENTs/RRULEs asserting the load-bearing invariants (projection idempotence, unknown-property preservation, loop-safety), and mutation testing applied to the whole suite (lean: `mutmut`; final pick is a light selection inside the build phase). Both run in the daemon repo's CI, not this repo's.

**M365 leg ladder (fork 4 — full read-write, condition-dependent shaping).** Because full-detail writes into M365 are essential and land exactly where the evidence is weakest (DavMail's Graph backend is maintainer-labelled beta with recurrence fixes landing as recently as 2026-06), the leg carries an ordered fallback ladder: DavMail-Graph (gated on a live write-path probe — De-risk §still-unverified) → a narrow native Graph adapter scoped to exactly the operations needed → DavMail under Microsoft's blessed well-known client IDs → an Apple-Calendar bridge on neptune as documented last resort (rejected as primary: same EWS cliff on Apple's opaque timeline, GUI-automation manipulation surface, splits the always-on path across two hosts). The tenant blocks third-party apps by default; CIO approval for DavMail's app registration is a named external dependency to start early.

**Secrets and state.** All secrets via sops-nix (Google OAuth client secret + token cache, DavMail/M365 TOTP secret, Radicale htpasswd). All mutable state — Radicale collections, vdirsyncer status, SQLite mappings, DavMail token cache — lives under one btrfs-snapshotted directory on electra with an off-host copy, so the personal-critical data has one backup story.

**Phasing (fork 5).** Phase 1: hub + Google + M365 spokes + iOS client. iCloud is dropped from phase 1 and revisited as a read-write spoke once the operator has lived without it; the architecture keeps that seam open by construction.

How the forces are met: conditional routing and shaping live in the daemon's rules (declared in git); recurrence fidelity is preserved by keeping events in iCalendar end-to-end and testing the invariants property-based; iOS gets a native CalDAV account on the hub; everything is composed declaratively by this repo with no public surface; the hub's state is snapshotted and copied off-host.

## De-risk evidence

Verified — deep-research run `wf_df6a51e7-6bc`, 2026-08-03, 25 claims adversarially verified (23 confirmed / 2 refuted); full detail in [`../research/calendar-sync-prior-art.md`](../research/calendar-sync-prior-art.md):

- **The shape has prior art; the seam is open.** A practitioner ran Radicale-hub + vdirsyncer for a family calendar for years without reported loops or RRULE corruption (UNVERIFIED-tier extract); keeper.sh proves hub-and-spoke aggregation (3-0) and supplies a verified loop-prevention pattern (UID provenance markers, 3-0); ical-filter-proxy proves the filter layer but is one-way ICS with no CalDAV write path (3-0 ×3). Nobody has published the bidirectional conditional-projection seam the daemon occupies.
- **The Google leg holds.** CalDAV v2 documented live (page updated 2026-05-01), OAuth-only, self-registered client required (3-0 ×3); vdirsyncer's OAuth breakage fixed since 0.19.0 (3-0 ×3). Caveat: Google makes no formal support commitment for CalDAV; continuity rests on documentation freshness.
- **The M365 leg's risk is characterised.** EWS blocked from 2026-10-01 (3-0 ×3); DavMail actively maintained with the Graph backend GUI-exposed since 6.8.0 but maintainer-labelled beta, recurrence/exception handling still being repaired 2026-06 (3-0 ×5, 3-0); MFA number-matching killed unattended push auth, TOTP restores an unattended path (3-0 ×2); vdirsyncer's own docs warn the DavMail pairing can reach data-loss (3-0). This evidence is why the leg is probe-gated and carries a fallback ladder.
- **Refuted en route:** "keeper.sh lacks conditional/privacy shaping" (0-3 — capability unresolved either way, see below), and "Google's release notes corroborate CalDAV continuity" (0-3).

Verified — Radicale fidelity probe (executed on alnair 2026-08-03; script adversarially peer-reviewed before execution per workflow §"Peer review binds to what executes"; Radicale 3.7.7 from the pinned nixpkgs `148bab9c1c3c…`, throwaway loopback instance, reserialisation demonstrated on every fixture — non-vacuous):

- **Recurrence structure: verbatim PASS.** RRULE (WEEKLY/BYDAY/UNTIL), EXDATE, both RECURRENCE-ID overrides (rescheduled + STATUS:CANCELLED) round-tripped property-for-property with zero diffs — the single most load-bearing fidelity claim holds.
- **Event-level X- properties (incl. a provenance marker, X-PARAMs, long values) and unknown/RFC-7986 properties with folded multi-byte UTF-8: preserved.** Calendar-level X-props also survived (informational fixture).
- **Caveat — Radicale is semantically lossless but not byte-verbatim.** Two normalisations observed: a raw `;` inside a TEXT value is re-serialised escaped (`x;y` → `x\;y`), and RFC-optional DQUOTEs around a param value are stripped (`LABEL="Team Call"` → `LABEL=Team Call`). Both are RFC-equivalent. **Design consequence:** the daemon's change-detection and mapping content-hashes must compare *parsed/normalised* iCalendar, never raw bytes — already the design's stated posture, now evidence-required rather than precautionary.
- **Malformed-input behaviour (informational): accepted and mutated.** A deliberately non-conformant Microsoft-style invite was accepted with a synthesized DTSTAMP and its SUMMARY *truncated at an unescaped comma* — real data mutation on malformed input, directly reinforcing the staging-quarantine requirement for the M365 leg.

Verified — keeper.sh capability probe (Opus subagent, source-level inspection of the 2026-07-20 HEAD, 2026-08-03):

- **The rejection stands on the load-bearing requirements, with corrected wording.** keeper's engine is deliberately "event content agnostic" (README); routing is a static source→destination mapping edge carrying no per-edge config; shaping (title-masking template, description/location stripping, busy-style projection) exists but binds to the *source calendar* — one source feeding two destinations projects identically to both. So keeper *does* offer per-source busy-only masking, attribute-type exclusion filters (all-day/focus-time/OOO), full-detail writes, and solid RRULE materialisation with exceptions — the research's refutation of our blanket "no shaping" claim was correct — but it has **no per-event content conditions** (hashtag routing: zero hits in the codebase) and **no per-destination-boundary full-vs-busy choice**, which are this design's two defining requirements. Its sync is also source-wins one-way re-mirroring, not bidirectional. Rejection confirmed on the precise grounds; fork 3 closed.

Verified — transport-pick probe (Opus subagent, primary sources, 2026-08-03):

- **vdirsyncer stands, as "current pick with a named successor watch."** vdirsyncer is v0.20.0 (2025-08-28) in nixpkgs and in author-declared wind-down (deprecation post 2026-04-09: support "will wind down substantially"; commits near-zero since late 2025). Its successor pimsync (same author, Rust, NLnet-funded, nixpkgs 0.5.11) is pre-1.0 and **lacks Google CalDAV/OAuth entirely** (migration man page) — preferring it now would break the Google spoke outright. **Named migration trigger:** pimsync ships Google CalDAV + OAuth (plus CalDAV date/item-type scoping) at ≥ v1.0.
- **The "no transform hooks" premise was inaccurate as stated, but the conclusion holds.** vdirsyncer *does* have per-item hooks (`post_hook`/`pre_deletion_hook` on filesystem storage, `filter_hook` on read-only HTTP storage) — but they are path-only, collection-blind, stateless, fire on our own write-backs (loop hazard), and the transform-capable variant is one-way-only. None can do conditional bidirectional routing + shaping with echo-suppression across the staging/canonical seam, which is precisely the daemon's job. pimsync currently *removes* `post_hook`, reinforcing the daemon regardless of transport.

Still unverified — the stage-4 probe plan, gating build:

1. **DavMail Graph write-path probe (decisive for the M365 ladder's first rung):** create/update/delete events including recurring series with exceptions, through DavMail-Graph into a scratch M365 calendar, verified round-trip. Blocked on the CIO-approval dependency. Probe pack prepared (2026-08-03, source-verified against DavMail and the repo pin): the pinned nixpkgs carries DavMail 6.8.1 (the first line with mode-split Graph support); minimal delegated scope set derived as `Calendars.ReadWrite offline_access openid profile` — dropping DavMail's default `Mail.ReadWrite`, with clean calendar-only startup UNVERIFIED until first run; two tenant routes identified (A: DavMail's own multi-tenant public client id `facd6cff-a294-4415-b59f-c5b01937d7bd` under user/admin consent, no app object created; B: a single-tenant native registration with `davmail.oauth.clientId`/`tenantId` set); unattended auth is `O365DeviceCode` + a TOTP factor via `davmail.oauth.totpSecret` (number-matching push cannot be automated). Which route the tenant permits, user-vs-admin consent policy, TOTP factor availability, and tenant GUID are operator/tenant questions on the prepared checklist.
2. **iOS-over-Tailscale probe:** iOS Calendar account setup and reliable read-write sync against Radicale via Tailscale Serve HTTPS (only macOS-adjacent evidence exists; discovery quirks are documented and solvable, but iOS itself is unproven here). Runbook drafted and awaiting adversarial review + operator prerequisites; known likely blocker: HTTPS certificates have never been enabled on the tailnet (`CertDomains: null`).

## Drawbacks

- **The calendar's availability now depends on electra.** iOS caches offline, but a down hub means a stale calendar and paused sync; the previous state (provider SaaS) had no such single point.
- **The M365 leg may simply not be approvable or workable.** CIO approval could be refused, and every rung of the ladder below DavMail costs more engineering (native adapter) or more fragility (bridges). If M365 write access fails entirely, the project's essential requirement is unmet — this is the direction's real kill-risk.
- **A custom sync engine is the classic DIY graveyard,** even scoped down to projection-only. The property/mutation-test posture and the CalDAV-everywhere scope reduction are mitigations, not immunity.
- **Operational breadth:** Radicale + DavMail (Java) + vdirsyncer timers + daemon + SQLite is five moving parts where a SaaS is zero; each is individually boring, but the composition is owned here forever.

## Cost

- **Two-repo development friction:** early on, the rules schema and the NixOS module co-evolve, so some changes are two-PR affairs with a flake-input bump between them; front-loaded, fades as the option surface stabilises.
- **A standing external dependency on workplace policy:** the M365 spoke lives at the pleasure of tenant administration; a policy change can break it at any time, and renewing approval is an operator task no automation removes.

## Rationale & alternatives

Each fork was ruled in operator dialogue (2026-08-03, this session), weighed against the stated forces:

- **Exposure — polling over push webhooks (fork 1):** webhooks add a public endpoint plus a subscription-renewal state machine and still require the same incremental fetch after each ping; polling latency (~poll interval) is invisible for a personal calendar. Zero public surface wins.
- **Topology — hub-and-spoke over pairwise mesh or projection-only hub (fork 2):** mesh makes rules and loop-prevention combinatorial per provider pair and leaves iCloud CalDAV as the phone's write target (documented custom-property fragility); projection-only fails the read-write iOS requirement outright. The hub makes rules, metadata, and additions linear; its cost (personal-critical state) is designed for rather than avoided.
- **Engine — CalDAV-everywhere + small daemon over n8n or fully bespoke (fork 3):** n8n's REST nodes reintroduce provider-model recurrence translation inside GUI-edited workflow state — the least testable home for the hardest problem, and squarely against this repo's declarative philosophy (#387's second-automation-plane concern made concrete); fully bespoke means owning provider API clients and sync correctness forever. Option C shrinks custom code to exactly the seam no tool fills, keeps it on local files where it is trivially testable, and hands transport to decade-proven movers. keeper.sh is rejected on source-verified grounds: its filtering/privacy is per-source-calendar and event-content-agnostic — attribute filters and per-source busy-masking exist, but no per-event content conditions (hashtag routing) and no per-destination-boundary full-vs-busy choice, the two defining requirements here — and its sync is source-wins one-way re-mirroring, not bidirectional (De-risk §keeper probe).
- **M365 posture — full read-write via a probe-gated ladder (fork 4):** read-mostly (the research's lean) was overridden by requirement — busy blocks *and* full-detail writes into M365 are essential. The ladder converts the weakest-evidence component from a bet into a gated sequence with named fallbacks.
- **iCloud — deferred, not dropped (fork 5):** phase 1 sheds one bidirectional loop-proofing surface; the operator trials life without it; the seam stays open.
- **Daemon shape (fork 6):** Python over Rust/Go because the risk concentrates in iCalendar parsing fidelity and Python's `icalendar` ecosystem is the most battle-tested available — library maturity beat language preference on the stated forces. One-shot over resident daemon (crash-only, observable; latency already conceded to polling). Rules-as-data over rules-in-code (the most-touched surface belongs in reviewable config). SQLite over the research's assumed Postgres (one writer, thousands of rows; Postgres would be electra's first service needing its own dump cadence, for no gain).
- **Residency — standalone repo over in-tree (fork 7):** the daemon is an application, not configuration; its slow CI (property + mutation testing) must not tax this repo's `nix flake check`; the seam is novel enough to be independently useful. Boundary: the daemon repo owns code, tests, schema definition, usage docs; this repo owns the design note, ADR, module, and the operator's declared rules.
- **Doing nothing** leaves the daily double-booking/hand-mirroring cost in place and was already rejected by intent (#386).

## Prior art

Surveyed in [`../research/calendar-sync-prior-art.md`](../research/calendar-sync-prior-art.md) (capture 2026-08-03): the terramoto.xyz Radicale+vdirsyncer family hub (closest practitioner build), keeper.sh (packaged hub-and-spoke, different hub, verified loop-mitigation pattern, capability question open), ical-filter-proxy (rule-schema prior art for the daemon, one-way only), and the documented failure modes (duplicate storms on the DavMail pairing, false conflicts from raw-text comparison, `STATUS:CANCELLED`-vs-`EXDATE` client divergence, Radicale's rejection of malformed Microsoft-originated data) that the daemon's normalisation, quarantine, and provenance mechanisms answer. This repo's own antecedents: ntfy on the tailnet-boundary-as-auth posture, and #387's products-tier criticality analysis, which this service instantiates on electra.

## Unresolved questions

- **Resolve before build (stage 4):** the five probes in De-risk §still-unverified — DavMail write-path (decisive), Radicale fidelity, iOS-over-Tailscale, keeper capability check, vdirsyncer-vs-pimsync.
- **External dependency:** CIO approval for DavMail's tenant app registration — start immediately; the write-path probe is blocked on it.
- **Resolve during build:** mutation-testing tool pick (`mutmut` lean); rules-TOML schema details; poll cadences; the daemon project's name and licence (operator's call at repo creation); exact collection layout (canonical/staging naming).
- **Out of scope:** multi-user sharing on the hub (Radicale's granularity limits noted in research §5 — single-operator use unaffected); any exposure beyond the tailnet.

## Future possibilities

- **iCloud read-write spoke** (phase 2, fork 5's recorded revisit).
- **Webhook receiver via Tailscale Funnel** if poll latency ever grates (fork 1's recorded upgrade path, expected never).
- **Further spokes** (any CalDAV-speaking provider is one vdirsyncer pair + rules away).
- **Publishing the daemon** — the seam is unoccupied in the wild; a documented standalone release may be useful beyond this fleet.
- **MCP/agent access to the hub calendar** — deliberately not designed here; would be its own intent-first issue.
