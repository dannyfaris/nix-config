# Home Assistant on electra — the fleet's first household-facing, stateful service

**Status:** Proposed — design note (`docs/design/`). Not built — build gated on #584 (backup capability precedes the first stateful service, operator ruling 2026-08-14). #839 · extends [fleet-service-isolation.md](./fleet-service-isolation.md) and [fleet-service-placement.md](./fleet-service-placement.md) (governing priors, not relitigated) · interacts with ADR-034 (via #584) and ADR-042 · loop 1 scope is single-operator; household induction is a named open question that reopens this loop (§Unresolved questions).

## Summary

Electra runs Home Assistant as a three-service native constellation — `services.home-assistant`, `services.zigbee2mqtt`, `services.mosquitto` — driving a Sonoff Zigbee USB coordinator with Sonoff, Philips Hue, and Aqara devices paired directly to the mesh (no vendor hubs, no vendor clouds). HA's module and package are pinned whole-vertical from a second flake input, moved only by a deliberate operator ritual — the weekly bump never changes the house's brain (operator ruling 2026-08-14; §Design, §Rationale & alternatives). Loop 1 is deliberately single-operator: access is tailnet-only, electra's inbound firewall posture does not change at all, and the household-facing access question — settled in direction (app-layer auth on the LAN, not tailnet onboarding) but not in implementation — parks as a named open question until the operator calls induction time, when this loop reopens and note + implementation iterate together. Build waits on #584: Home Assistant is the fleet's first service whose state would genuinely hurt to lose (Zigbee network keys, device pairings, auth), which is exactly ADR-034's fired migration trigger, and this note's state inventory (§Design) is #584's input.

## Motivation

The household's smart accessories (Sonoff, Philips Hue, Aqara — all Zigbee) have no automation brain. The operator wants one, on owned hardware, eventually usable by household members from their phones and tablets with none of the fleet's operator machinery — no VPN, no tailnet onboarding, no awareness the fleet exists. The fleet has never hosted a household-facing service or a non-operator user; nor has it hosted a service whose state cannot be reprovisioned from source. Home Assistant is both at once, which is why it moves through the design loop rather than landing as another ntfy-shaped module.

The intake dialogue (#839, 2026-08-14) also fixed what this loop is *not*: loop 1 serves the single operator only. The household questions shaped the direction and are recorded below, but no household-facing surface ships in this iteration.

Forces any design must satisfy:

- **F1 — declarative, whitelist-shaped.** Explicit > implicit, whitelist > blanket: the stack's configuration should be repo-visible Nix/YAML, not UI-and-database opacity, and any network opening is scoped and rationale-commented.
- **F2 — the mesh survives the fleet's lifecycle.** Under declarative management every config-touching `nh os switch` restarts the affected units, and this repo rebuilds as a way of life. The Zigbee radio must not blip on every HA iteration.
- **F3 — no irreplaceable state before the backup capability.** ADR-034's no-backup stance rests on reprovision-from-source; `.storage` and the Zigbee network keys break that premise. The operator's ruling: #584 runs to completion first, informed by this note; build here follows it.
- **F4 — no scaffold riders.** Electra's container-tooling decision is deliberately gated (#637); the isolation note's rule is native-by-default, promoted only by a named property. This adoption must not force either gate open in passing.
- **F5 — household-usable eventually, without fleet onboarding.** A direction-force for loop 1 (nothing chosen may foreclose it), a design-force for the induction iteration.
- **F6 — runtime-verified, not just declared.** Set ≠ enforced (#303, the #336 lesson): the posture claims this note makes are probed on the host before the work is called done.
- **F7 — hardware coupling handled declaratively.** The USB coordinator is physical state; its plumbing (device path stability across enumeration, service access to the tty) must be declared, not discovered per-boot.
- **F8 — the house's brain moves only deliberately.** HA's version must change only by explicit operator action, never as a side effect of the weekly bump (operator ruling 2026-08-14): the fleet stays evergreen, the household-facing brain updates at chosen moments with release notes read.

## Design

**The constellation.** Three native NixOS services on electra — the isolation note's default tier; the one promotion property that note names for HA (breaking-release upstream cadence) is answered *inside* the tier by a whole-vertical version pin (below), not by container promotion (§Premises P6, §Rationale & alternatives):

- `services.home-assistant` — the brain. Component set declared via the module's component mechanism; credentials that can be declared flow from sops-nix (already wired on electra).
- `services.zigbee2mqtt` — owns the Sonoff USB coordinator and the Zigbee mesh. Its YAML configuration is managed declaratively by the module (F1); it publishes to MQTT.
- `services.mosquitto` — the broker seam between mesh and brain, loopback-scoped in loop 1 (no listener beyond localhost; HA and z2m are co-resident).

The MQTT seam is what buys F2: zigbee2mqtt holds the radio, so Home Assistant restarts — frequent under declarative iteration — never bounce the mesh. HA reconnects to the broker and the mesh never noticed.

**Version pinning — the cadence answer (F8; operator ruling 2026-08-14).** HA's module and package both come from a second flake input (`nixpkgs-ha`, nixos-unstable at an operator-chosen rev): the built-in module is disabled via `disabledModules` and imported from the pinned input instead, with `services.home-assistant.package` resolved from the same input — module and package travel together, so there is no version skew. zigbee2mqtt and mosquitto stay on the main input and ride the weekly bump; they are boring, stable packages and the mesh gains nothing from pinning. Two operational consequences are part of the design, not afterthoughts: the weekly flake-lock bump must exclude `nixpkgs-ha` (a bare `nix flake update` would silently defeat the pin — the bump workflow is configured for selective update), and HA gains its own deliberate ritual — read the monthly release notes, `nix flake update nixpkgs-ha`, build, deploy; rollback is reverting one lock-file entry. The initial rev is simply the main input's rev at build time, inheriting P4's verification.

**Access, loop 1.** Tailnet-only, the established electra pattern (ntfy-server.nix): services bind where they like, the firewall default-denies everything except `tailscale0`, and no firewall change ships. The operator reaches the HA UI (port 8123) and the z2m frontend over Tailscale. Companion app on the operator's phone uses the tailnet URL.

**Access, the recorded direction (parked).** The induction iteration's starting lean, settled in the intake dialogue: household access lands as an app-layer boundary — TCP 8123 opened interface-scoped to the LAN, HA per-user non-admin accounts, no `trusted_networks` auto-login — not as tailnet onboarding of family devices. Network-layer auth is the right boundary for operators and the wrong one for household users (VPN friction, fleet-adjacent family devices, "the lights don't work" failure modes). The minimal-vs-anticipatory LAN posture question and TLS-on-LAN park with it. Nothing in loop 1 forecloses this (F5): the constellation is LAN-adjacent already, and induction is a firewall amendment plus account creation, not a re-architecture.

**Hardware plumbing (F7).** The coordinator is referenced by `/dev/serial/by-id/…`, never `/dev/ttyUSB*`, so enumeration order cannot rebind the mesh; the z2m service user gets tty group access declaratively. The dongle's firmware flavour (ZBDongle-P/TI vs ZBDongle-E/Silabs) is confirmed in the selecting-tooling pass before purchase-or-flash decisions are recorded.

**State inventory — input to #584.** What the constellation accumulates, where, and what losing it costs:

- `/var/lib/hass` — HA's config dir: `.storage/` (entity/device registry, per-user auth, integration tokens — the irreplaceable core), the recorder database (history; loss is tolerable), YAML the module manages (reprovisionable).
- zigbee2mqtt's data dir — `database.db` (paired-device registry), the network key material and coordinator backup. Loss means re-pairing every device in the house — walking to each sensor with a paperclip. This is the single most loss-expensive item.
- mosquitto persistence — transient QoS state; loss is a non-event.

Restore expectation for #584: file-level restore of the two state dirs onto a fresh electra reprovision should recover the mesh and the brain without re-pairing. All three dirs join the persist whitelist per the module-owns-its-state pattern (ephemeral-root.md), each entry owned by its service module, ntfy-server.nix as the worked example (including its `/var/lib/private` DynamicUser lesson, which likely already covers any DynamicUser member of the constellation — verified at implementation).

**Delivery slices — both after #584 lands (the operator's sequencing ruling, §Rationale & alternatives, gates all build on the backup capability, not merely the pairing step).** Slice 1: constellation up, dongle bound, operator access over tailnet, runtime probe green. Slice 2: devices paired, automations begin — the point at which state becomes real. Household induction is not a slice; it is the next loop.

**The runtime probe (F6).** Loop 1 makes a *negative* posture claim, which is cheap and falsifiable: from a LAN (non-tailnet) vantage, nothing on electra is newly reachable — 8123 and 1883 and the z2m frontend all refused; from the tailnet, 8123 answers. Probed on the host before the work is called done, per the repo's set-≠-enforced convention.

How the design meets the forces: F1 by the all-native, YAML/Nix-declared constellation; F2 by the MQTT seam; F3 by the #584 gate and slice ordering; F4 by staying at the native tier with no container substrate touched; F5 by the parked-but-unforeclosed induction direction; F6 by the negative-claim probe; F7 by the by-id binding; F8 by the whole-vertical pin.

## Premises

External claims this note rests on, with verification status. The elimination-bearing ones are flagged loudest, per the #763 scorecard.

- **P1 (eliminated ZHA; unchecked — deferred to the hardware-in-hand pass).** Home Assistant restarts bounce a ZHA-owned coordinator — the mesh blips on every HA unit restart. Structurally near-certain (the radio is in-process) but not yet verified at source; confirmed before build, alongside the hardware checks.
- **P2 (eliminated ZHA; unchecked — deferred to the hardware-in-hand pass).** zigbee2mqtt's device coverage and quirk handling for the actual accessory set — Aqara especially — is at least ZHA's equal. Conventional wisdom, taken on notice only; the selecting-tooling pass verifies against the specific device models once they exist.
- **P3 (checked).** HA's `synology_srm` device tracker supports the operator's RT2600ac — verified against home-assistant.io integration docs, 2026-08-14 (legacy-tier integration; `nmap_tracker`/ping are router-agnostic fallbacks). Underwrites "no household remote access" closing no doors on future presence detection.
- **P4 (checked, 2026-08-14).** nixpkgs at the flake pin ships live modules for all three services, and the HA module's component mechanism covers the needed integrations — evaluated against `nixosConfigurations.electra` (results in §De-risk evidence).
- **P5 (unchecked — deferred to the hardware-in-hand pass).** zigbee2mqtt supports the specific Sonoff dongle flavour in hand (P vs E; ember maturity if E). Folded into the selecting-tooling pass.
- **P7 (checked, 2026-08-14; eliminated the stable-pin option).** HA upstream supports only its latest release — home-assistant.io/security: "We only accept reports against the latest stable & official versions of Home Assistant or any versions beyond that are currently in development or beta test." A stable-channel freeze therefore ages out of security support within months; this underwrites both the stable-pin rejection (§Rationale & alternatives) and the ritual-rot drawback (§Drawbacks).
- **P6 (checked, 2026-08-14).** The isolation note's cadence-promotion property for HA rests on "the native module chronically lags upstream" — not firing at this pin: nixpkgs ships home-assistant 2026.7.4 (P4 eval) against upstream 2026.8.1 (github.com/home-assistant/core releases, checked 2026-08-14), one monthly release behind and actively maintained. The property's other face — breaking releases arriving on the weekly bump — is removed outright by the whole-vertical pin (§Design): HA's version moves only by deliberate operator action. What this check cannot refute, the design accepts instead: the ritual the pin creates (§Drawbacks, §Cost), and chronic nixpkgs lag as the residual container trigger — P6 is the dated baseline that gap is watched against.

## De-risk evidence

Verified so far (design stage, 2026-08-14):

- P3 checked at home-assistant.io (see Premises).
- **P4 checked by eval against `nixosConfigurations.electra` at the flake pin (2026-08-14):** `services.home-assistant` present with both `extraComponents` and `customComponents` (home-assistant 2026.7.4); `services.zigbee2mqtt` present with the freeform `settings` surface the declarative-fit ruling relies on (zigbee2mqtt 2.12.1); `services.mosquitto` present (mosquitto 2.1.2); `mqtt` and `synology_srm` both in the HA package's `availableComponents`. One nuance recorded: this pin exposes `availableComponents` only (no `supportedComponents` passthru), so "available" here means the component exists in the release — its dependency closure materialises via `extraComponents` at build, which is exercised the first time slice 1 builds.
- The native-tier pattern and its persist gotcha are proven in-repo: `modules/nixos/ntfy-server.nix` (tailnet-only exposure, module-owned persist entry, the `/var/lib/private` DynamicUser lesson).
- The governing priors exist and were consulted — including where they push back. The isolation note's native-default rule carries an HA-specific cadence caveat this note engages rather than elides (P6, §Rationale). The placement note decides zero placements by construction and instructs that HA's arrival forces "a real placement decision on its own facts": that decision is made *here*, by the prior's rules rather than by convenience — **R2** (hardware-coupled services place with their hardware, the box-with-the-USB-stick; never alcyone, never a sentinel) and **R5** (everything else lands on electra) both reach electra, and the sui-generis properties the prior names for HA (hardware + uptime + cadence) are all engaged in this note rather than quoted selectively.

Deferred to the hardware-in-hand pass (operator ruling, 2026-08-14: the design-stage de-risk is deliberately minimal — pin sourcing only; the loop returns here once the dongle and devices physically exist):

- P1: verify at source (HA/ZHA docs or code) that a ZHA coordinator rides the HA process lifecycle — the claim that eliminated the simpler option gets symmetric scrutiny.
- P2 + P5: the selecting-tooling pass — z2m device database entries for the actual Sonoff/Hue/Aqara models and the dongle flavour, checked at the z2m version in the pin.
- The runtime probe itself (§Design) runs at slice 1.

Unverified and stated as such: everything in the parked induction direction (LAN-scoped firewall mechanics, HA's auth/IP-ban behaviour) — deliberately, since no household surface ships in loop 1.

## Drawbacks

- **The house gains a dependency on the fleet.** Automations, and eventually household users, come to rely on a hobbyist-maintained host with a weekly-bump cadence. A vendor hub (Hue Bridge + app) would be more boring and more robust for the household; this direction trades that robustness for ownership, privacy, and declarative control.
- **First stateful service.** The reprovision-from-source purity ADR-034 rests on is genuinely eroded — that is why #584 gates build, but the erosion is permanent once devices pair.
- **Three services where a vendor hub is zero.** The constellation is cheap at the native tier, but it is still three units, three persist entries, and a broker to reason about.
- **HA is only partially declarative in practice.** Integrations added via UI flows live in `.storage`, not in Nix — a declared-vs-runtime split that F1 can narrow but never close. The repo must be honest that HA's core config model is imperative-leaning.
- **The pin's failure mode is the operator.** Nothing forces `nixpkgs-ha` forward: skip the update ritual for half a year and the fleet has voluntarily reinvented stale-HA — out of upstream security support (P7), integrations aging against the moving cloud/firmware world they talk to. Tracking-native had no such rot mode; the pin trades the bump's surprise-breakage risk for a discipline requirement.
- **USB coupling hardens placement.** The dongle physically pins the mesh to electra; host migration or failure now involves hardware relocation, not just a rebuild (the placement note's sui generis observation, now made real).

## Cost

- **Maintenance-cadence coupling arrives.** The placement note's named residual becomes live: the weekly bump now restarts a plane the household will eventually expect to be always-up. The MQTT seam confines the blast (mesh survives; automations blip), but the coupling is a standing price, not a one-off.
- **Zigbee pairing state is permanently imperative.** Device pairings cannot be declared; they are runtime state that only backup (#584) protects. The whitelist-of-everything ideal stops at the radio.
- **A second update plane, and heavier evals.** The HA ritual (release notes → `nix flake update nixpkgs-ha` → deploy) is a standing routine outside the weekly bump, and the second nixpkgs instance makes every electra eval heavier (CI and host) — paid on all builds, not just HA-related ones.

## Rationale & alternatives

**Deployment shape — native module with a whole-vertical version pin, over tracking-native, OCI container, and HAOS-in-a-VM.** The container is not a strawman here: it is the isolation note's own named answer to a real property HA carries — upstream breaking-release cadence vs the weekly bump (that note's F4; its prior art calls HA-on-NixOS "a well-known cadence-pain case"), with image-pinning as the decoupling. The whole-vertical pin (§Design) takes exactly that benefit — HA's version moves only by deliberate operator action — without leaving the native tier: no container substrate, no image trust story, no scaffold-rider opening of electra's gated container-tooling decision (this note's F4). The isolation note's own text licenses the within-tier answer: promotion is warranted only by a property "that a lower tier cannot satisfy", and its F4 states the cadence requirement as the service being able to "pin its own version independent of the bump" — which the second input provides without promotion. *Tracking-native* (no pin, one update habit fleet-wide) was the dialogue's initial lean and remains the cheaper posture; the operator ruled for the pin from day one (2026-08-14): for a household-facing service, controlled update timing is worth a standing ritual, and the coupling it removes — HA's monthly breaking releases arriving as a side effect of the weekly bump — is precisely the coupling the isolation note warns about for HA. *Pinning to NixOS stable* was examined and rejected: HA upstream supports only its latest release (P7), so a stable-channel freeze ages out of security support within months, integrations rot against the moving cloud/firmware world they talk to, and the semiannual channel jump batches ~6 breaking releases into one event — for HA specifically, close-tracking at operator-controlled tempo is the safe posture, not version age. The container thereby demotes to a residual trigger with the one firing condition no pin can fix: **if nixpkgs' HA packaging itself falls chronically behind upstream (P6 is the dated baseline the gap is watched against), promotion to the container tier per the isolation note's table is the recorded remedy, not a fresh debate.** The isolation note's flagged judgment call ("a service that is ambiguous (a native module exists *but lags upstream badly*) will still need a judgment call") is thus answered with P6's measurement rather than by omission. HAOS-in-a-VM buys the Supervisor add-on store, but add-ons are imperatively-managed containers — the antithesis of F1 — and the microVM substrate is itself an unbuilt seam (#555). The native module satisfies F1/F4 directly, and "add-ons" become sibling native services, which is this repo's preferred shape anyway. P4's pin check has since confirmed the module surface.

**Zigbee stack — zigbee2mqtt + mosquitto, over ZHA.** ZHA wins on simplicity (one service, no broker) and loses on F2 (P1: the in-process radio rides HA's restart-heavy declarative lifecycle) and F1 (UI-and-database configuration vs z2m's declarable YAML), with P2's device-coverage edge as supporting evidence. Operator ruling 2026-08-14: the constellation's complexity is well worth the declarative fit. Both eliminated-option premises (P1, P2) carry explicit verification obligations before build.

**Sequencing — wait for #584, over land-jointly or stage-gated decoupling.** Merging the backup question into this note would entangle an ADR amendment and its own tooling selection into an already-broad exercise (two exercises, one note — against the repo's one-note-per-exercise convention). The stage-gate option (build now, gate pairing on #584) was viable but trades cleanliness for speed the operator doesn't need. Ruling: #584 first, with this note's state inventory as its input — the backup design gets a concrete first customer, and this design gets a real backup target instead of a promise.

**Access — tailnet-only loop 1, over shipping the household surface now.** The household boundary is the largest stance change in the exercise; the operator scoped it out of loop 1 to iterate on it deliberately when induction is actually wanted, with the design loop reopening at that point. The direction (app-layer boundary, not tailnet onboarding) is recorded so the future iteration starts from today's reasoning rather than re-deriving it.

**Doing nothing** leaves the accessories driven by vendor apps or nothing at all: no automation, per-vendor silos, and the household's smart-home value unrealised. The devices are already owned; the marginal cost of the brain is three native services.

## Prior art

- **In-repo:** ntfy-server.nix is the native-tier worked example this constellation triples (tailnet-only exposure, module-owned persist entries, DynamicUser gotcha). The isolation and placement notes are the governing priors — this adoption is deliberately their first real exercise, and the placement note already named Home Assistant sui generis (hardware + uptime + cadence, all three engaged here: R2/R5 for placement, R3 queued at slice 2, the cadence property answered inside the native tier by the whole-vertical pin, with P6 the dated baseline). #791 (the ntfy.sh iOS relay) is the repo's precedent for a deliberate, constrained public-cloud dependency — cited here as the shape a future Nabu Casa decision would take, not as a commitment.
- **Community norm:** most HA deployments run HAOS on dedicated hardware (Pi/NUC/VM) precisely to get the Supervisor's managed backups and add-ons. The NixOS community's counter-pattern — native module + sibling services (z2m, mosquitto) declared in Nix — is well-trodden and is the shape adopted here; it trades the Supervisor's conveniences for declarative control, and its known rough edge (UI-managed `.storage` state) is acknowledged in Drawbacks rather than papered over.

## Unresolved questions

- **Household induction — the named open question.** When the operator calls it, this loop reopens: LAN exposure mechanics (minimal 8123 vs any discovery allowances), TLS-on-LAN vs recorded plain-HTTP acceptance, per-user account setup, and the runtime probe for the amended posture. The recorded direction (§Design) is the starting lean, not a pre-made decision.
- **#584's outcome** shapes the restore mechanics this note only sketches (file-level restore expectation, §State inventory). If #584's chosen mechanism imposes constraints (e.g. snapshot-consistency requirements for the SQLite recorder), they flow back into this note's implementation.
- **R3 fires at slice 2 — mandated by the placement prior, not optional.** The first service on electra with a real uptime expectation triggers the ADR-030 trigger-3 evaluation for electra (ring position last, kernel-update discipline, or stable channel). HA's automations make that expectation real at slice 2; the evaluation runs then, before the household ever depends on the box, escalating to R4 only if the posture can't stretch.
- **Resolved during the selecting-tooling pass:** P2 (device coverage), P5 (dongle flavour), and the z2m version/feature check at the pin.
- **Resolved at implementation:** exact persist entries (and whether ntfy's `/var/lib/private` entry already covers a DynamicUser member), recorder DB choice (default SQLite vs PostgreSQL — default unless the operator states otherwise), z2m frontend exposure details, component list for the HA module, the `disabledModules` import mechanics, and the weekly-bump workflow's exclusion of `nixpkgs-ha`.
- **Explicitly out of scope:** household remote access (ruled out for the household; operator retains tailnet), voice assistants, Matter/Thread, presence detection (P3 keeps the door open; nothing ships).

## Future possibilities

- **Household induction** (the parked iteration — see Unresolved questions).
- **Router-based presence** via `synology_srm` (P3) — home/away automations with zero remote path, when wanted.
- **The MQTT broker as shared infrastructure** — ESPHome/Tasmota-class devices, future sensors, or other fleet services publishing to the same seam.
- **Nabu Casa** if voice assistants or household remote access ever earn their keep — the #791-shaped deliberate-exception precedent applies.
- **Matter/Thread** if the accessory ecosystem drifts that way; the constellation shape (separate radio service, broker seam) extends naturally.
