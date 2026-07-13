# Fleet key custody — one key, one role, one lifecycle

**Status:** Proposed — design note (`docs/design/`). Not built. #526 (the identity-architecture hub its own comments recognize — comment 3, "the hub of the fleet's key-custody architecture"; supersedes its bench sequence with a moved-context revision); consumes ADR-042; imposes a constraint on #557; upstream of #563, #566, #572; adjacent #387, ADR-009, ADR-010, ADR-034. Drafted 2026-07-07; custody calls settled at review 2026-07-13. Expect an ADR on acceptance.

## Summary

Neptune's `~/.ssh/id_ed25519` holds three unrelated roles in one passphrase-less file — fleet SSH identity, GitHub push auth as `dannyfaris`, and (via `ssh-to-age`) the sops recovery root that `.sops.yaml` literally tells you to back up. This note freezes the custody model that untangles it: **machine-decryption identities are host-key-derived and reproducible-from-source** (one per NixOS host that actually holds a secret), and **one standalone operator age key is the durable edit-and-recovery root**, vault-held with a second offline copy. It supersedes the issue's on-the-bench rotation sequence, which was drawn for a fleet now being reshaped: mercury and nixos-vm retire (their recipients drop), saturn and neptune decrypt nothing (no darwin host identity is needed — the bench's "flip neptune to a host-key path" step dissolves), and ADR-042 already holds the slot for neptune's re-homed SSH key. Two invariants fall out: any operator-key rotation must refresh vault + offline + #572 escrow atomically, and #557 must seal the disk rather than TPM-bind the host key or it silently breaks every host's decryption.

## Motivation

#524's adversarial review surfaced (runtime-verified, 2026-07-03) that one file does three jobs. The consequences compound: a leak of that key is simultaneously fleet SSH access, supply-chain push rights into every host, and fleet-secrets decryption; and because it is the *only* host-independent member of the sops recipient set, losing it together with the hosts leaves secrets unrecoverable. The two-tier shape that fixes this — host-derived machine keys + a standalone operator key — is standard sops-nix practice and operator-endorsed; this note does not relitigate it. What it re-does is the *plan*, because the fleet moved under it.

The objective, stated as the principle it enforces: **each key does one job and carries one lifecycle**, and the fleet's secrets have a durable recovery root that depends on no single host and survives the disaster recovery exists for.

What has moved since the bench sequence was written, each changing a step:

- **ADR-042 landed.** neptune's fleet SSH role is now `hostKeys.neptune` in `lib/operator.nix` (still the old triple-role key, per ADR-010 §History) — so re-homing the SSH role is a `hostKeys` swap into a slot the edge model already defines, not a change to a flat list.
- **mercury and nixos-vm are retiring** (operator, 2026-07-07). Both are current `.sops.yaml` recipients. The recipient set is being rewritten anyway; dropping the two retiring hosts is decommission hygiene folded into this rotation, not extra work.
- **Darwin decrypts no secrets.** `modules/darwin/sops.nix` declares no `secrets.*`; the only secret (`dbf-password`) is NixOS-only. So neptune has no machine-decryption role to separate out — the `dbf@mac` key's only live jobs are *operator editing* and *recovery root*. The bench's step 4 ("flip neptune to a host-key path") solves a problem that does not exist, and the darwin module's own rationale ("the Mac doesn't need a separate host identity") was written when the operator key *was* the SSH key — the untangling inverts that logic without needing a host identity at all.
- **ADR-042 declined the CA (reconciling #558).** One leg of the shared identity frame (#526 comment 1: "a CA key raises the same custody question") no longer exists — ADR-042 keeps static keys, so there is no CA key to custody. The hub shrinks by one.
- **#387 added an AI-account custody leg** and reaffirmed #572's escrow dependence on whatever lands here.

Forces any custody model must satisfy:

1. **F1 — One key, one role.** No credential carries a second unrelated capability; the triple-role key is the anti-pattern this exists to end.
2. **F2 — A host-independent durable root.** The recovery identity must not be any host's key; losing every host must not lose the secrets.
3. **F3 — Recovery survives its own disaster (#566).** The root must be reachable when the fleet is network-dark and rebuilt from zero — not only when a cached session happens to be warm.
4. **F4 — Machine identities reproducible from source (ADR-034).** A host's decryption identity should come back with the host on reprovision, needing no separate backup — the reprovision-from-source stance applied to keys.
5. **F5 — Rotation is atomic across copies (#572).** Rotating the operator key must refresh vault, offline copy, and escrow together, or recovery/succession silently splits.
6. **F6 — Composes with the fleet's other identity decisions.** It must not fork ADR-042 (SSH edges) or collide with #557 (disk encryption); cross-issue invariants live here, the hub.
7. **F7 — No custody ritual that won't be performed.** Single operator; the proportionality force that killed #570 and deferred #568 — a rotation dance too heavy to actually do is worse than a simpler one honestly followed.

## Design

**Three key classes, three lifecycles.**

1. **Machine-decryption identities — host-key-derived, reproducible-from-source.** Each NixOS host that holds a secret decrypts via its `/etc/ssh/ssh_host_ed25519_key` through `ssh-to-age` (`sops.age.sshKeyPaths`, already the NixOS pattern). One per such host — metis today; jupiter/M720q/Pi as they land *and if they hold a secret*. Lifecycle: born with the host, dies with it, recovered by reprovisioning it (F4). **Darwin hosts get no machine identity** — they decrypt nothing; if a darwin secret is ever declared, neptune needs a real decryption identity and the host-key-vs-operator-key question reopens (migration trigger, below).
2. **Operator identity — the standalone edit + recovery root.** A fresh `age-keygen` key with no SSH ancestry, listed as a recipient on every secret. It is what the operator uses to run `sops`/`sops updatekeys` from a daily-driver Mac (via `~/.config/sops/age/keys.txt`, repopulated from the vault — *not* derived from any SSH key), and it is the disaster-recovery root. Custody: 1Password as primary, **plus a second offline copy** (F3). Lifecycle: long-lived; rotated only on suspected compromise, and rotation is atomic across all copies (F5).
3. **Re-homed roles (leaving the retiring triple-role key).** Fleet SSH → a fresh `dbf@neptune` key in `hostKeys.neptune` (passphrase-less per the #524 carve-out; ADR-042 defines the slot). GitHub → deregister the old key (git is HTTPS+token, ADR-009, so its registration is vestigial; a dedicated key only if SSH-git is ever genuinely wanted). The old `id_ed25519` retires once all three roles are re-homed.

**The recipient set collapses, it does not grow.** Today: `nixos-vm, mercury, metis, mac` (where `mac` = the id_ed25519-derived triple-role key). Target: `metis` (+ future NixOS secret-holders) + `operator` (the standalone key). nixos-vm and mercury drop (retiring); `mac` becomes `operator` (standalone, severed from SSH/GitHub); neptune and saturn are *not* recipients (no darwin secrets — they *use* the operator key to edit, they don't hold a host identity; today's `mac` was already the operator recipient, not a neptune host key, so nothing host-shaped is being dropped for them). The bench's "every host incl. neptune gets a host key + the operator key" over-counted; the moved fleet is smaller and cleaner.

**Revised rotation sequence** (order preserves decryptability — the old key must decrypt until re-encryption completes):

1. `age-keygen` the standalone operator key → 1Password + the offline copy + (if #572 is live) the escrow, all three at once (F5).
2. Add the new operator recipient to `.sops.yaml` *alongside* the existing `mac`; `sops updatekeys`. [old key still decrypts]
3. Repopulate `~/.config/sops/age/keys.txt` on neptune from the standalone key (not `id_ed25519`); runtime-verify `sops -d secrets/secrets.yaml` on neptune (set ≠ enforced; saturn is not yet stood up — it bootstraps straight onto the new model, its check landing with step 7's runbook rewrite). [darwin change is *repopulate*, not flip-to-host-key]
4. Fresh `dbf@neptune` fleet SSH key → swap `hostKeys.neptune`; re-switch destinations per the ADR-042 edges; verify fleet SSH.
5. Deregister the old key from GitHub; verify `gh` flows unaffected.
6. Pre-flight — `age-keygen -y ~/.config/sops/age/keys.txt` on neptune must print the *operator* pubkey (guards against the not-yet-rewritten recovery comment luring a keys.txt re-derivation back to the old key between steps 3 and 6). Then drop the old `mac` recipient *and* the retiring `nixos-vm` + `mercury` recipients from `.sops.yaml`; `sops updatekeys`; retire the old key file. The drop is administrative removal, not cryptographic revocation — `updatekeys` re-wraps but never rotates the data key, so a dropped private key plus any pre-drop git revision recovers the data key — and with it current and any future values until that key rotates; accepted (operator, 2026-07-13) as consistent with the untangling-not-compromise threat model. The suspected-compromise escalation is rotating the secret *values* together with `sops rotate`, so the replacements get a fresh data key — git history retains old ciphertext regardless. (Operator-confirmed 2026-07-13: neither retiring host rebuilds again before decommission. A post-drop rebuild would fail activation — `dbf-password` is `neededForUsers`.)
7. Reconcile the living references in the same change: `.sops.yaml`'s recovery comment (rewrite — no longer "back up `id_ed25519`"), `modules/darwin/sops.nix`'s now-inverted rationale comment, `docs/desktop/1password.md`, `docs/runbooks/darwin-bootstrap.md` (picks up saturn's step-3 `sops -d` check), `lib/operator.nix`'s `hostKeys.neptune` comment (still records the GitHub + sops roles the untangling removes), ADR-010 §History, and record the #557 disk-seal-not-key-bind invariant where #557 will see it.

**Two invariants this hub imposes on its neighbours:**

- **On #557 (verified from pinned sops-nix source):** the host-key machine tier reads `/etc/ssh/ssh_host_ed25519_key` as a plain file (`importAgeSSHKeys` → `os.ReadFile`). #557 may seal the *disk* (LUKS + TPM-sealed passphrase; the key is a normal file once booted — composes fine) but must **not** TPM-*bind* the host key (key never on disk — breaks derivation on every host, silently). If TPM-bound keys are ever wanted, this tier migrates to an `age-plugin-tpm` identity (`sops.age.plugins`; not in the current pin) — a deliberate, separate decision, not a side effect of #557.
- **On #572/#566:** the operator key is the escrowed artifact (#572) and the sole surviving credential at network-dark recovery (#566). Both make F5 (atomic rotation) and the offline copy (F3) non-optional — a rotation that updates the vault but not the escrow leaves #572 decrypting nothing; a vault-only root can't be reached in #566's from-zero scenario.

How the design meets the forces: F1 (three single-role classes; the triple-role key retired), F2 (the standalone operator key is host-independent by construction), F3 (the offline copy closes the network-dark gap the de-risk found), F4 (host keys reproduce on reprovision; no machine-key backup needed), F5 (atomic-rotation invariant, guarded by #569's heartbeat on the escrow), F6 (consumes ADR-042's slot, imposes the #557 invariant, retires #558's dead CA leg), F7 (the sequence is seven steps done once; the standing ritual is just "rotate all three copies together," rare).

## De-risk evidence

Verified this session (pinned source, the repo, official docs):

- **The entanglement is exactly as claimed** — `.sops.yaml`'s `mac` recipient and its recovery note ("back up `~/.ssh/id_ed25519`") are the same key `hostKeys.neptune`/`dbf@neptune` uses and that ADR-010 §History records as GitHub-registered + the sops source. Three roles, one passphrase-less file, confirmed from the committed files.
- **Darwin decrypts nothing** — `modules/darwin/sops.nix` declares no `secrets.*`; `dbf-password` (the only secret) is NixOS-only with `neededForUsers`. So the "flip neptune to a host-key path" step is unnecessary, and the module's host-identity rationale is inverted by the untangling. Verified from the module source.
- **#557 interaction (the load-bearing one)** — sops-nix rev on the pin derives host age keys via `os.ReadFile` on the SSH host key (no TPM/PKCS#11 path in `importAgeSSHKeys`). Therefore #557-as-disk-seal is orthogonal; #557-as-key-bind breaks the tier. The #558 design note frames #557 as disk-at-rest sealing (alongside FileVault), so the *likely* intent composes — but the invariant must be recorded so a naive #557 can't silently break sops.
- **darwin timing is moot** — the bench flagged "can darwin read the host key at sops activation?"; since darwin needs no host identity under this design, the question does not arise. (Were it ever needed: on a running neptune the host key exists and would work; only cold-bootstrap ordering is a risk. Verified feature-equivalence of the darwin/NixOS derivation path from upstream source.)

Unverified / needs on-host check, stated rather than implied:

- **1Password offline reach (#566)** — official docs indicate 1Password 8 unlocks offline on a *previously-synced, cached-session* device, but a new device or expired session needs a server round-trip. So the durable root is reachable for a running fleet but **not guaranteed in #566's from-zero network-dark rebuild** — the gap the offline-copy decision closes. The exact session-expiry edge needs an on-box check; the architectural gap does not.
- **The offline-copy medium** (paper age key, hardware token, cold storage) is deferred to implementation, below.
- Step 3's darwin `sops -d` verification and step 5's `gh`-flow check are on-host confirmations at implementation, not pre-verifiable here.

## Drawbacks

- **The standalone operator key on-disk on the Macs is a mild re-entanglement.** `keys.txt` holds the recovery root on neptune and saturn (for editing), so a stolen unlocked Mac leaks it. FileVault (both Macs) bounds theft-at-rest, and the key is severed from SSH/GitHub so the blast radius is "fleet secrets" not "fleet secrets + push + SSH" — a strict improvement over today, but not zero. The alternative (operator key vault-only, fetched per edit) trades this for per-edit friction (F7); the on-disk-under-FileVault choice is the status quo, kept deliberately.
- **The offline copy is a new artifact to keep current** — and F5 makes it a rotation obligation. A stale offline copy is a false safety net, worse than none if trusted. #569's heartbeat guarding the escrow helps for #572 but does not watch a paper copy in a drawer; that discipline is unmonitored by construction.
- **This note supersedes an operator-endorsed sequence.** The bench sequence was reviewed and blessed; overriding step 4 and the recipient set on a moved-context re-read risks discarding a rationale the operator held that I have not seen. Flagged for exactly that check — if darwin *is* meant to grow secrets soon, the host-identity step returns.
- **Custody models invite gold-plating.** Hardware tokens, per-secret keys, split-knowledge escrow all beckon; F7 says stop at the lightest model that holds F1–F6. This note's three classes are that line; the drawback is the pull to cross it.

## Cost

The standing price: rotating the operator key is now a three-place atomic update (vault + offline + escrow), a deliberate ceremony rather than a one-liner — accepted because the key rotates rarely (identity rotation, not secret rotation) and because the alternative is silent recovery/succession failure. Machine keys cost nothing extra (reproduced on reprovision). The offline copy is one artifact's lifecycle to maintain.

## Rationale & alternatives

- **A0 — keep the triple-role key.** Fails F1/F2 outright; the surfaced supply-chain-plus-recovery entanglement stands. Rejected — this is the problem.
- **A1 — the bench sequence as written** (flip neptune to a host-key path; every host incl. neptune a recipient). Correct in shape but drawn for the old fleet: it builds a darwin host identity for a host that decrypts nothing, keeps the retiring hosts as recipients, and carries the darwin-timing risk it flagged. Superseded, not reversed — same two-tier destination, a plan that matches the current fleet.
- **A2 — vault-only operator key (no offline copy).** Simpler custody, satisfies F1/F2, but fails F3 in #566's from-zero network-dark case (the de-risk finding). Viable *if* the operator scopes network-dark-from-zero recovery to #566 and accepts the 1Password-session dependency otherwise — a legitimate call, declined at review (below).
- **A3 — this model (host-derived machine keys + standalone operator key, vault + offline).** The only option satisfying F1–F7 together, at the cost of the on-disk-Macs drawback and the offline-copy obligation. Doing nothing keeps A0's live entanglement.

## Prior art

- **In-repo:** #524's review is the surfacing; ADR-010 §History records the triple-role fact; ADR-042 defines the SSH slot the re-homing fills; ADR-009 makes the GitHub role vestigial; ADR-034's reprovision-from-source is the principle F4 applies to keys. The community-config survey (§3.1) noted the committed-host-pubkey ↔ sops alignment this builds on.
- **Ecosystem:** two-tier sops-nix (per-host machine keys + an admin age key) is the standard documented pattern; `age-plugin-tpm` is the known escape hatch if TPM-held age keys are ever wanted. The "recovery root must have an offline copy" lesson is ordinary key-management practice — a networked-only root is a known anti-pattern for disaster recovery.

## Unresolved questions

Settled at review (operator, 2026-07-13):

- **The offline copy (F3 vs F7): required.** The operator key gets a second offline copy alongside the vault; A2 (vault-only, scoping the network-dark case to #566) was declined.
- **The #557 invariant: imposed.** "Seal the disk, don't TPM-bind the host key" is recorded as the constraint on #557; `age-plugin-tpm` stays the documented escape hatch, a deliberate future migration rather than a #557 side effect.
- **Step 6's folded-in recipient drop: confirmed** — the retiring hosts do not rebuild again before decommission (the step-6 clause).

Still open:

- **The offline-copy medium** — paper vs hardware vs cold storage; deferred to implementation.
- Out of scope, named not decided: #563's fleet signing key (another standalone key on this model — vault + offline + escrow — deferred to its own note); the AI-account custody leg (#387 — same *template*, but recovery codes are not age keys, so a sibling custody item, not a sops recipient); #572's escrow *procedure* (this note fixes the artifact it escrows and the atomic-rotation invariant, not the succession runbook); #557's own mechanism.

## Future possibilities

- **#563's signing key** slots in as a third standalone key under the same custody model, once peer-substitution trust is designed.
- **#566 consumes this directly** — the operator key (with its offline copy) is the sole surviving credential its recovery path assumes; this note's F3 decision is #566's foundation.
- **#572 escrows this** — the operator key plus a procedure, sealed for a successor; the atomic-rotation invariant (F5) and #569's heartbeat are what keep that escrow from silently going stale.
- **A custody stance, ADR-042-shaped:** once the model lands, an eval check that `.sops.yaml`'s recipient set equals {live NixOS secret-holders} ∪ {operator} — a retired host left as a recipient, or a host key that should not decrypt, fails CI. The set ≠ enforced closure for the recipient set.
- **If a darwin secret is ever declared,** neptune (and saturn) acquire a real machine-decryption need and the host-key-vs-operator-key question this note closed for the no-secret case reopens — a migration trigger, phrased for #562.
