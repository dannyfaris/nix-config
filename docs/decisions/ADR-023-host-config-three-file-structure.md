# ADR-023: Three-file host configuration structure

**Date**: 2026-05-25
**Status**: Accepted

## Context

Each `hosts/<name>/` directory currently contains two files: `default.nix` (logical configuration) and `hardware.nix`. The committed `hosts/metis/hardware.nix` interleaves three categories of content with sharply different ownership stories:

1. **Hardware-discoverable values** (`boot.initrd.availableKernelModules`, `boot.kernelModules`, Intel microcode). Only the running machine knows these; they come from `nixos-generate-config`.
2. **Disk layout** (`fileSystems."/..."` entries, `btrfsOpts` let-binding, `boot.supportedFilesystems`). Declarative, known up front.
3. **Logical settings** (`nixpkgs.hostPlatform`, `zramSwap.enable`, `swapDevices`). Decisions; nothing to do with hardware.

Because the file mixes auto-generated and hand-authored content, bootstrap requires a careful "replace ONLY the kernel-modules blocks, preserve everything else" surgical merge — a procedural workaround for a structural problem. Standard NixOS convention treats `hardware-configuration.nix` as untouchable auto-generated output; the current `hosts/metis/hardware.nix` quietly violates that expectation. ADR-022's adoption of `disko` creates a natural home for the disk-layout category (category 2 above), which makes the clean split possible.

The three-file split is a recognised convention in well-regarded multi-host NixOS flakes: Stapelberg's declarative-install config, Misterio77/nix-starter-configs, EmergentMind/nix-config ("Anatomy of a NixOS Config" reference), and wimpysworld/nix-config all use logically equivalent splits. Our convention picks the cleanest version of this pattern.

## Decision

Each `hosts/<name>/` directory installed via `nixos-anywhere` (ADR-022) contains exactly three files, each with a single ownership story:

- **`default.nix`** — hand-authored. Logical settings (`hostName`, `system.stateVersion`, `_module.args.hostContext`, role/platform module imports, host-specific `mkForce` / `mkDefault` overrides, ergonomic flags like `zramSwap.enable`).
- **`disko.nix`** — hand-authored. Declarative disk layout: partitions, filesystems, mount options, btrfs subvolumes. Read by `disko` at install time and by NixOS at runtime for `fileSystems` entries — single source of truth.
- **`hardware-configuration.nix`** — auto-generated. Kernel modules, microcode, `nixpkgs.hostPlatform`. Pre-bootstrap state: a stub containing only `nixpkgs.hostPlatform = lib.mkDefault "<arch>-linux"` so `nix flake check` evaluates before the host exists. Post-bootstrap state: replaced verbatim by `nixos-anywhere --generate-hardware-config nixos-generate-config` output (which uses `--no-filesystems`, so the output coexists with `disko.nix` without conflict). See [ADR-022 §Implementation](./ADR-022-headless-bootstrap-nixos-anywhere.md#implementation) for the operator command. Convention-protected by a top-of-file comment declaring it auto-generated (see Implementation below for the exact form).

The convention applies to hosts installed via `nixos-anywhere` (Mercury and Metis going forward, plus any future `headless` host). `nixos-vm` is legacy and remains unchanged.

## Rationale

Each file aligns with a single ownership story. `default.nix` is "decisions we made." `disko.nix` is "disk layout we want." `hardware-configuration.nix` is "what `nixos-generate-config` produced." No file mixes two stories, so no file needs surgical merging.

This eliminates the fragility flagged in the previous Metis runbook explicitly: there is no longer a "preserve these hand-authored blocks while replacing those auto-generated blocks" instruction, because the two kinds of content live in different files. Post-install, `hardware-configuration.nix` is overwritten atomically. The instruction reduces to "commit the new file as-is."

The split also restores standard NixOS convention. The community Discourse thread "How strict are you in not editing `hardware-configuration.nix`?" shows practitioners split between editing and not editing the file. Treating it as immutable (with hand-edits going in `default.nix` instead) is the cleaner posture for a multi-host fleet because re-running `nixos-anywhere --generate-hardware-config` will overwrite any edits silently.

Uniformity across hosts is a secondary win. Mercury's `disko.nix` will be ~15 lines and its `hardware-configuration.nix` will be near-empty; Metis's will be substantially larger. But the *shape* is identical, which makes "how is a host configured?" answerable in one sentence regardless of the host's specifics.

A specific subvolume-naming detail informs the convention: when using btrfs with disko, subvolumes should be prefixed with `@` (e.g. `@root`, `@home`, `@nix`) rather than named after their mountpoints. Disko's internal `mktemp -d` during install collides with literal mountpoint-style subvolume names (disko#442). The `@` prefix is the long-standing convention from Ubuntu's btrfs installer (openSUSE's Snapper setup uses a related but distinct layout, e.g. `@/.snapshots`) and avoids the collision entirely.

A second detail simplifies the mount-options list: since Linux 6.2, `discard=async` is automatically enabled by the kernel on capable devices, and `ssd` is auto-detected. NixOS 25.11 ships Linux 6.12, so both options are redundant in committed `mountOptions` lists. Keeping them in the file is harmless but noisy; dropping them keeps the file honest about what's hand-chosen versus kernel-default.

## Consequences

- ✓ Bootstrap-time hardware merge eliminated. `nixos-anywhere --generate-hardware-config` overwrites a stub; no surgical preservation of hand-authored blocks.
- ✓ Standard NixOS convention restored. `hardware-configuration.nix` is what it says it is.
- ✓ Uniform host shape. Adding a future host is "copy the three files from an existing host, edit each one."
- ✓ Snapshot tooling (Snapper, btrbk) becomes easier to add later. Editing `disko.nix` for a new subvolume is a normal file edit, not a "be careful, this file has hand-authored bits next to do-not-touch bits" operation.
- ✗ Three files per host instead of two. On hosts with trivial disk layout (Mercury) and a near-empty hardware probe, this can feel like more files than content justifies.
- ✗ The "do not hand-edit" rule on `hardware-configuration.nix` is enforced only by the top-of-file comment. A future contributor (or LLM) could edit it anyway. The convention is load-bearing but not yet tooling-enforced. A pre-commit hook that lints for the `nixos-generate-config` banner is the planned enforcement, but is out of scope for this ADR.
- ✗ `nixos-vm` does not follow the convention (it predates `disko` and was never installed via `nixos-anywhere`). One legacy exception in an otherwise uniform set.
- ⚠ Migration trigger: if a future host's `hardware-configuration.nix` and `disko.nix` are both genuinely trivial (e.g. ephemeral container, embedded device), the three-file convention may be overkill. Revisit if and when that arrives.

## Implementation

The split is applied as part of the ADR-022 migration:

- **Mercury**: rename existing `hardware.nix` → `hardware-configuration.nix` (no content change; the file is already a stub). Flip `nixpkgs.hostPlatform` from `"aarch64-linux"` to `"x86_64-linux"` (Mercury is now t3.medium / Nitro / x86_64, not Graviton). Add `hosts/mercury/disko.nix` describing the ESP + ext4 root on the EBS volume (`/dev/nvme0n1`). Import `disko.nix` from `default.nix`.
- **Metis**: split current mixed-content `hardware.nix` into three. Move `fileSystems`, `btrfsOpts`, and `boot.supportedFilesystems` into a new `hosts/metis/disko.nix`, using `@root` / `@home` / `@nix` subvolume names (per disko#442) and dropping `discard=async` and `ssd` from mount options (auto-applied by Linux 6.2+ on capable devices; NixOS 25.11 ships 6.12). Move `zramSwap.enable` and `swapDevices` into `default.nix`. Reduce `hardware-configuration.nix` to a stub containing only `nixpkgs.hostPlatform`. After Metis is reinstalled via `nixos-anywhere`, the stub is replaced by the real generated file.
- **`nixos-vm`**: unchanged. Existing two-file shape preserved as a legacy exception.

The top-of-file comment in each **pre-bootstrap stub** `hardware-configuration.nix` reads exactly:

```
# AUTO-GENERATED by nixos-anywhere --generate-hardware-config
# (which calls nixos-generate-config --show-hardware-config --no-filesystems
#  on the target during install).
#
# Do NOT hand-edit.
#   - Manual settings belong in default.nix.
#   - Filesystem layout belongs in disko.nix.
#
# Regenerate by re-running the bootstrap recipe.
```

**Post-install lifecycle**: after `nixos-anywhere --generate-hardware-config` runs, the file is overwritten in its entirety with `nixos-generate-config --show-hardware-config --no-filesystems` output. That output carries its own `# Do not modify this file!` banner, which is sufficient. **Do not re-add the stub form's comment block after install** — the generator's banner is the convention going forward; the stub form exists only so that `nix flake check` can evaluate a not-yet-installed host.
