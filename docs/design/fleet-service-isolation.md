# Fleet service isolation — native by default, promoted by property

**Status:** Proposed — design note (`docs/design/`). Not built. #387 — settles the issue body's native-vs-container question and its exception rule, which is one half of the "central homelab ADR" #387 names; the other half (placement) is [fleet-service-placement.md](./fleet-service-placement.md). Upstream of #386, #555; adjacent ADR-034, ADR-030. Drafted 2026-07-07; trimmed same day after adversarial self-review (ladder-as-fleet-policy → a rule plus named seams). Expect an ADR on acceptance, jointly with the placement sibling.

## Summary

When the fleet hosts an application service, the isolation it gets is currently an accident of packaging: ntfy is a native NixOS service because a module exists; keeper (#386) will be a container because it has none. This note replaces the accident with a rule — and deliberately nothing bigger: **default to a native NixOS service; promote along the isolation spectrum (native → OCI container → microVM guest → dedicated host) only to the lowest position a named property demands** (no clean packaging, an upstream cadence that fights the weekly bump, untrusted code, neighbour blast-radius). Only the first two positions are *adopted tiers* — native (proven by ntfy) and container (keeper forces it; verified buildable in the pin). Guest and dedicated-host are **named seams**: vocabulary for promotion targets, deliberately unbuilt (guest gated on #555; dedicated-host reached only through the placement axis). The rule lands as a host-agnostic `services` capability any host composes; metis applies it first, but the rule is the fleet's, not metis's. Isolation depth is one axis; *where* a service runs — its host and failure domain — is the separate axis carried by the sibling note [fleet-service-placement.md](./fleet-service-placement.md).

## Motivation

#387 re-roles metis to a headless services host and explicitly spins the service-architecture question out as "the central homelab ADR." That question is not metis-specific: the fleet already runs services (ntfy, the unit-failure-notifier) today, the tower will burst-host builds, the RPi will host watchers, and a products tier (Home Assistant, n8n) is coming — every one of them faces the same question of *how isolated a hosted service is from its host, its neighbours, and the fleet's version cadence*. Today there is no answer, only a reflex: reach for a native module if nixpkgs has one, a container if it doesn't. That reflex ties a service's isolation to its packaging luck rather than to its risk.

The objective, stated solution-free: a service's isolation should be **chosen for its properties, not fallen into** — deliberately, cheaply, and derivably, so that the tier a future service lands at is a consequence of facts about the service, not a fresh debate each time.

Grounding sharpens three facts (census, this session):

- **The native tier is proven and cheap.** `modules/nixos/ntfy-server.nix` is a handful of code lines: one upstream `services.ntfy-sh` module, tailnet firewall trust as the auth boundary, no tokens, no proxy. That is the default tier done right, and the bar a promotion must clear to justify itself.
- **There is no container-as-*service* substrate today.** `modules/nixos/docker.nix` is rootless *dev* docker, explicitly for the operator's build workflow, not service hosting. The idiomatic NixOS substrate — `virtualisation.oci-containers` (podman) — exists in the pin but is unused. The container tier is genuinely new capability, and keeper is the service that forces it.
- **The guest tier is vapour.** No `microvm.nix`/arion input exists; #555 has scoped the substrate but selected no mechanism and committed no design. The model can name the guest tier and its promotion property, but must not pre-commit a substrate — that is #555's selecting-tooling to run.

Forces any model must satisfy:

1. **F1 — Composable, declarative (ADR-027).** Lands as a capability a host imports; no role layer, no auto-discovery, no imperative service management.
2. **F2 — Accrete, not big-bang (ADR-032).** Service #1 must land without building the whole platform; tiers are built only as services 2..N justify them. No hypervisor for a calendar sync.
3. **F3 — Blast-radius proportional to risk.** A service's failure or compromise must not take the host or its neighbours down beyond what its risk warrants (the operator's never-share-fate rule: a build burst must not kill the heating automation).
4. **F4 — Version-cadence independence.** The fleet tracks `nixos-unstable` weekly (ADR-030). A service with a breaking-release upstream (HA) or no clean packaging (keeper, a Bun app) must be able to pin its own version independent of the bump, or the bump breaks it weekly.
5. **F5 — State honesty (ADR-034).** A stateful service (keeper's Postgres + `ENCRYPTION_KEY`) is the first fleet data not covered by reprovision-from-source — ADR-034's migration trigger, fired. The tier model must surface this seam, not obscure it.
6. **F6 — No host becomes a gate.** Pull-based convergence (#552) means no host depends on another to deploy; the model must never place a fleet *function* where a host being down blocks the fleet.
7. **F7 — Single-operator effort ceiling.** Each tier is standing operational surface. The model must not mandate isolation heavier than a service's risk warrants — the proportionality that killed #570's heavy layers and deferred #568.
8. **F8 — Don't pre-empt open selections.** The guest substrate (#555), TLS/ingress, and backup are their own undecided decisions; the model names their seams without deciding their mechanism.

## Design

**The spectrum.** Four positions of increasing isolation, version-independence, and blast-radius containment — and decreasing declarative integration and simplicity. Only positions 1–2 are adopted tiers; 3–4 are named seams:

1. **Native NixOS service** — an upstream `services.*` module, tailnet-firewall-scoped (the ntfy pattern). Maximally declarative and reviewable; shares the host's kernel, user space, and nixpkgs cadence.
2. **OCI container** — `virtualisation.oci-containers` (podman backend; verified in the pin), image pinned by digest. Process/filesystem isolation, and — the load-bearing property — the *workload image is pinned independent of nixpkgs*, so the weekly bump moves the runtime but not the service version.
3. **microVM guest** — a full kernel/root boundary (the #555 substrate, unselected). Strong blast-radius containment and migration-as-guest-move; the tier for services that run untrusted code or must never share fate with the host.
4. **Dedicated host** — a separate machine: maximal isolation, but reached for *placement* reasons (hardware coupling like HA's Zigbee/Z-Wave USB, independent uptime, failure-domain separation), not because a service needs more sandboxing than a guest gives. This is where the isolation axis saturates and hands off to the placement axis (below); it is the spectrum's ceiling, but the reasons that reach it live on the other axis, which this note does not adjudicate.

**The rule.** Default to tier 1. Promote to a higher tier only when the service has a **named property that a lower tier cannot satisfy**, and settle at the *lowest* tier that satisfies it:

| Promoting property | Promotes to (at least) | Because |
|---|---|---|
| No clean native packaging | container | a Bun/TS app (keeper) has no module; forcing a native repackage fights nixpkgs |
| Upstream breaking-release cadence vs the weekly bump | container | image-pinning decouples the service version from `nixos-unstable` (F4) |
| Runs untrusted / arbitrary code | guest | a kernel boundary contains it (sandboxes, #565 charters) |
| Must contain blast-radius from/to *neighbours* on the same host | guest | a neighbour's crash or compromise must not reach it (F3) |

(Sharing fate with the *host* — if the box dies, the service dies — is not on this spectrum: no amount of on-host isolation fixes it. That is the placement axis below.)

The rule's shape is the point: it is **property-driven and lowest-sufficient**, so a service's isolation tier is *derivable* from facts about it rather than argued each time, and proportionality (F2/F7) is built in — you never reach past the position a property demands. This collapses the "native vs container vs guest" question into one rule. It does **not** settle *where* a service runs.

**The second axis (deferred).** Isolation depth answers *how sandboxed* a service is on whatever host runs it; it does not answer *which host, in which failure domain*. That is the placement question the operator framed as criticality classes: accelerators (degraded-not-broken if their host is down), watchers/last-resorts (which must live in a *different* failure domain than what they guard — the #547 RPi, not the box it watches), and products (uptime-expected, sometimes hardware-coupled). That axis is driven by failure-domain and physical coupling, not sandboxing, and it is carried by the sibling note [fleet-service-placement.md](./fleet-service-placement.md), which develops the operator's open criticality-class arbitration into conditional decision rules. The two axes compose — a service has both a tier *and* a placement, chosen on different grounds.

**Where it lands (F1).** A host-agnostic `services` capability (bundle) providing each tier's seam: the native-service convention (exists), the OCI-container substrate (built when keeper lands), the guest hook (a named interface to #555, unbuilt), and the degenerate dedicated-host case (a host that composes `services` and hosts one thing). A host composes `services` to host workloads; metis composes it first, the tower opportunistically, a products host or the RPi as they arrive. The bundle **accretes tier machinery as services justify it** (F2): keeper forces the container tier to be built; nothing builds the guest tier until a service with a guest-promoting property and #555's substrate both exist.

**State and gating.** "Stateful" is itself a promoting property in a second dimension: a service holding data not covered by reprovision-from-source (F5, ADR-034) cannot land until a state-recovery seam answers for it — so a stateful service's landing *mandates the backup seam* (whose mechanism is a sibling note, not this one). And no service placed under this model may sit on the fleet's critical path (F6): the rule hosts *workloads*, never fleet *functions* — pull-based convergence already guarantees no host waits on another to deploy. But F6 is discharged on the *placement* axis, not this one: a guest existing does not make it safe — a guest on metis makes metis load-bearing for that workload, so a watcher or last-resort promoted to the guest tier must still be *placed* off the box it guards. The tier answers isolation; F6 and failure-domain are the placement axis's to satisfy.

How the design meets the forces: F1 (a composed bundle, no role layer); F2 (tiers built only as justified; native default); F3 (guest/host tiers exist precisely for blast-radius promotion); F4 (container/guest tiers pin their own version); F5 (statefulness mandates the backup seam and surfaces it); F6 (workloads-not-functions on the isolation axis; failure-domain placement, where F6 is actually discharged, deferred to the second axis); F7 (lowest-sufficient-tier — never over-isolate); F8 (guest substrate and TLS/backup named as seams, mechanisms deferred).

## De-risk evidence

Verified against `main` and the pin, 2026-07-07:

- **The native tier is real and is the cheap default** — `modules/nixos/ntfy-server.nix` (a native `services.ntfy-sh` module + tailnet trust, no tokens or proxy); the pattern the rule defaults to.
- **The container tier is buildable now, in-idiom** — `nix eval …metis.config.virtualisation.oci-containers.backend` returns `"podman"`; the option accepts `"podman" | "docker"`. So the tier keeper forces is a standard NixOS capability, not a bespoke build. The existing rootless *dev* docker (`modules/nixos/docker.nix`) is separate and unaffected.
- **The container tier's cadence-decoupling claim holds precisely** — `oci-containers` pins the *workload image* (by tag/digest), independent of nixpkgs; the podman runtime itself tracks the weekly bump, the service version does not. This is the exact mechanism F4 needs, and it is worth stating at that precision so it is not over-claimed.
- **The guest tier is genuinely unbuilt** — no `microvm`/`arion`/`cloud-hypervisor` node in `flake.lock`; #555 has selected no substrate and committed no design (census). The model therefore names the guest tier as a *seam gated on #555*, and must not pre-empt its selecting-tooling.
- **ADR-034's trigger is fired, not hypothetical** — its migration trigger names "a local-only database" explicitly; keeper's Postgres + `ENCRYPTION_KEY` is exactly that. The state seam is a present requirement, not a future one.

Unverified, stated rather than implied:

- **The promotion rule's crispness under real cases** — the properties are legible for keeper (no packaging), HA (cadence + hardware), and sandboxes (untrusted code), but a service that is ambiguous (a native module exists *but lags upstream badly*) will still need a judgment call; whether the rule stays crisp across the real service set is unproven until services 2..N actually arrive.
- **podman vs docker as the `oci-containers` backend** — a small selecting-tooling at build time (podman's rootless-daemonless model is the likely fit); not decided here.
- **Whether the guest tier is ever needed** — possible that native + container covers the whole fleet and the guest/host tiers stay named-but-unbuilt indefinitely; that is an acceptable outcome, not a gap.

## Drawbacks

- **A spectrum is a taxonomy, and taxonomies invite over-classification.** The risk is that every new service triggers a "which tier?" deliberation instead of defaulting to native. The rule mitigates this by defaulting to the lowest tier and promoting only on a named property — but the mitigation is only as strong as the properties are crisp. If they blur, the model degrades into per-service judgment, which is the status quo with extra ceremony.
- **The container tier is real new capability, and building it is step-3-gated.** keeper is sequenced behind the tower (#387 step 2, itself behind a bad RAM market). So designing the model now is right (bank the reasoning while the decision is cheap), but *building* the container tier — oci-containers, image pinning, keeper's TLS/OAuth seam — should not run ahead of the service that needs it. The note designs; it does not build.
- **The guest seam leans on vapour.** If #555 never lands or picks a substrate that does not fit, the spectrum has a missing position. It degrades gracefully — a guest-wanting service falls back to a hardened container or a dedicated host — but the model should not pretend the guest tier is available before #555 makes it so.
- **The model risks growing past its own justification.** A one-person fleet whose first service is a calendar sync needs only "native, or a container when native won't do" plus the promotion table — which, after adversarial self-review (2026-07-07), is exactly what this note was trimmed to: the rule is the decision; the upper positions are named seams only. This drawback stands as the tripwire — if the seams start getting built speculatively (a hypervisor with no guest-demanding service, a "platform" refactor), the trim's discipline has slipped and the objection re-applies in full.

## Cost

Each *built* tier is standing operational surface: the container tier adds image-pin maintenance and a TLS/ingress seam; a built guest tier would add microVM lifecycle management; a dedicated host adds a machine. Named so the ADR states the price of each rung as it is built, rather than discovering it. The native tier is near-free (a nixpkgs module); the cost climbs up the spectrum, which is itself an argument for the lowest-sufficient-tier rule.

## Rationale & alternatives

- **A0 — status quo (no rule).** Isolation is a packaging accident; fails F3 (no deliberate blast-radius), F4 (no cadence story), and sets no precedent. This is what the note replaces.
- **A1 — native-only, never containers.** Purest declarative form, but keeper cannot land without an ugly native repackage, and HA's cadence fights the weekly bump every week. Fails F4 and F2 (blocks real services). Reality does not fit it.
- **A2 — container-everything.** Uniform and cadence-decoupled, but throws away native modules' declarative integration (ntfy's 21 lines become a container + image pin + volume management), makes every service less reviewable than a nixpkgs module, and adds overhead (F7) for services that do not need it. Rejected as the *default*; retained as tier 2.
- **A3 — hypervisor-everything (a small internal cloud).** Maximal isolation and cadence-independence, unifies #555 — but heaviest (F7), risks making metis load-bearing as hypervisor (F6), is a new paradigm (against ADR-027's "extension, not paradigm"), and depends on unbuilt #555. Over-built for a first service. Rejected as the default; retained as tier 3.
- **A4 — the property-driven rule (chosen).** The only option that satisfies F1–F8 together: native default (ethos, cheap), promotion on named properties (F3/F4), lowest-sufficient (F2/F7), guest/host as named seams (F8). It concedes the rule's crispness is load-bearing (Drawbacks) and the guest tier is unbuilt (De-risk) — both honest, neither fatal. Impact of doing nothing: keeper lands as a one-off container with no precedent, and the next three services each re-litigate isolation from scratch.

## Prior art

- **This repo:** ntfy is the native tier proven; `docker.nix` is dev-docker explicitly *not* a service substrate (so the container tier is genuinely new, not a rename); ADR-027 is the composition mechanism; ADR-032 the accrete discipline; ADR-034 the state boundary the stateful tier strikes; ADR-042 is the shape to emulate — a policy expressed as data, with an eval stance and a set≠enforced probe rung to follow.
- **Industry:** the native-vs-OCI-vs-VM spectrum is the standard homelab decision; `virtualisation.oci-containers` is the idiomatic NixOS container-as-service, `microvm.nix`/`nixos-containers` the guest options (#555's territory). Home-Assistant-on-NixOS specifically is a well-known cadence-pain case — the native module chronically lags upstream and many run the container — which corroborates F4 and the cadence-promotion rule directly.

## Unresolved questions

- **The promoting properties' exact predicates** — what counts as "breaking-release cadence," and is a service's tier + its justifying property recorded per-service (a documented note) or left to maintainer judgment? The rule's value scales with this crispness.
- **Capability naming** — a host-agnostic `services` bundle vs a metis-flavoured `homelab` one; leans `services`, settles in the draft/impl.
- **Container backend** — podman vs docker for `oci-containers`; a small build-time selection.
- **Does "stateful" mandate the backup seam inline, or only reference it?** Lean: a stateful service cannot land without a state-recovery answer, so statefulness gates on the backup seam existing — but the backup *mechanism* is a sibling note (restic/btrbk), not this one.
- Out of scope, named not decided: **the placement axis itself** — which host and failure domain a service runs in (the accelerator / watcher / products criticality-class arbitration the operator opened); #555's guest-substrate selection; the TLS/ingress seam (needs >1 service); the metis re-role migration mechanics (a downstream application of this ADR); inference (parked, #387); naming (#368).

## Future possibilities

- **The rule and its seams are the home for the deferred cluster:** #386 (first container-tier application), #555 (the guest seam's substrate), #563's fabric (which tier a remote builder / store server sits in), #565 charters (untrusted code → the guest seam). Where those services *run* is the sibling placement note's territory.
- **An enforcement rung, ADR-042-shaped:** a stance asserting every hosted service declares its tier *and* the property that justifies it — a service silently at the wrong tier (a stateful one with no backup seam; untrusted code in a bare container) fails the check. The set≠enforced closure, once the model has real services to assert against.
- **The guest seam interacts with the former products question:** if #555 matures, a service the placement sibling would otherwise send toward its own box (short of hardware coupling) may instead land as a guest — but *where* anything in that former class runs is [fleet-service-placement.md](./fleet-service-placement.md)'s call (whose lean is to dissolve the category entirely); the guest seam only changes *how isolated* a service is once placed.
