# ADR-038: Celestial host-naming framework — gravitational binding mirrors operational dependency

**Date**: 2026-06-23
**Status**: Accepted, Implementation pending

> Replaces the ad-hoc host names ADR-016 grandfathered (`mercury`, a planet; `metis`, a Jovian moon; `mac-mini`, a descriptor; `nixos-vm`, a role) with a single evergreen framework drawn from celestial bodies, where a host's *substrate* — owned metal, rented metal, or a guest VM — picks its celestial class (planet, moon, or a minor body from the open reserve). Amends [ADR-016](./ADR-016-host-identity.md): its stable-per-physical-machine identity rule stands unchanged; this ADR only supplies the naming *source* ADR-016 left ad-hoc, and consciously overturns ADR-016's one blanket clause forbidding in-place directory renames so a one-time themed re-key (via `git mv`, which preserves the history that clause protected) can land. Ratified in [#368](https://github.com/dannyfaris/nix-config/issues/368); rolled out per-host in staged subtasks, the first being [#403](https://github.com/dannyfaris/nix-config/issues/403) (`mac-mini` → `neptune`).

## Context

ADR-016 fixed *when* a host name changes (stable per physical machine; a hardware swap is a new host, a software-role change is not) but deliberately left the name *source* ad-hoc — it grandfathered a mix of descriptive and themed names and recorded, as a migration trigger in its Consequences, that "adopting a structured theme (with the current hosts re-keyed at the same time) is reasonable" once the fleet outgrew memorable ad-hoc names. The fleet has reached that point: six hosts named off four unrelated rungs (a planet, a Jovian moon, a form-factor descriptor, a role string), with no system tying them together, and two new machines (a flagship NixOS tower and a MacBook Air) about to be onboarded. The operator wants a single, principled, evergreen naming framework and the current hosts re-keyed to match — exactly ADR-016's anticipated trigger.

Host names are not load-bearing — they drive no config (no `hostName ==` conditionals; eval-bearing references are the directory name and a handful of keys that move in lockstep with it). A name attaches to a *configuration* — one `hosts/<name>/` directory, one `nixosConfigurations`/`darwinConfigurations` entry, with one singular identity (hostName, the SSH host key that derives its sops recipient, its tailnet registration, its palette entry). Two coexisting hosts are therefore always two configurations with two names; the framework names configurations, not running processes, and the directory model already prevents name clashes. The framework is chosen for human legibility and durability, not machine behaviour.

## Decision

Adopt **celestial bodies** as the host-naming theme, with one principle underneath it: **gravitational binding mirrors operational dependency.** What a machine *is* — owned metal, rented metal, or a guest VM — decides its celestial class. Substrate is a durable property of the machine (not its software role), so keying the class on substrate stays consistent with ADR-016's stability rule.

| Substrate | Celestial class | Why it fits |
|-----------|-----------------|-------------|
| Physical machine (metal you own) | major planet, **moon-capable** | A full world that owns its own gravity — an independent host with dependents; the VMs you pin to it orbit it as moons. |
| VPS / cloud instance (someone else's metal) | major planet, **moonless** | A real standalone host, but on rented metal — barren, nothing of yours orbiting it. Mercury/Venus being airless-hostile is a fitting bonus. |
| VM pinned to an owned host | a **moon** of that host's planet | A moon is bound to exactly one planet — the strongest gravitational tie in the scheme — mirroring a pinned VM's total dependence on its host metal. |
| Roaming VM, or any host that fits no class above | a **minor body** — asteroid &c., the open reserve | Bound to no single planet; a deliberately loose catch-all (see Rationale). |

Whether a planet carries moons is itself the owned-vs-rented marker: your own metal can anchor pinned VMs — each of which *is* one of its moons, taking the name of one of that host-planet's actual moons — while rented metal stays barren by choice. A moon is therefore not a phantom signal naming nothing; it is the VM. **Earth is excluded** from the name pool by operator preference.

The **minor-body reserve** (asteroids, and the rest of the celestial menagerie — comets, dwarf planets, Kuiper-belt objects) is held as a single, deliberately under-specified catch-all for roaming VMs and any host pulled in that fits no class above. It is *not* pre-partitioned into sub-categories: if a reserve category proves to recur often enough to deserve its own rule, this ADR is iterated (a new class is slotted in) at that point — doing more now would be unjustified.

**Per-host selection** (ratified in #368):

| Current | New | Class | Machine |
|---------|-----|-------|---------|
| (new tower) | **Jupiter** | moon-capable planet | NixOS x86_64 flagship desktop |
| (new MacBook Air) | **Saturn** | moon-capable planet | darwin daily driver |
| `metis` | **Mars** | moon-capable planet | NixOS x86_64 work + personal dev (ProDesk) |
| `mac-mini` | **Neptune** | moon-capable planet | darwin home Mac |
| `mercury` | **Mercury** | moonless planet | AWS EC2 x86_64 work, headless |
| `nixos-vm` | *(minor-body reserve — no name minted)* | minor body (reserve) | UTM/aarch64 refinement VM on a non-host Mac; retiring |

`nixos-vm` runs in UTM on a **non-host Mac** (a personal machine not configured in this repo), so it is gravitationally bound to no fleet planet — it types to the minor-body reserve, not a moon. An earlier revision assigned it **Triton** on the false premise that it ran on the Mac mini (→ Neptune); corrected per #448. No reserve name is minted: the host is retiring, and the reserve deliberately names things only on need.

**Relationship to ADR-016.** This ADR *amends*, not supersedes, ADR-016:

- **Kept, unchanged:** a host name is a property of the physical machine, not its current job; identity is stable per machine; a hardware swap is a new host, a role change is no rename. ADR-038 only fills the naming *source* ADR-016 left open, realising the migration trigger in ADR-016's own Consequences.
- **Overturned, consciously:** ADR-016's Implementation clause "existing directories are never renamed in place." That clause existed to protect a host directory's git-tracked history (rebuild log, `hardware-configuration.nix` evolution, generation history) from being severed by a rename. `git mv` preserves that history intact, so the clause's protected interest survives the re-key. The blanket "never" is therefore lifted **for this one-time themed re-key only**; it is *not* a standing licence to rename hosts on a whim. Ongoing, ADR-016's rule holds: a stable name, set once, that doesn't chase software changes.

## Rationale

How we landed here, including the roads not taken.

**Why a theme at all, now.** ADR-016 named the trigger (ad-hoc names stop scaling; adopt a structured theme and re-key) and judged it unmet at three hosts. At six-going-on-eight, off four unrelated naming rungs, it is met. A celestial theme is evergreen (the bodies don't go out of date), has a built-in hierarchy to encode meaning against, and lets the strongest existing name — `mercury` — survive the reframing rather than being discarded.

**Why substrate is the class axis.** The one thing that durably distinguishes these machines operationally is what metal they run on and who owns it: owned hardware you can touch, rented hardware in a provider's account (a VPS, or an IaaS instance like Mercury's EC2 — the ownership axis is what matters, not the exact rental tier), or a guest VM running on top of one of those. That maps cleanly onto a gravitational hierarchy, and — being a machine-identity property rather than a role — it sits inside ADR-016's stability guarantee instead of fighting it.

**Why a pinned VM is a moon, not an asteroid.** An earlier draft made *every* VM an asteroid, on the grounds that a UTM image roams across Apple Silicon Macs and a moon-name would falsely assert a single parent. But in practice a fleet VM is a configuration with a singular identity (one host key, one sops recipient, one tailnet name) pinned to one host. For that pinned case the moon is the *purest* expression of the framework's thesis: the strongest gravitational tie mirrors the strongest operational dependency, and an asteroid ("bound to no one") would be a small lie about a VM that depends totally on its host. Multiple VMs pinned to one host take distinct moons of that planet — a clean per-host sub-namespace. The portability worry is real but narrow, and is handled by applying ADR-016's own principle one level down: ADR-016 keys "different host" on a *physical*-machine change, and this ADR extends that to a moon's parent — a VM that genuinely relocates to another host is treated as a *new* host (new name), just as ADR-016 treats a hardware swap — so a moon name never goes stale, it is retired and reborn.

**Why a genuinely roaming VM (and the rest) goes to the reserve, not its own planet-bound class.** A VM that truly belongs to no single host can't honestly be a moon, and isn't a standalone planet either. The minor-body reserve — asteroids and the wider menagerie — is host-independent by nature, so it types those cleanly, and is kept as one loose pool rather than carved into speculative sub-classes. This is the deliberate-non-adoption move: name the catch-all, don't over-define it; let real recurrence, not anticipation, justify any future sub-rule (and that rule lands by iterating this ADR).

**Why a VPS is a moonless planet, not a minor body.** A VPS is a real, always-on, standalone host — a planet — just on metal that isn't yours. The minor-body reserve is for things that aren't full standalone hosts (roaming guests, oddities); demoting a VPS there would mistype it. Moonlessness is the right marker for "standalone host, rented metal, nothing of yours orbiting it," and it keeps the `mercury` name.

## Consequences

- ✓ One evergreen rule covers the whole fleet; a new host's name follows from a single question — what does it run on, and do you own that metal?
- ✓ The moon model makes the core principle exact: the strongest gravitational tie (moon→planet) names the strongest operational dependency (pinned VM→host), and the unbound minor bodies name the things with no fixed host. The thesis isn't decoration — it picks every class.
- ✓ A moon name *encodes* which host its VM runs on; multiple VMs pinned to one host take distinct moons of that planet, a per-host sub-namespace that cannot clash.
- ✓ `git mv` preserves each renamed directory's full history, so the re-key costs none of the audit trail ADR-016's never-rename clause was protecting.
- ✓ The framework absorbs the two incoming machines (Jupiter, Saturn) without a fresh naming debate, and keeps the strongest existing name (`mercury`).
- ✗ A one-time fleet-wide churn: directory renames plus a live-reference sweep across docs and code, and per-host operator cutover (macOS system names, tailnet registration) that can't be done from another host.
- ✗ Per-planet moon budgets are uneven — Jupiter and Saturn have dozens of named moons, Neptune more than a dozen, **Mars exactly two** (Phobos, Deimos), and a moonless VPS zero. A host that needed to pin many VMs *and* mapped to a moon-poor planet would strain the namespace. Accepted: usage is one-or-few pinned VMs per host; a genuinely roaming VM falls to the reserve anyway.
- ⚠ The minor-body reserve is deliberately under-specified (one loose pool, no pre-assigned sub-categories). Trigger: a reserve category that recurs often enough to deserve its own rule — formalise it then by iterating this ADR (a new class, or a successor if the theme stops paying for itself), not before.
- ⚠ **VPS hosts cap at two.** Only Mercury and Venus are moonless among the major planets; a third VPS would have to bend the rule. Acceptable for a personal fleet, noted as a deliberate ceiling, not a surprise. Moon-capable planets and the minor-body reserve both scale freely.

## Implementation

Doc-before-code, then a staged per-host rollout — each rename is its own peer-reviewed PR citing this ADR, so the framework lands once and the churn arrives one host at a time:

1. **This ADR** + the host-naming section in [taxonomy.md](../taxonomy.md#host-naming-celestial-bodies) (the applied rule + per-host table) + ADR-016's status → `Amended by ADR-038`. (This first slice is documentation-only; the directory renames are deferred to their own passes below, so `hosts/mac-mini` et al. stay live until then.)
2. **`mac-mini` → `neptune`** ([#403](https://github.com/dannyfaris/nix-config/issues/403), the pilot — a single darwin box, the only purely-descriptive current name, lower-stakes than the active Linux dev box): `git mv hosts/mac-mini hosts/neptune`; the eval-bearing keys that must move in lockstep or `nix flake check` throws — `parts/darwin.nix` host key, `parts/checks.nix` (`host-mac-mini` + `stances-mac-mini`, incl. the label arg), `lib/host-palettes.nix` key (keyed by `hostName`; `modules/nixos/stylix-palette.nix` throws on a missing key), `hostName`/`hostContext.hostName` in the host file; plus `networking.computerName = "Neptune"` + `localHostName = "neptune"` (the genuinely-unset macOS facets). Live-reference sweep; historical mentions in implemented ADRs / PRD / `flake.nix` are annotated, not rewritten (ADR-037 — an implemented ADR is frozen record). Operator-run cutover on the Mac: `darwin-rebuild switch --flake .#neptune`, then `tailscale up --hostname=neptune` (the tailnet name is sticky from registration).
3. **Remaining hosts** — `metis` → Mars and the two new machines (Jupiter, Saturn) land as they are touched, on the same pattern; `nixos-vm`'s rename is mooted (reserve-typed per #448, and the host is retiring).

Cross-reference: [ADR-016](./ADR-016-host-identity.md) (host identity — amended here), [ADR-037](./ADR-037-doc-mutability-contracts.md) (why frozen ADR mentions are annotated, not rewritten, and why a reserve category formalises by iterating this ADR), [taxonomy.md](../taxonomy.md) (the applied naming rule); issues [#368](https://github.com/dannyfaris/nix-config/issues/368) (framework ratification), [#403](https://github.com/dannyfaris/nix-config/issues/403) (the pilot rename).
