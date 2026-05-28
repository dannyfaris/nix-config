# ADR-022: Host install via `nixos-anywhere` + `disko`

**Date**: 2026-05-25
**Status**: Accepted
**Supersedes**: ADR-017
**Amends**: ADR-018 (host SSH key acquisition order only)

## Context

ADR-017 chose the official NixOS AMI path for Mercury and explicitly rejected `nixos-anywhere` + `disko` on three grounds: bus-factor simplicity, the AMI being well-maintained on AWS, and `disko` not earning its keep on a standardised cloud platform.

Two things have shifted since:

1. **The bootstrap target changed.** Mercury is an in-place conversion of an existing Ubuntu Server 26.04 LTS EC2 instance (x86_64, Nitro, t3.medium), not a fresh AMI launch. The AMI path doesn't apply because we're not starting from an AMI; terminating the Ubuntu instance and relaunching would lose the instance entirely. `nixos-anywhere` is purpose-built for in-place conversion. The official `nixos-anywhere` CI suite gained an Ubuntu kexec integration test on x86_64 in release 1.11 (June 2025, nix-community/nixos-anywhere#537), so this is the well-tested path.

2. **A bare-metal sibling host (Metis) joined the runway.** Its bootstrap requires ~50 lines of manual `parted`/`mkfs`/`btrfs subvolume create` shell, a two-pass install (stock NixOS first, then flake), post-boot host-key harvest with a sops chicken-and-egg pre-flight, and a fragile "replace ONLY the kernel-modules blocks" merge against the committed `hardware.nix`. `nixos-anywhere` + `disko` collapses this dramatically; the runbook rewrite will quantify.

ADR-017's bus-factor argument was the load-bearing reason to defer `nixos-anywhere`. That argument is now weaker: Metis cannot use the AMI path at all (bare metal), so the operator already has to learn `nixos-anywhere` for at least one host. Learning two install paths is worse than learning one — bus-factor improves when both hosts share a mechanism. Writing a new runbook is bus-factor work either way.

A concrete blocker noted under ADR-017 — the `amazon-image.nix` module's `fileSystems."/"` colliding with `disko`'s declarative layout — was resolved upstream in nixpkgs PR #377406 (merged 2026-02-01, present in 25.05 and 25.11). The amazon-image module now declares its filesystem options with `lib.mkDefault`, so `disko`'s definitions win without `lib.mkForce` ceremony. Older tutorials that recommend `lib.mkForce` overrides are now actively harmful — they trigger eval-time regressions per the 25.05 release notes.

## Decision

Adopt `nixos-anywhere` as the install mechanism for `headless` hosts on both AWS and bare metal. Adopt `disko` for declarative disk layout.

- **Mercury**: convert the existing Ubuntu EC2 instance in-place via `nixos-anywhere`. `disko` defines a simple ESP + ext4 root layout on the single EBS volume (`/dev/nvme0n1` on Nitro). `amazon-image.nix` is imported normally — no `lib.mkForce` overrides — for its EBS-aware kernel modules (`ena`, `nvme`), kernel params (`nvme_core.io_timeout=4294967295`), `boot.growPartition = true`, and cloud-init / EC2 metadata integration.
- **Metis**: boot Metis from a Linux live USB; run `nixos-anywhere` from the operator's machine against it. `disko` defines the GPT + 2 GiB ESP + btrfs layout with three flat subvolumes (`@root` / `@home` / `@nix`; the `@` prefix avoids the `mktemp -d` collision documented in disko#442).
- **Host SSH keys are pre-generated** on the operator's machine and injected via `nixos-anywhere --extra-files`. The corresponding age recipient is added to `.sops.yaml` and `secrets/secrets.yaml` is re-encrypted *before* install begins, eliminating the post-boot harvest step from ADR-018's runbook.

ADR-017 is superseded. ADR-018's core decision (sops-nix, per-host age recipients, SSH-host-key-derived identity) is unchanged; only the key-acquisition order is amended.

## Rationale

The bare-metal-vs-cloud distinction that motivated different bootstrap paths under ADR-017 dissolves under `nixos-anywhere`. Both targets converge on one install command from the operator's machine — same mental model, same tooling, same recovery posture.

`disko`'s value is asymmetric across the two hosts. On Metis it pays off heavily: the btrfs subvolume layout is non-trivial to configure imperatively, and the previous design had structural drift risk between the Phase 3 partitioning shell and the runtime `fileSystems` block. On Mercury, `disko` is near-trivial (single EBS, single root partition). The asymmetry is fine — uniformity of tooling outweighs marginal complexity on the simpler host.

Pre-injecting the host SSH key eliminates the rotation race that ADR-018's original runbook tries to catch with a `sops -d` pre-flight: if cloud-init regenerates the host key between harvest and first switch, `dbf` ends up with an empty `hashedPasswordFile` and sudo breaks. With pre-injection, there is no window in which the key can rotate. The pattern (`mktemp -d` for the private key, `--extra-files` for injection, `trap … EXIT` for disposal) is the canonical workflow in nixos-anywhere's official secrets how-to.

The amazon-image module is kept (rather than replaced with hand-rolled imports of its useful bits) because, post-#377406, the collision concern is gone and the module's contributions are substantial:

- `boot.initrd.availableKernelModules` includes `nvme` (essential for EBS visibility in stage-1).
- `boot.extraModulePackages = [ ena ]` for the AWS enhanced-networking driver.
- `boot.kernelParams` includes `nvme_core.io_timeout=4294967295` — ~136-year I/O timeout. AWS documents that the default ~30 s timeout causes EBS hiccups to surface as I/O errors.
- `boot.growPartition = true` so the root partition fills the EBS volume.
- `ec2-data.nix` and `amazon-init.nix` for cloud-init / EC2 metadata service integration.

Re-implementing these by hand would be substantial work with easy-to-miss subtleties (the NVMe timeout in particular is non-obvious). Keeping the module is the right call today. Migration trigger if this changes: amazon-image starts re-asserting filesystem definitions at non-mkDefault priority, or a future AWS host has storage requirements that amazon-image actively fights (e.g. EBS encryption-at-rest setups disko handles natively). Until then, keep importing it.

`nixos-anywhere` + `disko` also generalises better than ADR-017's AWS-specific decision. Future hosts on Hetzner, DigitalOcean, or another bare-metal location use the same install command. No per-provider ADR is needed unless something fundamental shifts.

## Consequences

- ✓ Single install mechanism across AWS and bare metal. Both runbooks collapse dramatically (Metis particularly so — its current eight-phase runbook becomes a single install command). Both hosts share one shape.
- ✓ Disk layout becomes declarative code. Structural drift between partitioning and runtime mounts is no longer possible.
- ✓ The sops chicken-and-egg disappears. Mercury and Metis secrets are ready before the host exists.
- ✓ Generalises to non-AWS providers. ADR-017's AWS-only scope is removed.
- ✗ Two new flake inputs (`nixos-anywhere`, `disko`). Both are well-maintained nix-community projects (nixos-anywhere 1.13.0, released 2025-11-13), but new surface area in a deliberately minimal flake.
- ✗ `disko` makes disk layout part of the flake. Running `nixos-anywhere` against an already-running host wipes it. Mitigation: `nixos-anywhere` is bootstrap-only; daily operation continues via `nh os switch`, which doesn't touch the disk.
- ✗ Pre-generating host SSH keys creates a new operator-side secret. The private key briefly exists on the operator's machine before injection. Mitigation: keep it in `mktemp -d -p /dev/shm` (in-memory tmpfs on Linux) — or plain `mktemp -d` on macOS, where it's disk-backed but unlinked on cleanup — with `trap … EXIT` for guaranteed cleanup. Documented in nixos-anywhere's secrets how-to.
- ✗ Subvolume-naming gotcha: btrfs subvolumes mounted at paths matching their names can collide with disko's internal `mktemp -d` during install (disko#442). Use the `@` prefix (`@root` / `@home` / `@nix`). Easy to apply once known, easy to forget when copying the runbook.
- ⚠ Migration trigger: if `nixos-anywhere` or `disko` becomes unmaintained, or if a host class emerges where neither fits cleanly (e.g. an embedded device with no kexec capability), re-evaluate.

## Implementation

New flake inputs: `nixos-anywhere` and `disko`, both from `nix-community`. Each host gets a `hosts/<name>/disko.nix` imported from its `default.nix`. On AWS hosts the amazon-image module continues to be imported via `(modulesPath + "/virtualisation/amazon-image.nix")`; **no `lib.mkForce` overrides on filesystem options** (per nixpkgs #377406, these would now trigger eval-time regressions).

Per-host file layout follows ADR-023's three-file convention (`default.nix`, `disko.nix`, `hardware-configuration.nix`).

Pre-injection workflow (operator-side, executed once per new host):

1. `mktemp -d -p /dev/shm` for an in-memory scratch directory on Linux (plain `mktemp -d` on macOS); `install -d -m 755 "$tmp/etc/ssh"`.
2. `ssh-keygen -t ed25519 -N "" -f "$tmp/etc/ssh/ssh_host_ed25519_key"` to generate the host key locally.
3. `ssh-to-age < "$tmp/etc/ssh/ssh_host_ed25519_key.pub"` to derive the age recipient.
4. Add the recipient to `.sops.yaml`, `sops updatekeys secrets/secrets.yaml`, commit, push.
5. Run the install:

   ```
   nixos-anywhere \
     --flake .#<host> \
     --target-host <user>@<ip> \
     --extra-files "$tmp" \
     --generate-hardware-config nixos-generate-config \
                                hosts/<host>/hardware-configuration.nix
   ```

   `--generate-hardware-config` takes two positional arguments: the backend tool (`nixos-generate-config` or `nixos-facter`), then the output path on the operator's filesystem.

6. `trap … EXIT` cleans up `$tmp` regardless of how the command exits.

The `--generate-hardware-config` flag runs `nixos-generate-config --show-hardware-config --no-filesystems` on the target after kexec and writes the result locally to the specified path. The `--no-filesystems` ensures the output coexists with `disko.nix` without filesystem-definition conflict. The resulting file is committed verbatim per ADR-023.

The two prior host-specific bootstrap runbooks have been consolidated into a single `docs/runbooks/headless-bootstrap.md` with AWS-specific and bare-metal-specific preludes, since the install step is identical across both. The original host-specific runbooks are preserved in git history.

A `justfile` recipe (`just bootstrap <host>`) wrapping the workflow above is planned as follow-up implementation work. A pre-commit hook lint for `hardware-configuration.nix` integrity is similarly planned. Both are operational improvements, not architectural decisions; this ADR captures the *why*, the runbook the *how*, and the recipe the *ergonomics*.
