# Ephemeral-root recovery

Operational procedure for recovering state from archived roots on hosts running the ephemeral-root mechanism (`modules/nixos/ephemeral-root.nix`, [design note](../design/ephemeral-root.md), #553). At every boot the previous `@root` is renamed into a timestamped `roots-archive/` entry and a fresh empty `@root` is created; archives are purged after `ephemeralRoot.retentionDays` (default 30). This runbook is the retention force's other half: the archive is only a safety net if the recovery path is written down.

The workflows are translated from mature adjacent ecosystems (snapper/openSUSE, ZFS boot environments, btrfs-native promotion — [recovery-workflows research](../research/ephemeral-root-recovery-workflows.md)), not invented; the promote sequence is additionally VM-verified by the ephemeral-root test (`nix build .#ephemeral-root-vm`, assertion h).

**The clock:** every recovery below has a deadline. Archives older than `retentionDays` are purged; a loss noticed on day N+1 is unrecoverable. The retention window is sized together with `nix.gc --delete-older-than` (design note §Cost) — both windows matter to §Promote.

## First, identify the failure — most are not archive recoveries

- **The OS broke after a config or package change** → boot an older NixOS generation at the systemd-boot menu. `/nix` is a separate persistent subvolume this mechanism never touches; generation rollback works exactly as on any NixOS host. The archive is not involved.
- **A file on `/` is gone after a reboot** → it was not on the persist whitelist. It is in the newest archive → §Extract, then declare it in `environment.persistence` in its owning module so it stops happening. This is the expected dominant recovery.
- **The host booted but the wipe did not run** → §Degraded boot.
- **Root-wide state loss where file-picking is impractical** → §Promote, the last resort.
- **Auth or secret lockout after a persist change (login rejected on *every* generation)** → a whitelisted *directory* was bind-mounted over live state before its `@persist` backing was stocked, or a secret-bearing path diverged between `@root` and `@persist` — and generation rollback will **not** help, because every generation re-derives `/etc/shadow` from the same effective path at boot. Identify which copy the early-boot reader actually resolves (pre-bind reads hit the *underlying* `@root` path), fix *that* copy, and reconcile the other (the 2026-07-30 incident, #553 comments). SSH host keys and `/etc/machine-id` are no longer bind-mounted at all — they live physically on `/persist` (sshd's configured key paths; the initrd machine-id copy) — so for those two, `/persist` is always the canonical copy and writes to `@root:/etc/ssh` are read by nothing.

## The layout

The btrfs top level (subvolid 5) is not mounted in the running system; browse, extract, and promote all mount it transiently. Under it: `@root` (the live root, mounted with `subvol=@root`), `@persist`, and `roots-archive/` holding one complete previous root per boot, named by UTC ISO-8601 basic timestamp (e.g. `20260726T041500Z`; a `.<pid>` suffix on same-second collisions). `<device>` below is the host's `ephemeralRoot.device` value.

## Browse — inspect an archive

```bash
mkdir -p /mnt/btrfs-top
mount -t btrfs -o subvolid=5,ro <device> /mnt/btrfs-top
ls /mnt/btrfs-top/roots-archive/
# inspect roots-archive/<stamp>/... — each entry is a full previous root
umount /mnt/btrfs-top
```

Read-only is deliberate for pure inspection; drop `ro` only when moving to extraction.

## Extract — recover files (the normal case)

Reflink-copy from the archive into the live root **within the single top-level mount** — zero-cost (CoW-shared, no data copied) and immune to the cross-mount reflink limitation:

```bash
mount -t btrfs -o subvolid=5 <device> /mnt/btrfs-top
cp -a --reflink=always \
  /mnt/btrfs-top/roots-archive/<stamp>/var/lib/example \
  /mnt/btrfs-top/@root/var/lib/example
umount /mnt/btrfs-top
```

**Pick the target by whitelist status.** `/mnt/btrfs-top/@root` is the live root's subvolume, but impermanence *bind-mounts every whitelisted path from `@persist` over it* — so for a whitelisted path, writes into `@root` land *underneath* the bind mount and the running system never sees them. Extract into `@root/<path>` only for paths **not** on the persist whitelist (those appear at `/` immediately, no reboot); for a whitelisted path, extract into `@persist/<absolute-path>` (impermanence mirrors the absolute path under `/persist`), which the live bind mount surfaces immediately:

```bash
# whitelisted path — target @persist, not @root:
cp -a --reflink=always \
  /mnt/btrfs-top/roots-archive/<stamp>/var/lib/tailscale/tailscaled.state \
  /mnt/btrfs-top/@persist/var/lib/tailscale/tailscaled.state
```

Caveats, all load-bearing:

- **An extraction into `@root` without a whitelist declaration survives exactly one boot.** The next reboot archives it again. If the file should live, the same change adds its `environment.persistence` declaration in the owning module; extraction alone is a one-boot patch.
- **Review before restoring system files** (snapper's own warning, carried): machine-generated files (`/etc/machine-id` class if ever un-whitelisted, mount tables, anything a service regenerates) can conflict with the running system — restore data, not machinery, unless you know why.
- **Two mounts, same subvolume.** `/mnt/btrfs-top/@root` and `/` alias the same inodes through two mounts; write through one path at a time and don't edit the same file via both.
- **The target's parent directory must exist** (`mkdir -p` it first on a sparse root), and a `--reflink=always` failure is a *signal*, not an obstacle — it means source and target are not on the same filesystem (wrong mount, wrong device); stop and re-check rather than retrying without the flag.

## Promote — boot an archived root (last resort)

For root-wide loss where the archive is a better base than the current root. First choose the source archive via §Browse — every `<source-stamp>` below is that *chosen older archive*, distinct from the fresh timestamp minted in step 1 for the root being displaced. Two pre-checks, then a three-step sequence, then **one kill-switch boot** — promotion without the kill-switch boot is self-defeating (the next boot would immediately re-archive the promoted root).

**Pre-check 1 — what flattens.** Snapshotting is non-recursive: nested subvolumes inside the archive return as *empty directories* in the promoted copy. List them so this is a decision, not a surprise:

```bash
btrfs subvolume list -o /mnt/btrfs-top/roots-archive/<source-stamp>
```

On this fleet that is `/var/lib/machines` and `/var/lib/portables` — acceptable, systemd recreates them.

**Pre-check 2 — spot-check the closure.** The archived root symlinks into `/nix/store` paths of its generation; GC may have stripped them (the retention×GC coupling). A cheap negative check:

```bash
test -e "$(readlink -f /mnt/btrfs-top/roots-archive/<source-stamp>/etc/static)" \
  && echo etc-path-alive || echo closure-stripped
```

`closure-stripped` means a promoted root boots broken — fall back to §Extract for the data. But a green result is a *spot-check only*, not a guarantee: GC works at store-path granularity and this tests one path. The true closure test is the kill-switch boot itself; if the promoted root comes up broken, the displaced root is still in `roots-archive/` and re-promotable the same way.

**The sequence** (VM-verified online — renaming the mounted `@root` is legal; the running system continues on it by subvolume id until reboot):

```bash
mount -t btrfs -o subvolid=5 <device> /mnt/btrfs-top
# 1. Displace the current root INTO the archive, minting a NEW timestamp for
#    it, and refresh its mtime: a renamed subvolume keeps its old top-dir
#    mtime, and the purge selects on exactly that — without the touch, a
#    long-uptime root can age-test as already stale and be reaped at the
#    next daily purge instead of surviving the retention window.
DISPLACED="/mnt/btrfs-top/roots-archive/$(date -u +%Y%m%dT%H%M%SZ)"
mv /mnt/btrfs-top/@root "$DISPLACED"
touch "$DISPLACED"
# 2. Snapshot — never raw-mv — the CHOSEN archive into place: the copy
#    boots, the archive survives re-promotable.
btrfs subvolume snapshot /mnt/btrfs-top/roots-archive/<source-stamp> /mnt/btrfs-top/@root
umount /mnt/btrfs-top
```

**The kill-switch boot.** Reboot; at the systemd-boot menu press `e`, append `ephemeral.skip-rollback` to the kernel command line, boot. No rebuild, effective for this boot only. This boot consumes the promotion; the following reboot resumes normal wiping — so use it to extract what was actually needed and land the persist declarations.

**Banned: `btrfs subvolume set-default`.** Inert on this fleet — the explicit `subvol=@root` mount option always wins over the default-subvolume setting — with independent persistence and deletion traps besides (research §2). Promotion is by name, never by set-default.

## Degraded boot — the rollback bailed

Any rollback failure routes to "leave `@root` in place, boot on it": the host comes up on the *old, un-wiped* root and the initrd writes the reason to `/run/ephemeral-root-degraded`. The unit itself always exits 0 (structural fail-safe), so check the marker, not the unit state:

```bash
cat /run/ephemeral-root-degraded            # reason, present only on a degraded boot
journalctl -b -o cat | grep ephemeral-root  # the initrd service's log — grep the
                                            # whole boot journal; -u filtering of a
                                            # stage-1 unit across the switch-root
                                            # handoff is not the VM-verified form
```

A degraded boot is safe (nothing was destroyed) but means the wipe is not enforcing — treat the marker as a page, fix the cause, reboot. The probe (#633) reports this marker once built.

## Kill-switch reference

`ephemeral.skip-rollback` on the kernel command line skips the rollback for that single boot — checked before anything else in the initrd service. Edit at the systemd-boot menu (`e`), no rebuild, no persistent state. Uses: consuming a promotion (above), initrd debugging, buying a boot while deciding.
