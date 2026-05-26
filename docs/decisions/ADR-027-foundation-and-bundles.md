# ADR-027: Foundation and capability bundles (walk back the role taxonomy)

**Date**: 2026-05-27
**Status**: Accepted

> This ADR **supersedes [ADR-014](./ADR-014-independent-roles.md)** in full and **amends [ADR-013](./ADR-013-composition-framework.md)** by retracting its role-specific sub-claim while preserving its broader explicit-imports philosophy. The composition framework's rejection of auto-discovery, its whitelist stance, and its "explicit > implicit" posture all survive; only the *role layer* on top of that framework is walked back. [ADR-015](./ADR-015-tier-as-directory.md) (tier-as-directory) and [ADR-016](./ADR-016-host-identity.md) (host identity) are untouched.

## Context

ADRs 013 and 014 introduced a three-role taxonomy — `headless`, `linux-workstation`, `macos-workstation` — with **independent** (non-inherited) role composition. The PRD §3 was written around the same model.

Eight months and three hosts in, the data is sharper than the forecast:

- Only one role has been implemented: `headless`. All three hosts (nixos-vm, mercury, metis) adopt it.
- Of the nine modules `roles/headless.nix` imports, **zero are headless-specific**. Every entry (locale, nix-daemon, sshd, firewall, sops, users, system-packages, mosh, home-manager) is universal to every NixOS host the operator runs. The role name asserts a property — *absence of graphical environment* — that none of its contents actually depend on.
- The next planned divergence is Metis growing a desktop environment. Under the existing taxonomy this creates a category problem: Metis is no longer "headless" but is also not yet a "linux-workstation" by any clean definition. Either the role name becomes a lie on the tin, or Metis migrates to a `linux-workstation` role that re-imports the same nine modules under a different label.
- PRD §3.3 describes `linux-workstation` as "the full development environment of `headless` plus a GUI layer" — a layered/inherited relationship — directly contradicting ADR-014's independence stance. The architecture is at war with itself on this point.
- The forecast that justified the role abstraction (multiple instances per role, with role-shaped overlap as the cost-center to amortize) has not materialised. Two roles remain unbuilt; the one that exists carves no actual joint.

The role concept was *abstraction-by-forecast*. It paid interest immediately (categorisation overhead, the PRD/ADR contradiction, friction every time a host's purpose evolved) without delivering a payoff. The honest correction is to walk the abstraction back to what's actually doing work: shared modules, opted into by hosts according to what those hosts do.

## Decision

Adopt a **two-layer composition model** with a third allowance for ungrouped modules:

1. **Foundation** (`modules/core/<platform>/foundation.nix`, `home/core/<platform>/foundation.nix`) — the unconditional baseline. Identity, administrative essentials, and security posture. Every host of the platform imports it. Foundation is *not* a bundle; it's the irreducible floor.

2. **Capability bundles** (`modules/core/<platform>/bundles/<name>.nix`, `home/core/<platform>/bundles/<name>.nix`) — coherent named groupings of **2 or more** modules toward a functional capability the host has. Hosts opt in by importing the bundle. Bundle names describe *what is in them* (`cli-tooling`, `desktop-env`, `agent-clis-extras`, `container-runtime`, `remote-access`), never *what kind of host they're for*. Single-module "bundles" are forbidden — they're noise; the underlying module stays standalone until a sibling joins it.

3. **Standalone modules** — modules a host imports directly when no natural bundle home has emerged for them. They graduate to a bundle when a coherent capability category surfaces (rule-of-two-with-intent-to-grow). Standalone-ness is not a defect; it's the honest state for a capability that hasn't yet attracted siblings.

The `roles/` directory ceases to exist. `lib/mk-host.nix` retains its host-construction role (specialArgs, third-party flake-module imports, etc.); only its `role` argument is removed. Each host's `default.nix` explicitly imports its platform's `foundation.nix` plus the bundles and standalone modules it wants.

The split between "what's in foundation" and "what's a bundle" follows a principled test, not deduplication mechanics: **foundation holds identity + administration + posture (things a host needs to be one of dbf's hosts at all); bundles hold capabilities (things a host has)**. A bundle that happens to be imported by every current host is still a bundle — fleet uniformity is a snapshot property, not a downgrade.

## Rationale

**Bundles describe what is in them; roles described what hosts are for.** The role abstraction collapsed every distinguishing axis of a host (cloud vs bare-metal, work vs personal, dev vs service, headless vs graphical) into a single categorical label. Real hosts hit combinations the role didn't capture, and the label became a category lie under predictable evolution. Bundle names describe their contents and don't claim anything about the host that imports them. The same bundle (`cli-tooling`) can sit in a headless dev box, a workstation, and a future appliance host without changing meaning.

**Capability-grouping matches how the operator already conceptualises the config.** The home-module tree was already organised by capability (`shell.nix`, `prompt.nix`, `editor.nix`, `multiplexer.nix`, `agent-clis.nix`, `cli-utils.nix`). The role layer was bolting categorical labels on top of an existing functional organisation. Promoting capability-grouping to a first-class structural concept (bundles) honours what was already true.

**The Metis-with-desktop scenario becomes trivial.** Under the role model, Metis growing a desktop forced either a category lie (`headless` Metis with niri imports) or a role migration (move Metis to `linux-workstation` that mechanically re-imports the same baseline under a different label, per ADR-014). Under the bundle model, Metis was `{ foundation + cli-tooling + agent-clis-extras + container-runtime + tailscale-mesh + local-linux-platform }`; it becomes `{ ... + desktop-env + desktop-apps }`. Additive, no rename, no contradiction.

**Foundation must be honestly minimal.** Folding "every host imports it today" into foundation would re-create the same flattening that made `headless` a grab-bag. Foundation is reserved for things that *cannot be opt-out capabilities* — identity (users, sops), administration (nix-daemon, locale, baseline system packages), posture (firewall). Capabilities, even universal-today ones (remote access via sshd+mosh, cli tooling), live in bundles. This preserves the taxonomy as the fleet evolves: a future appliance host that doesn't need cli-tooling can simply not import that bundle, and the existing foundation+bundle structure makes that change trivial.

**Single-module bundles are forbidden.** Pre-wrapping a single module in a bundle file adds an indirection without a capability grouping to justify it — the same kind of forecast-driven abstraction the role layer was. A bundle earns its place when it aggregates 2+ modules toward a coherent named capability. Until then, the module stays standalone in `modules/core/<platform>/`. Promotion happens when a natural sibling appears.

**ADR-013's broader philosophy survives.** ADR-013's load-bearing claims — flake-parts as the organisational framework, explicit imports over auto-discovery, whitelist over blanket — are independent of the role taxonomy. Foundation and bundles use explicit imports throughout; nothing here re-introduces auto-discovery. The role-specific sub-claim ("each role file lists its modules") is what gets walked back; the explicit-composition philosophy stands. The amendment marker on ADR-013 says so directly.

**ADR-014 dissolves cleanly.** ADR-014's stance ("roles are independent, not inherited") was an answer to a question that no longer exists. Without a role layer there's nothing to inherit. The reasoning behind ADR-014 (avoid inheritance contracts, keep composition flat) survives in spirit: bundles are themselves non-inherited, and host import lists are flat.

**Profile/feature-flag systems were considered and rejected.** A `options.profiles.X.enable = true;` model (snowfallorg-style) would solve the same problem but reintroduce the very "applicability lives in the module" pattern ADR-013 correctly rejected. Bundles keep applicability in the *importing* file (the host), which is exactly where the user looks first when asking "what is this host doing?".

## Consequences

- ✓ Bundle names are honest by construction. A bundle cannot become a category lie because it isn't making a category claim about the host.
- ✓ Hosts evolve their capabilities additively. Adding a desktop to Metis is `imports += [ bundles/desktop-env.nix bundles/desktop-apps.nix ];` — no rename, no role migration, no contradiction with prior ADRs.
- ✓ Reading a host's `default.nix` imports list answers "what is this host doing?" structurally: `foundation + cli-tooling + agent-clis-extras + container-runtime + ...` is a direct list of the host's capabilities.
- ✓ Foundation shrinks to its honest minimum (identity + admin + posture). The aggregator is smaller, more reviewable, and less prone to drift into a grab-bag.
- ✓ The PRD §3.3 / ADR-014 contradiction is resolved by removing the contradicting layer.
- ✓ ADR-013's explicit-imports philosophy is preserved; only the role sub-claim is retracted.
- ✗ Net per-host verbosity increases: each host file gains an explicit `foundation.nix` import plus N bundle imports, replacing the single `role = "headless"` arg. The transparency win is worth the lines.
- ✗ The `role-purity` lint promised by PRD §8.1 (#4) becomes moot and is removed. The replacement enforcement is `bundle-purity`: bundle files contain `imports` only, and each entry resolves to a module path (or to another bundle, when nested grouping emerges).
- ✗ "What kind of machine is this?" no longer has a single-word answer in the config. The host's bundle composition is the answer, expressed as a list. The operator and reviewers must read the imports rather than a label. Reframed positively: the imports *are* the answer, and they're honest in a way a label couldn't be.
- ⚠ Migration trigger: if the fleet ever grows past ~10 hosts and bundle-selection patterns become genuinely repetitive (e.g., 5+ hosts all importing the same 8 bundles), a "host-kind bundle" (a bundle that imports other bundles) can be introduced. The trigger is rule-of-three or stronger from observed duplication — not from forecast. A bundle-of-bundles is structurally fine; what's forbidden is *naming it after a host category* in advance of the data.

## Implementation

Migration proceeds as five small slices, each peer-reviewable per the operator's hard rule:

1. **Slice 1a (this commit) — Docs.** ADR-027, amendment marker on ADR-013, supersession marker on ADR-014, README index update.
2. **Slice 1b — Docs continued.** PRD §3 / §4.2 / §5 / §8.1 rewrite; `docs/taxonomy.md` addition covering foundation/bundles/standalone-modules naming.
3. **Slice 2 — Introduce `foundation.nix` + `bundles/` scaffolding.** `modules/core/nixos/foundation.nix` and the initial bundle files factored from current content. No host changes. `nix flake check` verifies no semantic drift.
4. **Slice 3 — Switch hosts.** One commit per host (nixos-vm, mercury, metis). Each commit verifies byte-identical system closure (`nix store diff-closures` empty, store path unchanged) — same standard used for the original Tier-3 module decomposition.
5. **Slice 4 — Remove role plumbing.** Delete `roles/`, drop the `role` argument from `lib/mk-host.nix`, simplify `parts/nixos.nix`. Remove the `role-purity` lint reference from PRD §8.1 (already done in slice 1b).
6. **Slice 5 — Sync ancillary documentation.** `CLAUDE.md` references to roles, AI memory files, any remaining stale references.

Filesystem layout (effective at slice 2):

```
modules/core/nixos/
  foundation.nix              # unconditional baseline
                              # (candidates: users, sops, locale,
                              # nix-daemon, firewall, system-packages,
                              # home-manager — finalised in slice 2)
  bundles/
    remote-access.nix         # sshd + mosh + ghostty.terminfo
    container-runtime.nix     # docker (host opt-in)
    local-linux-platform.nix  # boot-systemd + networking-networkmanager
    tailscale-mesh.nix        # tailscale (single-module today — stays standalone
                              # until a sibling joins; see "standalone modules" below)
  <standalone modules>        # btrfs-scrub.nix, docker.nix, etc. — direct host imports

home/core/nixos/
  foundation.nix              # universal home environment wiring
  bundles/
    cli-tooling.nix           # shell + prompt + direnv + multiplexer + editor + cli-utils + nix-tooling
    agent-clis-base.nix       # claude-code + cursor-cli (universal today)
    agent-clis-extras.nix     # codex + gemini-cli (host opt-in)
    git-personal.nix          # git + git-identity-dual + gh
    git-work.nix              # git + git-identity-work
```

The exact bundle decomposition is finalised in slice 2; the listing above is illustrative of the shape, not prescriptive. Single-module bundles named above will be reconsidered during slice 2 — they either acquire a sibling and stay a bundle, or revert to standalone modules. The rule is enforced at slice-2 review, not at ADR time.
