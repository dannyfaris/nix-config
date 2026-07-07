# UTM

Type-2 virtualisation platform — runs Linux / Windows / other-OS
VMs on macOS via Apple Virtualization.framework or QEMU
(host-side via JIT). Picked because it's the host for the
[`nixos-vm`](../../hosts/nixos-vm) fleet member — the
aarch64-Linux refinement target referenced in
[`CLAUDE.md`](../../CLAUDE.md)'s fleet list. Without UTM, there's
no way to drive the nixos-vm host on this Mac.

## Selection

Darwin: `pkgs.utm` via
[`modules/darwin/utm.nix`](../../modules/darwin/utm.nix),
imported by `hosts/neptune/default.nix`. ADR-031's §Boundary
rule **nixpkgs-by-default baseline** applies — neither clause-2
nor clause-3 carve-outs are justified (see Rationale).

This is the **second Darwin runtime to land via nixpkgs** rather
than via the cask path, after [colima.md](./colima.md). The
shape parallels colima's: standalone module, single
`environment.systemPackages` line, no Homebrew involvement.

## Rationale

**MAS rejected — clause-3 disqualifier.** Apple's App Store has
"UTM SE: Retro PC emulator" by Turing Software (ID 1564628856).
The load-bearing problem is that **the MAS sandbox prohibits
the JIT (dynamic-code-execution) entitlement** that
hardware-accelerated VM performance needs. The MAS variant
exists, the binary loads, but it falls back to TCG software
emulation — community reviewers call it the "slow edition" with
reason. Same disqualifier shape as the conversational Miro
decision (MAS variant exists but is materially degraded versus
the direct-download Mac app) — clause-3 is rejected for
materially-degraded MAS variants regardless of whether the
degradation is sandboxing, iPad-on-Mac shimming, or some other
Apple-imposed constraint.

**Cask rejected — no clause-2 carve-out justification.**
Homebrew's `utm` cask points at the same `UTM.dmg` from
`utmapp/UTM`'s GitHub releases — and UTM **has no auto-updater
of its own** (verified against the upstream cask source, which
notably does NOT set `auto_updates true`; no Sparkle, no
Keystone, no in-app updater). The named-degradation pattern
that justifies clause-2 carve-outs for our other Mac apps
(1Password's MDM template paths; Chrome's Keystone neutered by
`--simulate-outdated-no-au`; Typora / Obsidian / Cursor /
ChatGPT each silently breaking their respective vendor updaters
against the immutable nix-store path) **does not apply to UTM**.
There's no updater to break.

Per ADR-031's clause-2 specificity bar — *"Don't like the
nix-managed location alone does not qualify for clause 2."* —
the only argument remaining for cask over nixpkgs (UTM.app
lives at `/Applications/Nix Apps/UTM.app` via nix-darwin's
system-applications mechanism rather than `/Applications/UTM.app`
directly) is explicitly named in the ADR as insufficient for a
clause-2 carve-out.

**nixpkgs path actively favoured by CLI-first usage.** The
operator's primary UTM workflow is CLI-driven via `utmctl`
(scripted VM lifecycle: start, stop, status, snapshot). The
nixpkgs derivation's `installPhase` does
`makeWrapper $bin "$out/bin/$(basename $bin)"` for every binary
in `UTM.app/Contents/MacOS/*` — so `utmctl` lands declaratively
on PATH alongside the UTM GUI launcher. **The cask does not do
this**: cask installs `UTM.app` to `/Applications/` and leaves
`utmctl` buried at `/Applications/UTM.app/Contents/MacOS/utmctl`,
reachable only via that absolute path or an operator-side
alias. For a CLI-first workflow, nixpkgs is strictly better.

## Alternatives considered

**MAS (`UTM SE`)** — iPad-on-Mac compatibility-layer, no JIT,
materially degraded. Rejected at ADR-031 Step 0 / clause-3
disqualifier.

**Homebrew cask `utm`** — viable mechanism; carved out on the
grounds that (1) UTM has no auto-updater so the clause-2 named-
degradation pattern doesn't apply, and (2) `utmctl` doesn't land
on PATH automatically, which costs the operator's CLI-first
workflow. Available as a fallback if any unforeseen nix-shape
issue surfaces.

**`pkgs.qemu` directly** — different scope. QEMU is the engine
UTM wraps. The operator wants UTM specifically for its VM
management surface (config files, snapshots, UI when needed),
not raw QEMU. Out.

**VirtualBox / VMware / Parallels** — proprietary alternatives,
license-cost-bearing, no compelling reason to swap. Out.

## Configuration

**Module declaration** — `modules/darwin/utm.nix`:

```nix
environment.systemPackages = [ pkgs.utm ];
```

That's the whole module. The host imports
`../../modules/darwin/utm.nix` from `hosts/neptune/default.nix`.

The nixpkgs derivation handles the rest:
- `UTM.app` lands at `/Applications/Nix Apps/UTM.app` via
  nix-darwin's system-applications symlinking
- `$out/bin/UTM` and `$out/bin/utmctl` (plus any other helper
  binaries shipped inside the .app bundle) land on PATH via
  the makeWrapper loop in the derivation's installPhase

## Workflow

**GUI usage:** Spotlight / Launchpad find UTM.app at
`/Applications/Nix Apps/UTM.app`. Cmd-Space → "UTM" → launch.
First launch may surface a macOS Gatekeeper prompt for the
unsigned-by-Apple binary (UTM is signed by its developer but
not notarised through Apple's enterprise channel) — approve
once.

**CLI usage** (the load-bearing path for this operator):

```bash
utmctl list                          # list configured VMs
utmctl status <vm-name>
utmctl start <vm-name>               # boot the VM
utmctl stop <vm-name>                # graceful shutdown
utmctl ip-address <vm-name>          # the VM's guest IP
utmctl snapshot list <vm-name>       # list snapshots
utmctl snapshot save <vm-name> <tag> # create a snapshot
utmctl snapshot restore <vm-name> <tag>
```

For the `nixos-vm` host's typical lifecycle:

```bash
utmctl start "NixOS VM"              # start the VM
utmctl stop "NixOS VM"               # when done
```

Fleet SSH into the VM ended with ADR-042's edge narrowing (nixos-vm is a keyless sink, retiring); the entry points are the UTM console window for a shell in the guest and `utmctl` for lifecycle control.

(The VM's display name in UTM is whatever the operator named it
during creation — check `utmctl list` for the exact string.)

## Update behaviour

**nixpkgs flake bumps.** UTM ships via nixpkgs; updates land on
`nix flake update` + `nh darwin switch`. No Sparkle, no in-app
updater, no MAS — operator-cadence either way (the cask path
would have been brew-cadence via `brew upgrade --cask utm`).
Same posture as colima.

## Sharp edges

**UTM.app lives at `/Applications/Nix Apps/UTM.app`, not at
`/Applications/UTM.app`.** nix-darwin's system-applications
mechanism symlinks nixpkgs-installed `.app`s into the `Nix Apps`
subdirectory under `/Applications/`. Spotlight / Launchpad /
Cmd-Tab all find it correctly. Dock-pinning works but may
occasionally hiccup when the nix store path changes across an
update — flag, not blocker. If this becomes a real annoyance,
the cask path is a one-line module flip to recover the
canonical `/Applications/UTM.app` location.

**Gatekeeper prompt on first launch.** UTM is signed by its
developer (Turing Software) but Apple's notarisation status for
GitHub-released builds has historically varied. macOS may
surface a "cannot verify" prompt the first time UTM.app is
launched from the nix-store path; one-time accept-and-proceed.

**JIT entitlement.** UTM's hardware-accelerated VM mode requires
the host process to have JIT entitlements. The nixpkgs build
inherits the upstream signing's entitlements; if a future
nixpkgs revision strips them, VMs fall back to TCG (software
emulation), which is materially slower. The diagnostic is
"VM boots but at 1/10 normal speed"; the upstream entitlement
file is `Configuration/UTM.entitlements` in the UTM repo.

**Migration candidate to cask.** If anything in the nixpkgs
shape misbehaves operationally (Dock instability, GUI launch
issues, JIT entitlement regressions, etc.), flipping to the
`utm` cask is a one-line change: replace the `pkgs.utm` line
in `modules/darwin/utm.nix` with a `homebrew.casks = [ "utm" ];`
entry in `modules/darwin/homebrew.nix`. The cask path doesn't
add `utmctl` to PATH automatically, so a manual shell alias
(`alias utmctl=/Applications/UTM.app/Contents/MacOS/utmctl`)
would need to land alongside.

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) —
  §Boundary rule nixpkgs-by-default baseline; no clause fires
  for UTM (clause-3 disqualifier for MAS variant; no clause-2
  named degradation against nixpkgs).
- [`colima.md`](./colima.md) — sibling Darwin nixpkgs install
  (same shape: standalone module, environment.systemPackages,
  no cask).
- UTM upstream — https://github.com/utmapp/UTM
- `utmctl` reference — https://docs.getutm.app/scripting/scripting/
- [`hosts/nixos-vm/`](../../hosts/nixos-vm) — the load-bearing
  VM workload this Mac runs UTM for.
