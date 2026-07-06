# Fleet SSH identity — declared edges, no new trust anchor

**Status:** Proposed — design note (`docs/design/`). Not built. #558 (reconciles #524; adjacent to #526, #551, #556, #570). Drafted 2026-07-07. Expect an ADR on acceptance (amending ADR-010).

## Summary

Keep the fleet's SSH trust on static per-host keys — but narrow the shape from #524's implicit any→any to a **declared edge whitelist**: a single data map (destination host → authorised source hosts) in `lib/`, from which each host's `authorizedKeys` is derived, with a stance asserting the derivation holds. No SSH CA, no Tailscale SSH; both are declined *today* on evidence, with the migration triggers that would reverse that decision recorded and watchable. The unit being whitelisted stays the per-host key; the thing that changes is that every trust edge becomes an explicit, reviewable line in git rather than a consequence of a flat list.

## Motivation

The fleet is five hosts: four run sshd (mercury, metis, nixos-vm, neptune); saturn is deliberately client-only (`hosts/saturn/default.nix`). Outbound auth is mid-migration under #524: one passphrase-less ed25519 key per host, generated on that host, its public half appended to the single flat `authorizedKeys` list in `lib/operator.nix` that every host's `users.nix` consumes. Two keys are enrolled today (neptune, metis); mercury and saturn enrol at their next bootstrap events, at which point any of the four keys opens any of the four sshd hosts.

#558's intent, stated solution-free: fleet SSH trust should be **(a)** declared and reviewable in git, **(b)** bounded in what a single compromised host can reach, **(c)** cheap to grow — O(1) edits per new host, **(d)** revocable in bounded time, and **(e)** operable by one person with near-zero recurring ceremony. The issue frames this as "identity, not key lists" and names an SSH CA and Tailscale SSH as candidate architectures, with finishing #524's matrix as the status-quo outcome if the evidence supports it.

Grounding against the working tree reframes the problem in three ways:

- **The matrix's maintenance cost is already O(N), not N×N.** The flat list is single-sourced: adding a host is one generated key plus one line in `lib/operator.nix` plus one committed host pubkey. The N×N lives in the *trust relation* (every key opens every door) — which is the security shape #558 is actually naming, and that critique stands. The grounding corrects only the cost half of the framing, because an inflated maintenance burden would overweigh the CA's convenience case; the forces that carry the issue's real concern are F2 and F7 below.
- **Host identity is already solved.** Committed host pubkeys pinned via `modules/shared/ssh-known-hosts.nix` killed TOFU fleet-wide (#517). A CA's host-certificate half offers nothing here; only the *user-auth* half is in question.
- **The unscoped shape has a concrete consequence.** mercury is the work-only, internet-adjacent EC2 host; under the flat list its key (once enrolled) opens the personal hosts and every personal host's key opens it. That is the #570 work/personal boundary's SSH slice, decided by default rather than deliberately.

The forces any design must satisfy, in rough priority order:

1. **F1 — Declared trust:** every edge visible and reviewable in git (whitelist > blanket, explicit > implicit).
2. **F2 — Compromise containment:** a stolen credential's reach is bounded in *scope* (which doors) and *time* (how long), with the two measured honestly and separately.
3. **F3 — Evergreen growth:** O(1) marginal work per new host; the fleet is growing (saturn just landed, a Pi is mooted in #547, #387 contemplates a main PC).
4. **F4 — Degraded-mode survival:** auth must not become more dependent on the tailnet, its control plane, or GitHub being up (#566); the break-glass table stays intact.
5. **F5 — No unowned crown jewels:** any new highest-value secret needs a custody design in the #526 frame before it exists.
6. **F6 — One assertable posture:** the stance layer (`lib/stances.nix`, ADR-033) must keep asserting the *actual* auth surface, and #551's probe rungs must be able to reach it; two parallel SSH postures on one host is a standing lint on this force.
7. **F7 — Edge scoping:** the work/personal boundary must be expressible per edge (#570).
8. **F8 — Zero standing ceremony:** single operator; no recurring signing/renewal rituals.
9. **F9 — Platform coverage as pinned:** the mechanism must cover darwin inbound (neptune) with the nix-darwin actually in the lockfile, not an idealised one.

## Design

**The mechanism: trust edges as data, keys as today.**

`lib/operator.nix` (or a small sibling — implementation's call) stops exporting one flat `authorizedKeys` list and instead exports the same material shaped as identity plus topology:

```nix
hostKeys = {
  neptune = "ssh-ed25519 AAAA… dbf@neptune";
  metis   = "ssh-ed25519 AAAA… dbf@metis";
  # mercury, saturn appended at their enrolment events, as today
};

# destination → source hosts whose keys it authorises
# (strawman set — the operator settles which flows are real; see
# Unresolved questions)
sshEdges = {
  mercury  = [ "neptune" "saturn" "metis" ];
  metis    = [ "neptune" "saturn" ];
  neptune  = [ "metis" ];
  nixos-vm = [ ];
};
```

Each platform's `users.nix` derives its `authorizedKeys` by looking up its own hostname in `sshEdges` and mapping the named sources through `hostKeys`. The hostname arrives through the established `hostContext` module argument (`lib/mk-host-context.nix`'s `_module.args` bridge, ADR-019); `users.nix` does not take that argument today, so the implementation adds `hostContext` to its signature — the same one-word change `modules/{nixos,darwin}/stylix-palette.nix` already made to consume it. The first commit expresses the *current* flat semantics as edge data (behaviour-preserving refactor); narrowing the edge set is then a data-only change the operator makes deliberately. The any→any question stops being an architecture and becomes a reviewable attrset — the strawman set above is exactly that, a strawman, held in Unresolved questions for the operator to settle.

**Enforcement follows the existing rungs.** An eval stance (`lib/stances.nix`) asserts per host that the rendered `authorizedKeys` equals the edge-derived set — a key present on a host with no declaring edge fails CI, exactly the shape ADR-033 already gates. When #551 lands its registry, this stance grows the runtime rung: a probe demonstrating a non-edge key is *refused* by the live sshd, retiring another "set ≠ enforced" gap (#303 lineage).

**Companions, not dependencies.** The tailnet ACL (#556) adds the network-layer ring — which nodes can reach :22 on which — mirroring the edge map one layer down; it proceeds by its own loop and this design neither waits for nor assumes it. #526 untangles neptune's legacy triple-role key independently; this design consumes its outcome (a fresh fleet-only neptune key becomes just another `hostKeys` entry). Revocation latency (delete edge/key, rebuild fleet) is what it is today — manual propagation — and is the same latency #552's convergence rings would later compress fleet-wide; nothing here needs to anticipate that.

**What is deliberately not built:** no CA keypair, no certificate issuance, no KRL distribution, no second SSH server. The migration triggers that would reopen those are recorded in Future possibilities, phrased for #562's machine-watching.

How the design meets the forces: F1 (every edge is a line in git), F2-scope (a compromised host reaches only its declared edges), F3 (one key + one pubkey + edge entries per new host), F4 (keys are local files; auth works with the tailnet, its control plane, and GitHub all dark), F5 (no new secrets of any class), F6 (one sshd posture per host, existing stances extended not forked), F7 (the edge map *is* the boundary's SSH expression), F8 (no ceremonies; nothing expires), F9 (both platforms already consume the flat list from the same source — the derivation swap is symmetric). The one force it does not satisfy is F2-time, examined in Drawbacks.

## De-risk evidence

Verified against the working tree at `main` `a6293c8` and the running pins, 2026-07-07:

- **The flat list and its consumers:** `lib/operator.nix` `authorizedKeys` (two keys enrolled: neptune, metis) consumed by `modules/nixos/users.nix` and `modules/darwin/users.nix`; per-host key model and the passphrase-less carve-out recorded in ADR-010 §History (2026-07-03).
- **Host-identity pinning:** `modules/shared/ssh-known-hosts.nix` pins committed host pubkeys for neptune/mercury/metis on both platforms — TOFU already dead, so host certificates add nothing.
- **nix-darwin can carry arbitrary sshd directives on our pin:** `nix eval .#darwinConfigurations.neptune.config.services.openssh.extraConfig` returns the full hardening block (this session). A research pass against upstream nix-darwin master claimed only `enable` exists — contradicted by the pin; recorded here as the reason this note trusts evals over upstream docs. Consequence: the CA option's darwin delivery (`TrustedUserCAKeys` via the same drop-in) *would* be mechanically possible — B is declined on the weighing, not on feasibility.
- **Tailscale SSH server-side platform support:** official KB — Linux, plus macOS *only* via the open-source tailscaled variant (<https://tailscale.com/docs/features/tailscale-ssh>). The fleet's Macs run the GUI app (`tailscale-app` cask, `io.tailscale.ipn.macsys` — `modules/darwin/homebrew.nix`), which cannot serve. neptune's inbound would stay on sshd regardless.
- **Tailscale SSH bypasses sshd:** per the same KB page, tailnet SSH terminates in tailscaled's built-in server; `sshd_config` hardening (and therefore the entire `sshNixos`/`sshDarwin` stance layer) does not govern those sessions. Authorisation lives in the tailnet ACL `ssh` section — which is exactly the artifact #556 exists to bring into git.
- **OpenSSH CA mechanics** (for the declined-but-weighed option): `TrustedUserCAKeys`, principals (`-n`), validity windows (`-V`), `source-address`, and KRL revocation per sshd_config(5)/ssh-keygen(1) (man.openbsd.org). Note the KRL point that shaped the weighing: *active* revocation under a CA still requires distributing a revocation artifact to every host — the same rebuild-propagation latency as deleting a key line; expiry is the CA's only *passive* win.
- **CA tooling packaging reality:** `step-ca` 0.29.0 present in the nixpkgs pin (`nix eval .#nixosConfigurations.metis.pkgs.step-ca.version`); a `services.step-ca` NixOS module exists upstream (not needed by this design; recorded for the trigger path).
- **`hostContext` reaches system modules via the established bridge:** `lib/mk-host-context.nix:45` sets `_module.args.hostContext` on both platforms, and `modules/{nixos,darwin}/stylix-palette.nix` already consume it through their module signatures — so the Design's derivation needs only a signature addition in `users.nix`, no new wiring (verified by grep, this session; flagged by peer review).

Unverified, stated rather than implied:

- **Tailscale SSH behaviour with the control plane unreachable** (existing sessions, new connections between nodes with valid keys and cached netmaps): official docs are silent; not empirically probed because no candidate that depends on it survived the weighing. Must be probed before any future trigger-driven adoption of C.
- **The strawman edge set's fitness** — which flows are real (does mercury need *any* outbound fleet key?) is an operator decision, not a verified fact.
- The exact stance/probe wording lands with implementation.

## Drawbacks

- **No passive expiry — F2-time is genuinely unmet.** A quietly exfiltrated key stays valid until noticed, the edge or key line deleted, and every affected host rebuilt. This is the CA's real advantage and this design declines it. The bounds offered instead: edge scoping caps what the key reaches; the private keys never leave their hosts by construction (per-host generation, ADR-010); and detection-side coverage (#551 probes, #553's audit) is where the program invests. If this residual is judged unacceptable, B is the answer and this note's weighing says what it costs.
- **N passphrase-less private keys at rest, per ADR-010's operator-endorsed carve-out** — every enrolled host is one theft or live compromise away from its declared edges. Containment is breach-side, not credential-side: #557's TPM sealing (deferred) and the Macs' FileVault bound physical theft; nothing bounds a live compromise except the edge scope itself. This is the price of declining expiry, named plainly.
- **The edge map can ossify.** A stale edge (a flow that stopped existing) is invisible to the stance, which asserts derivation, not need. Periodic honesty is on the operator; #571's usage-ledger idea is the eventual instrument if this bites.
- **Declining Tailscale SSH keeps all authz eggs in the key basket** even after #556 lands ACLs-as-code; the network ring will scope reachability but never identity.
- **If the operator settles on the full any→any edge set anyway,** the mechanism degenerates into today's flat list with extra indirection — in that case the honest move is keeping the flat list and closing #558 with "matrix affirmed", not shipping unused machinery.

## Cost

The standing price of the chosen direction: fleet auth remains coupled to rebuild-propagation for every trust change (add, narrow, revoke) — acceptable at five hosts, and the exact latency #552 would later compress, but a real operational property of the no-expiry model that the ADR should state plainly.

## Rationale & alternatives

- **A — finish #524 as-is (flat any→any list).** Wins F1/F3/F4/F5/F6/F8/F9 exactly as the chosen design does, and it is simpler. Loses F7 outright — the work/personal SSH boundary stays decided-by-default — and F2-scope (any compromise reaches everything). The chosen design is A with the shape made explicit; A survives as the degenerate data case if the operator declares all edges.
- **B — OpenSSH user CA (offline `ssh-keygen -s`, or step-ca).** Wins F2-time (expiry) and expresses F7 (principals, `source-address`). Loses F5 (a CA key is a new crown jewel needing #526-grade custody before it exists) and F8 (short TTLs mean recurring signing ceremony — for host-to-host automation keys that means an *online* signer, a new attack surface; long TTLs quietly give the expiry win back). Weakened on its own headline by the KRL finding: active revocation still propagates at rebuild speed, so B beats the chosen design only passively. Prior art for fleet-scale NixOS CAs is thin (blog/gist pattern, no canonical config). At one operator and five hosts the ceremony buys little; the triggers below name the scale at which it starts buying a lot.
- **C — Tailscale SSH.** Wins F2-time in its strongest form (central, instant, no rebuilds) and F7 natively (ACL `ssh` rules). Fails F1 *today* — authorisation would move from git into the unversioned ACL console until #556 lands, inverting the repo's philosophy for its most sensitive surface. Fails F6 — bypasses sshd, so the hardened posture and its stances stop governing the actual door; neptune stays on sshd regardless (GUI-variant limitation), making dual posture permanent. Strains F4 — control-plane dependence, with offline behaviour officially undocumented (unverified above). Reconsiderable when its trigger conditions are all true; not before.
- **Do nothing** — #524 stays formally held on #558 (its 2026-07-06 comment), the SSH stream stalls, and the boundary question keeps getting answered by default at each enrolment event.

The chosen design is the only option that satisfies F1, F4, F5, F6, F8, F9 simultaneously; it buys F7 and F2-scope over A for one small mechanism, and concedes only F2-time — knowingly, bounded, with the reversal triggers recorded.

## Prior art

- This repo's own lineage is the strongest precedent: #517 moved host trust from TOFU to declared pinning; #524 moved outbound keys to per-host generation with single-sourced authorisation; this note is the same move applied to the trust *topology*. ADR-010 §History carries both.
- SSH-CA-on-NixOS exists as a community pattern (jamesog.net's 2023 walkthrough and gist using `TrustedUserCAKeys`) but no widely-referenced multi-host fleet config runs one — thinness that is itself evidence about operating cost at small scale.
- Tailscale's own KB is the authority for what Tailscale SSH is (tailscaled-terminated, ACL-authorised, Linux + open-source-macOS servers) — see De-risk evidence for the specific pages.
- smallstep's step-ca is the standard self-hosted issuance daemon should the CA trigger ever fire; packaging verified against the pin above.

## Unresolved questions

- **The edge set itself** — the strawman in Design (operator workstations → everywhere; metis → mercury + neptune; mercury and nixos-vm → nothing) is for review, not decided. In particular: does mercury need *any* outbound fleet key at its recovery enrolment, and does metis→neptune reflect a real flow?
- **Where the edge data lives** (`lib/operator.nix` growing a `sshEdges` attr vs a sibling `lib/` file) — implementation detail, decided at build time.
- **Stance and probe wording** — lands with the implementation commit and, for the runtime rung, with #551.
- **#524 reconciliation mechanics** — on acceptance, #524 re-scopes to "complete enrolment under the declared-edge shape" rather than closing; its runbook §Fleet SSH enrolment gains the edge step.
- Out of scope here: tailnet ACL content (#556), the full work/personal boundary (#570 — this note settles only its SSH-edge slice), neptune's key untangling (#526), and any change to inbound sshd posture (already stanced).

## Future possibilities

Recorded as migration triggers so #562 can eventually watch them; each names the condition under which today's decision should be reopened rather than quietly eroded:

- ⚠ **Fleet scale:** sshd-running hosts ≥ 8, or a second operator identity appears → re-run the CA weighing; F8's ceremony cost inverts with scale and multi-party issuance.
- ⚠ **Unattended delegation:** an automation flow needs *expiring, scoped* credentials a static key cannot express (cross-host agents, deploy pushers surviving the #552/#419 decision) → B's online-issuance variant (step-ca is pinned and packaged) becomes the subject of its own note.
- ⚠ **Hardware attestation:** #557 lands TPM sealing and a key-custody story that makes host-bound short-lived credentials meaningful → revisit with #526's frame.
- ⚠ **Tailscale SSH preconditions all true:** #556 has ACLs in git with drift detection; the Macs move to the open-source tailscaled (or mac inbound is explicitly conceded to sshd); control-plane-down behaviour empirically verified acceptable → C becomes weighable on F1/F6/F4 rather than failing them by default.
- The edge map is the natural substrate for #561's read surface ("who may reach whom") and for a future #551 probe family (per-edge acceptance/refusal proofs).
