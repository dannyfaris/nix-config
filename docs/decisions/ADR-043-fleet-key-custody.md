# ADR-043: Fleet key custody — one key, one role, one lifecycle

**Date**: 2026-07-13
**Status**: Accepted, Implemented (#526)

> Every fleet credential does **one job** and carries **one lifecycle**. Machine sops decryption rides **host-key-derived age identities** — one per NixOS host that holds a secret, reproduced with the host on reprovision; Darwin hosts hold none (they declare no secrets). The edit + disaster-recovery root is **one standalone operator age key** with no SSH ancestry, vault-held (1Password item "sops age key - operator") plus an offline copy. SSH and git-hosting auth live on their own rails (per-host keys per ADR-042/ADR-010; HTTPS+token per ADR-009). Neptune's triple-role `id_ed25519` — fleet SSH + GitHub push + sops recovery root in one passphrase-less file — is retired and extinguished. The *why* lives in the design note [`docs/design/fleet-key-custody.md`](../design/fleet-key-custody.md); this ADR freezes the decision. The rotation itself is recorded in [ADR-010](./ADR-010-ssh.md) §History (2026-07-13).

## Context

#524's adversarial review surfaced (runtime-verified, 2026-07-03) that one passphrase-less file did three unrelated jobs: fleet SSH identity, GitHub push auth into every host's config, and — via `ssh-to-age` — the sops recovery root that `.sops.yaml` told the operator to back up. A leak was all three capabilities at once, and as the recipient set's only host-independent member, losing it together with the hosts left the fleet's secrets unrecoverable. The design note re-drew #526's original rotation plan against the moved fleet: mercury and nixos-vm retiring (their recipients drop), Darwin decrypting nothing (the planned neptune host-identity flip dissolves), and ADR-042 already holding the slot for neptune's re-homed SSH key.

## Decision

- **Three key classes, three lifecycles.** (1) *Machine decryption*: host-key-derived age identities (`sops.age.sshKeyPaths` over `/etc/ssh/ssh_host_ed25519_key`), one per NixOS secret-holder — metis today; born with the host, dies with it, reproduced by reprovisioning (no backup of its own). (2) *Operator identity*: a standalone `age-keygen` key, no SSH ancestry — a recipient on every secret, the edit + disaster-recovery root; lives at `~/.config/sops/age/keys.txt` on the operator's Macs, populated from the vault and never derived from an SSH key. (3) *Role keys*: fleet SSH stays on per-host keys (ADR-042); git-hosting auth stays HTTPS+token (ADR-009) — no SSH key is registered with GitHub.
- **The recipient set is exactly {live NixOS secret-holders} ∪ {operator}** — `{metis, operator}` today. A host that holds no secret is not a recipient; a retired or retiring host's recipient drops.
- **Operator-key rotation is atomic across copies**: vault + offline copy (+ any future escrow) refresh in the same sitting, or recovery/succession silently splits.

## Rationale

Single-sourced in the design note (Rationale & alternatives; step 6's recorded acceptance); the decisive findings only: Darwin hosts declare no sops secrets, so there is no Darwin machine identity to custody — the operator key's on-disk presence on the Macs is for *editing*, bounded by FileVault. A vault-only root fails from-zero network-dark recovery (1Password requires a server round-trip on a new or session-expired device — the offline copy closes that gap). And recipient removal is administrative, not cryptographic revocation: `sops updatekeys` re-wraps but never rotates the data key, so a dropped key plus git history still reads values until the data key rotates — acceptable for an untangling, with value rotation + `sops rotate` as the compromise-case escalation.

## Consequences

- ✓ A leaked credential is now one capability, never three; each key's blast radius matches its job.
- ✓ The recovery root survives total fleet loss and depends on no host; the vault restore was exercised live (2026-07-13) before the old root was extinguished.
- ✓ Machine identities cost nothing to keep: no backup, no rotation ceremony — reprovision-from-source (ADR-034) applied to keys.
- ✗ `keys.txt` on the operator's Macs is a mild re-entanglement — a stolen unlocked Mac leaks the fleet-secrets root. Bounded by FileVault; accepted against the alternative of per-edit vault fetches.
- ✗ The offline copy is an unmonitored artifact — a stale copy is a false safety net; the atomic-rotation rule is the only guard.
- ✗ Dropped recipients retain access to the historical data key via public git history. Accepted (untangling, not compromise response); the escalation is rotating the secret *values* together with `sops rotate`.
- ⚠ Constraint on #557: seal the *disk* (LUKS + TPM-sealed passphrase composes), never TPM-bind the SSH host key — the machine tier reads it as a plain file (verified from the pinned sops-nix source); TPM-held age identities would be a deliberate migration to `age-plugin-tpm`, not a #557 side effect.
- ⚠ Migration trigger: a Darwin host declares a sops secret → it then needs a real machine-decryption identity, and the host-key-vs-operator-key question this closed for the no-secret case reopens.
- ⚠ Migration trigger: new standalone credentials (#563's signing key, #387's AI-account custody leg) join *this* custody model — vault + offline + escrow, atomic rotation — rather than growing parallel custody stories.
- ⚠ Future stance, when warranted per ADR-032: an eval check that `.sops.yaml`'s recipient set equals {live NixOS secret-holders} ∪ {operator} — the set ≠ enforced closure for the recipient set.

## Implementation

Executed 2026-07-13 as #526's revised rotation — design note #581 (custody calls settled in it; the step-6 non-revocation acceptance + pre-flight guard recorded in #589), recipient add #588, SSH re-home #590, drop + reconcile #591 — with runtime verification at every step: operator key decrypts alone; metis accepts the new `dbf@neptune` key and refuses the retired one; metis's re-wrapped stanza decrypts at activation; the rewritten darwin-bootstrap gate check proven in a fresh-Mac environment; the vault restore exercised on a live incident. The old key's three roles ended in order (SSH re-homed, GitHub deregistered, recipients dropped) and the key file was deleted. Living references reconciled in #591: `.sops.yaml`'s recovery comment, `modules/darwin/sops.nix`, `docs/desktop/1password.md`, both bootstrap runbooks, the justfile, ADR-010 §History.
