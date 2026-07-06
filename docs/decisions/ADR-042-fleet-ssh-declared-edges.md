# ADR-042: Fleet SSH trust — declared edges, static per-host keys

**Date**: 2026-07-07
**Status**: Accepted, Implementation pending (#524 re-scoped)

> Fleet SSH user auth stays on **static per-host keys**; the trust topology becomes a **declared edge whitelist** — destination host → authorised source hosts — held as data in `lib/`, derived into each host's `authorizedKeys`, and stance-asserted. An SSH CA and Tailscale SSH are **declined on today's evidence**, each behind recorded migration triggers (Consequences). The *why* lives in the design note [`docs/design/fleet-ssh-identity.md`](../design/fleet-ssh-identity.md); this ADR freezes the decision. Amends [ADR-010](./ADR-010-ssh.md), whose §History carries the per-host key model this builds on.

## Context

#524 was completing an any→any key matrix: every enrolled per-host key accepted by every sshd host, via the single flat `authorizedKeys` list in `lib/operator.nix`. #558 forced the identity-architecture question — SSH CA, Tailscale SSH, or the matrix — before that shape shipped; the design note ran the three-way selection against nine named forces with pin-verified de-risk. The operator's target fleet (recorded 2026-07-07 in the note) settled the topology's shape: sources are exactly the three interactive workstations (jupiter, neptune, saturn); the service tier (metis post-#387, M720q, Raspberry Pi) is pure sink; mercury and nixos-vm are retiring.

## Decision

- Per-host, passphrase-less, fleet-only outbound keys (ADR-010 §History 2026-07-03) remain the credential; no CA, no certificates, no second SSH server.
- Trust edges become declared data: an `sshEdges` map (destination → sources) beside per-host `hostKeys` in `lib/`; each platform's `users.nix` derives its own `authorizedKeys` from its hostname (via the `hostContext` module argument). The first commit is behaviour-preserving; any narrowing is a reviewed, data-only change.
- **Trust flows downhill**: workstations mesh with each other and reach the service tier; sink hosts accept only workstations, never each other, and never generate outbound fleet keys at all.
- saturn's client-only stance flips — it becomes a destination (tailnet-bound listener evaluated at implementation). mercury never enrols as a source and remains a workstation-only sink until decommission.
- An eval stance asserts per host that the rendered `authorizedKeys` equals the edge-derived set; #551's registry later adds the runtime probe rung (a non-edge key is *refused*).

## Rationale

Single-sourced in the design note's Rationale & alternatives; the three decisive findings only: an SSH CA's *active* revocation is rebuild-propagated exactly like key-line deletion (KRL distribution), so its win is passive expiry alone — bought with a new crown-jewel custody burden (#526 frame) and standing ceremony at single-operator scale. Tailscale SSH moves authorisation into the unversioned tailnet ACL (until #556 lands), bypasses the stanced sshd posture entirely, and cannot serve on the Macs' pinned GUI variant. The flat matrix's real defect is its *shape* — every key opens every door, which is precisely the service-tier → workstation attack direction — not its maintenance cost, which `lib/operator.nix` single-sourcing already made O(N).

## Consequences

- ✓ Every trust edge is a reviewable line in git; any→any becomes a data question, never an architecture default.
- ✓ At target, the standing key surface is three workstation keys on encrypted interactive machines; a compromised service box holds no SSH rail upward and none sideways.
- ✓ One sshd posture per host — the existing stance layer (ADR-033) extends rather than forking; no new trust anchors, no new dependencies, break-glass table untouched.
- ✗ No passive expiry: a quietly exfiltrated workstation key is valid until noticed, its line deleted, and affected hosts rebuilt. Accepted knowingly; containment is edge scope plus breach-side detection (#551/#553 lineage).
- ✗ Every trust change propagates at rebuild speed — the latency #552's convergence rings would later compress.
- ⚠ Migration trigger: sshd-running fleet reaches ~8 hosts, or a second operator identity appears → re-run the CA weighing (ceremony cost inverts with scale).
- ⚠ Migration trigger: an unattended flow needs *expiring, scoped* delegation a static key cannot express → design the online-issuance CA (step-ca is packaged in the pin).
- ⚠ Migration trigger: #557 lands TPM-sealed custody that makes host-bound short-lived credentials meaningful → revisit with #526's frame.
- ⚠ Migration trigger: #556 has tailnet ACLs in git with drift detection, the Macs run the open-source tailscaled (or mac inbound is conceded to sshd), and control-plane-down behaviour is empirically verified → Tailscale SSH becomes weighable on its merits.
- ⚠ The fleet backup design must not silently invert the downhill rule: a pull-based backup box is a universal source; prefer push-to-sink or transport-native designs, or reopen this ADR.

## Implementation

#524 re-scopes to "complete enrolment under the declared-edge shape": the edge map, the `users.nix` derivation, and the stance land as one change; the runbooks' §Fleet SSH enrolment gains the edge step; saturn's sshd lands with the tailnet-bound listener evaluated at that commit; metis moves source → sink at #387's re-role as a data change.
