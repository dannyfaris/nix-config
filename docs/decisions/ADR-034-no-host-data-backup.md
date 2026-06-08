# ADR-034: No host-data backup — recovery is reprovision-from-source

**Date**: 2026-06-08
**Status**: Accepted

> Records a deliberate *non*-adoption: this repo does not back up live-host user data, and does not intend to at current data volumes. Recovery from host loss is reprovision-from-flake plus the homes durable data already has (git remotes, 1Password, cloud sync, the off-band sops identity). Closes the open question #197 raised — "am I actually backed up?" — by writing the answer down rather than leaving it assumed.

## Context

`modules/nixos/btrfs-scrub.nix` guards metis against silent bit-rot, but that is *integrity*, not *backup* — it detects/repairs corruption of data that's present, and does nothing for disk loss, host loss, or accidental deletion. A grep of the tree confirms there is **no** backup mechanism of any kind: no restic / borg / btrbk, no snapper or btrfs snapshots, no Time Machine declaration.

Of the four hosts, only two hold user data that isn't trivially reproducible:

| Host | Storage | User data | Reproducible? |
|------|---------|-----------|---------------|
| **metis** | btrfs (`@root`/`@home`/`@nix`), no LUKS | `/home` | system yes (flake); `/home` no |
| **mac-mini** | APFS (Darwin) | user home | system yes (flake); home no |
| **mercury** | ext4 on EBS (AWS EC2) | work-only, headless | yes — EBS is AWS-replicated/snapshot-able; reprovisible |
| **nixos-vm** | ext4 (UTM) | refinement target | yes — disposable by design |

So the live question is narrow: what happens to **metis `/home`** and **mac-mini's home** if the disk or host is lost?

## Decision

**Backup of live-host data is deliberately out of scope.** The repo adopts no backup tooling and no snapshot mechanism. Recovery from host loss rests on two things already true:

1. **Every host is reproducible from the flake** — reprovision via `nixos-anywhere` (ADR-022) on Linux or the Darwin bootstrap on mac-mini, and the system returns bit-for-bit.
2. **Durable data already has homes off the host** — source and config live in git remotes; secrets and credentials in 1Password; documents in cloud sync (iCloud/Drive/Dropbox); and the sops *decryption identity* is itself backed up out-of-band ([ADR-018](./ADR-018-headless-secrets-sops.md), #279), so the encrypted blob stays recoverable even if every host and the Mac are lost.

The one thing this does **not** cover is uncommitted work-in-progress and scratch in metis `/home` and mac-mini's home that hasn't yet been pushed or synced. Per the #197 triage that data is "a little" — annoying to lose, not damaging — and the loss is **accepted**, mitigated by the habit of committing/pushing and letting cloud sync run, not by infrastructure.

mercury is explicitly out of scope: it is reprovisible, its volume sits on AWS-managed EBS, and its work artifacts live in remotes.

## Rationale

A real backup system is not one setting — it is a tool choice, an off-host target, encryption and key management, a schedule, cross-platform coverage (mac-mini is Darwin, so a Linux-only module wouldn't reach it), and — the part that makes it real — a *tested restore drill*, since an unverified backup is not a backup. That is a standing maintenance surface with its own failure modes.

Weighed against "a little WIP," it doesn't earn its keep. The two protection shapes each cover only half the threat and neither is justified at this volume: local snapshots (cheap on metis' btrfs) guard accidental deletion but not disk loss; off-host backup guards disk loss but is the heavier build. With essentially nothing irreplaceable living only on these disks, the proportionate answer is to write down the recovery story and stop — consistent with [ADR-032](./ADR-032-proportionate-enforcement-and-rationale.md) (lightest mechanism that holds the guarantee; the guarantee here is small).

This is a recorded decision, not a permanent verdict — see the migration trigger below.

## Consequences

- ✓ Zero backup infrastructure to build, secure, schedule, or maintain; no new root of trust beyond the existing sops/1Password story.
- ✓ The recovery model is explicit and discoverable instead of an unstated assumption — which was #197's actual ask.
- ✗ Uncommitted WIP / un-synced scratch on metis and mac-mini is lost on disk failure or accidental deletion. Accepted; mitigated by commit/push + cloud-sync habits, not tooling.
- ✗ No point-in-time rollback for accidental deletion, even though metis' btrfs subvolumes would make snapshots low-friction. Accepted under the same proportionality reasoning.
- ⚠ **Migration trigger — irreplaceable local-only data accumulates.** If a workflow starts producing data that lives only on a host and would genuinely hurt to lose (large media, datasets, a local-only database, a research corpus), revisit. The likely shape then: btrbk/snapper snapshots on metis for quick rollback **plus** restic to an off-host/cloud target for disaster recovery, keyed off the existing sops/age or 1Password trust rather than a new one, with Time Machine (or the same restic) covering mac-mini — and a tested restore drill as the acceptance bar.

Cross-reference: [btrfs-scrub.nix](../../modules/nixos/btrfs-scrub.nix) (integrity, the gap this answers); [ADR-018](./ADR-018-headless-secrets-sops.md) + #279 (the sops identity — the one "survives host loss" item that *is* backed up out-of-band); [ADR-022](./ADR-022-headless-bootstrap-nixos-anywhere.md) (the reprovision path recovery leans on); [ADR-032](./ADR-032-proportionate-enforcement-and-rationale.md) (proportionality).
