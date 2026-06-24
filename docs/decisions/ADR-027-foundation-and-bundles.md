# ADR-027: Foundation and capability bundles (walk back the role taxonomy)

**Date**: 2026-05-27
**Status**: Accepted

> This ADR **supersedes [ADR-014](./ADR-014-independent-roles.md)** in full and **amends [ADR-013](./ADR-013-composition-framework.md)** by retracting its role-specific sub-claim while preserving its broader explicit-imports philosophy. The composition framework's rejection of auto-discovery, its whitelist stance, and its "explicit > implicit" posture all survive; only the *role layer* on top of that framework is walked back. [ADR-015](./ADR-015-tier-as-directory.md) (tier-as-directory) and [ADR-016](./ADR-016-host-identity.md) (host identity) are untouched.

> **Revision (2026-06-05):** stale module paths in this ADR were swept to the
> current flat layout (`home/core/…` → `home/…`, `modules/core/…` → `modules/…`)
> per [ADR-026](./ADR-026-drop-core-tier-prefix.md), which dropped the `core/`
> tier prefix. Navigability fix only — the decision recorded here is unchanged.

## Context

ADRs 013 and 014 introduced a three-role taxonomy — `headless`, `linux-workstation`, `macos-workstation` — with **independent** (non-inherited) role composition. The PRD §3 was written around the same model.

Three hosts in, with the role taxonomy mature enough to evaluate, the data is sharper than the forecast:

- Only one role has been implemented: `headless`. All three hosts (nixos-vm, mercury, metis) adopt it.
- Of the nine modules `roles/headless.nix` imports, **zero are headless-specific**. Every entry (locale, nix-daemon, sshd, firewall, sops, users, system-packages, mosh, home-manager) is universal to every NixOS host the operator runs. The role name asserts a property — *absence of graphical environment* — that none of its contents actually depend on.
- The next planned divergence is Metis growing a desktop environment. Under the existing taxonomy this creates a category problem: Metis is no longer "headless" but is also not yet a "linux-workstation" by any clean definition. Either the role name becomes a lie on the tin, or Metis migrates to a `linux-workstation` role that re-imports the same nine modules under a different label.
- PRD §3.3 describes `linux-workstation` as "the full development environment of `headless` plus a GUI layer" — a layered/inherited relationship — directly contradicting ADR-014's independence stance. The architecture is at war with itself on this point.
- The forecast that justified the role abstraction (multiple instances per role, with role-shaped overlap as the cost-center to amortize) has not materialised. Two roles remain unbuilt; the one that exists carves no actual joint.

The role concept was *abstraction-by-forecast*. It paid interest immediately (categorisation overhead, the PRD/ADR contradiction, friction every time a host's purpose evolved) without delivering a payoff. The honest correction is to walk the abstraction back to what's actually doing work: shared modules, opted into by hosts according to what those hosts do.

## Decision

Adopt a **bundle-based composition model** with explicit standalone-module imports for ungrouped capabilities:

1. **Capability bundles** — aggregator files at `modules/<platform>/bundles/<name>.nix` (and the home-manager parallel). Each bundle's body is an `imports` list naming **two or more** modules toward a coherent named capability the host has. Hosts opt in by importing the bundle in their own `imports` list. Bundle names describe *what is in them* (`cli-tooling`, `desktop-env`, `agent-clis-extras`, `container-runtime`, `remote-access`), never *what kind of host they're for*. Single-module "bundles" are forbidden — they're noise; the underlying module stays standalone until a sibling joins it.

2. **Standalone modules** — modules a host imports directly when no natural bundle home has emerged for them. They graduate to bundle membership when a coherent capability category surfaces (rule-of-two-with-intent-to-grow). Standalone-ness is not a defect; it's the honest state for a capability that hasn't yet attracted siblings.

3. **Foundation** — `foundation.nix` at the top of each platform's module tree (`modules/<platform>/foundation.nix` and, where applicable, `home/<platform>/foundation.nix`) is a bundle by every structural rule, distinguished only by *convention*: every host of the platform imports it. Its contents are whatever modules are unconditionally true of every host that platform serves — typically identity (users, sops), administration (nix-daemon, locale, baseline system packages), and security posture (firewall). The same `bundle-purity` rule applies (≥ 2 imports, pure aggregation). Placement at the top of the platform tree rather than inside `bundles/` is a discoverability convention reflecting its conventional universal-import status — not a separate structural layer.

The `roles/` directory ceases to exist. `lib/mk-host.nix` retains its host-construction role (specialArgs, third-party flake-module imports, etc.); only its `role` argument is removed. Each host's `default.nix` explicitly imports `foundation.nix` plus the bundles and standalone modules it wants.

Bundles are flat: they import modules, not other bundles. A bundle-of-bundles is not part of this model. If a future architectural need genuinely surfaces (driven by observed data, not forecast), that is a separate decision documented in its own ADR.

The contents distinction between foundation and other bundles (foundation tends to hold identity + admin + posture; other bundles hold capabilities) is a *guideline* about what belongs inside a foundation file, not a structural difference between foundation and other bundles. A capability that every host of a platform happens to want today still belongs in a capability bundle, not in foundation; fleet uniformity is a snapshot property, not a reason to collapse the taxonomy.

## Rationale

**Bundles describe what is in them; roles described what hosts are for.** The role abstraction collapsed every distinguishing axis of a host (cloud vs bare-metal, work vs personal, dev vs service, headless vs graphical) into a single categorical label. Real hosts hit combinations the role didn't capture, and the label became a category lie under predictable evolution. Bundle names describe their contents and don't claim anything about the host that imports them. The same bundle (`cli-tooling`) can sit in a headless dev box, a workstation, and a future appliance host without changing meaning.

**Capability-grouping matches how the operator already conceptualises the config.** The home-module tree was already organised by capability (`shell.nix`, `prompt.nix`, `editor.nix`, `multiplexer.nix`, `agent-clis.nix`, `cli-utils.nix`). The role layer was bolting categorical labels on top of an existing functional organisation. Promoting capability-grouping to a first-class structural concept (bundles) honours what was already true.

**The Metis-with-desktop scenario becomes trivial.** Under the role model, Metis growing a desktop forced either a category lie (`headless` Metis with niri imports) or a role migration (move Metis to `linux-workstation` that mechanically re-imports the same baseline under a different label, per ADR-014). Under the bundle model, Metis was `{ foundation + cli-tooling + agent-clis-extras + container-runtime + tailscale-mesh + local-linux-platform }`; it becomes `{ ... + desktop-env + desktop-apps }`. Additive, no rename, no contradiction.

**Foundation is structurally a bundle, distinguished only by convention.** An earlier framing of this design described foundation as a separate compositional layer above bundles. That was unnecessary: foundation is an aggregator file that imports two or more modules, satisfies the same `bundle-purity` rule, and is just named and placed conventionally to mark its universal-import status. Treating it as "the bundle hosts conventionally always import" collapses two concepts into one without losing anything. The contents guideline (foundation tends to hold identity / admin / posture; other bundles hold capabilities) governs what should be *inside* foundation, not whether foundation is structurally different from a bundle.

**Foundation should stay honestly minimal.** Folding "every host imports it today" into foundation would re-create the same flattening that made `headless` a grab-bag. Foundation is reserved for things that *cannot be opt-out capabilities* — identity (users, sops), administration (nix-daemon, locale, baseline system packages), posture (firewall). Capabilities, even universal-today ones (remote access via sshd, cli tooling), live in capability bundles. This preserves the taxonomy as the fleet evolves: a future appliance host that doesn't need cli-tooling can simply not import that bundle, and the existing bundle structure makes that change trivial.

**Single-module bundles are forbidden.** Pre-wrapping a single module in a bundle file adds an indirection without a capability grouping to justify it — the same kind of forecast-driven abstraction the role layer was. A bundle earns its place when it aggregates 2+ modules toward a coherent named capability. Until then, the module stays standalone in `modules/<platform>/`. Promotion happens when a natural sibling appears.

**ADR-013's broader philosophy survives.** ADR-013's load-bearing claims — flake-parts as the organisational framework, explicit imports over auto-discovery, whitelist over blanket — are independent of the role taxonomy. Foundation and bundles use explicit imports throughout; nothing here re-introduces auto-discovery. The role-specific sub-claim ("each role file lists its modules") is what gets walked back; the explicit-composition philosophy stands. The amendment marker on ADR-013 says so directly.

**ADR-014 dissolves cleanly.** ADR-014's stance ("roles are independent, not inherited") was an answer to a question that no longer exists. Without a role layer there's nothing to inherit. The reasoning behind ADR-014 (avoid inheritance contracts, keep composition flat) survives in spirit: bundles are themselves non-inherited, and host import lists are flat.

**Profile/feature-flag systems were considered and rejected.** A `options.profiles.X.enable = true;` model (snowfallorg-style) would solve the same problem but reintroduce the very "applicability lives in the module" pattern ADR-013 correctly rejected. Bundles keep applicability in the *importing* file (the host), which is exactly where the user looks first when asking "what is this host doing?".

## Consequences

- ✓ Bundle names are honest by construction. A bundle cannot become a category lie because it isn't making a category claim about the host.
- ✓ Hosts evolve their capabilities additively. Adding a desktop to Metis is `imports += [ bundles/desktop-env.nix bundles/desktop-apps.nix ];` — no rename, no role migration, no contradiction with prior ADRs.
- ✓ Reading a host's `default.nix` imports list answers "what is this host doing?" structurally: `foundation + cli-tooling + agent-clis-extras + container-runtime + ...` is a direct list of the host's capabilities.
- ✓ One structural concept covers all aggregator files: `bundle-purity` applies to foundation and bundles uniformly (≥ 2 imports, pure aggregation, no inline configuration). No carve-outs, no special cases.
- ✓ Foundation stays honestly minimal (identity + admin + posture). The aggregator is smaller, more reviewable, and less prone to drift into a grab-bag.
- ✓ The PRD §3.3 / ADR-014 contradiction is resolved by removing the contradicting layer.
- ✓ ADR-013's explicit-imports philosophy is preserved; only the role sub-claim is retracted.
- ✗ Net per-host verbosity increases: each host file gains an explicit `foundation.nix` import plus N bundle imports, replacing the single `role = "headless"` arg. The transparency win is worth the lines.
- ✗ The `role-purity` lint promised by PRD §8.1 (#4) becomes moot and is removed. The replacement enforcement is `bundle-purity`: aggregator files (foundation and bundles) contain an `imports` list of two or more distinct modules and no inline configuration.
- ✗ "What kind of machine is this?" no longer has a single-word answer in the config. The host's bundle composition is the answer, expressed as a list. The operator and reviewers must read the imports rather than a label. Reframed positively: the imports *are* the answer, and they're honest in a way a label couldn't be.

## Implementation

Migration proceeds as five small slices, each peer-reviewable per the operator's hard rule:

1. **Slice 1a (this commit) — Docs.** ADR-027, amendment marker on ADR-013, supersession marker on ADR-014, README index update.
2. **Slice 1b — Docs continued.** PRD §3 / §4.2 / §5 / §8.1 rewrite; `docs/taxonomy.md` addition covering foundation/bundles/standalone-modules naming.
3. **Slice 2 — Introduce `foundation.nix` + `bundles/` scaffolding.** `modules/nixos/foundation.nix` and the initial bundle files factored from current content. No host changes. `nix flake check` verifies no semantic drift.
4. **Slice 3 — Switch hosts.** One commit per host (nixos-vm, mercury, metis). Each commit verifies byte-identical system closure (`nix store diff-closures` empty, store path unchanged) — same standard used for the original Tier-3 module decomposition.
5. **Slice 4 — Remove role plumbing.** Delete `roles/`, drop the `role` argument from `lib/mk-host.nix`, simplify `parts/nixos.nix`. Remove the `role-purity` lint reference from PRD §8.1 (already done in slice 1b).
6. **Slice 5 — Sync ancillary documentation.** `CLAUDE.md` references to roles, AI memory files, any remaining stale references.

Filesystem layout (decomposition decided in slice 2 after peer review):

```
modules/nixos/
  foundation.nix              # imports: locale, nix-daemon, firewall, sops,
                              #          users, system-packages, home-manager
  ghostty-terminfo.nix        # standalone — extracted from system-packages
                              # so it can sit in remote-access bundle
  bundles/
    remote-access.nix         # sshd + ghostty-terminfo
  boot-systemd.nix            # standalone (no coherent sibling)
  networking-networkmanager.nix  # standalone (no coherent sibling)
  docker.nix                  # standalone (single-module; container-runtime
                              # bundle would be pre-wrapping a single module)
  tailscale.nix               # standalone (single-module; tailscale-mesh
                              # bundle would be pre-wrapping a single module)
  btrfs-scrub.nix             # standalone (no coherent sibling)

home/nixos/
  (no foundation.nix — the home tree is all capabilities; nothing
   foundation-shaped to aggregate. PRD §3.2 hedges this case with
   "where applicable".)
  bundles/
    cli-tooling.nix           # shell + prompt + direnv + multiplexer
                              # + editor + cli-utils + nix-tooling
    git-multi-identity.nix    # git + git-identity-dual + gh
    git-work.nix              # git + git-identity-work
  ssh.nix                     # standalone (single SSH outbound config)
  macchina.nix                # standalone (single login-info display)
  agent-clis.nix              # standalone — kept as one cohesive module
                              # installing claude-code + cursor-cli
                              # (splitting into per-CLI modules just to
                              # satisfy the bundle ≥ 2 rule would be
                              # pure ceremony)
  agent-clis-extras.nix       # standalone — same rationale for
                              # codex + antigravity-cli
```

The decomposition above resolves the "single-module bundles will be reconsidered during slice 2" question raised in the original draft: those entries either acquired a sibling and stayed a bundle (none, in the event), or reverted to standalone modules (most). The `local-linux-platform` bundle was rejected on coherence grounds during the same review — "bootloader + NetworkManager" was a host-shape label rather than a capability.

## History

### `theming.nix` reclassified from bundle to standalone module (2026-05-31)

`home/shared/bundles/theming.nix` was authored in slice 2b (PR #30,
2026-05-28) — before the `bundle-purity` lint existed — as a file living
under `bundles/` whose body sets `stylix.targets.*.enable` inline, with
no `imports` list. Measured against the `bundle-purity` rule (§8.1 #4,
restated in this ADR's Decision and Consequences), that is a violation on
two counts: an aggregator file must contain **only** an `imports` list of
**two or more** distinct modules, and `theming.nix` has zero imports and
sets options inline. This blocked the `bundle-purity` lint from landing
(#54 P5.1, tracked via #65).

The resolution **(B)** is to recognise the **category error** rather than
bend the file or the rule. `theming.nix` is not an aggregator and never
was: it is a single coherent capability — the explicit whitelist of which
HM-managed tools cede their theming to Stylix — expressed as a flat list
of `enable` toggles. That is a *standalone module*, not a bundle. The fix
is therefore a reclassification, not a refactor:

- The file moves out of `bundles/` to `home/shared/stylix-targets.nix`
  (a standalone module). Standalone modules are permitted to set options
  inline; the `bundle-purity` rule governs only `foundation.nix` and files
  under `bundles/`, so the violation ceases to exist by construction —
  no PRD amendment, no lint carve-out.
- Hosts that imported the bundle (metis, nixos-vm, mercury) repoint their
  `extraHomeModules` entry to the new path.

**Alternatives weighed.** (A) Splitting into one single-line module per
Stylix target and making `theming.nix` a genuine `imports` list. Rejected:
it conforms literally but produces ~14 near-empty files no host imports
separately — exactly the forecast-driven indirection this ADR's
"single-module bundles are forbidden" rationale warns against — and
scatters the per-target rationale comments that currently make "where does
Stylix theming live?" read as one file. (C) Amending §8.1 #4 to carve out
a "configuration bundle" class. Rejected: it weakens a bright-line,
deterministic invariant to accommodate one mis-filed file and complicates
`lint-bundle-purity.sh` with a "config bundle vs real bundle" distinction
— the Consequences above explicitly count "no carve-outs, no special
cases" as a win.

This amendment changes no decision in this ADR; it is a clarifying
application of the taxonomy it already defines (a bundle aggregates ≥ 2
modules; a single coherent capability is a standalone module). See #65
for the implementing change.

### Foundation's inline Stylix block factored into stylix-palette.nix (2026-05-31)

This ADR states three times — with deliberate force — that foundation is governed by `bundle-purity` identically to any other aggregator: *"The same `bundle-purity` rule applies (≥ 2 imports, pure aggregation)"* (Decision §3); *"`bundle-purity` applies to foundation and bundles uniformly (≥ 2 imports, pure aggregation, no inline configuration). No carve-outs, no special cases"* (Consequences). Foundation being *"structurally a bundle, distinguished only by convention"* is load-bearing to the whole walk-back of the role taxonomy.

The very next ADR contradicted it. **ADR-028 (one day later) added an inline `stylix = { enable; autoEnable; base16Scheme; }` block to `foundation.nix`** when it promoted Stylix to foundation. That made foundation impure — an `imports` list *plus* inline configuration — in direct violation of the rule above. The contradiction went unnoticed because the enforcing lint (`bundle-purity`, PRD §8.1 #4) was never built; it surfaced when #54 P5.1 set out to build it and found foundation would be the lint's sole violator (every actual `bundles/` file is clean).

**Resolution: factor the block out, change no rule.** The inline `stylix` block — together with the `let palettes = …; scheme = …` lookup and the `inputs.stylix.nixosModules.stylix` import — moves to a new standalone module `modules/nixos/stylix-palette.nix`, which foundation imports like every other concern. This was the correct shape independently of the lint: the `stylix` block was *the only concern in foundation not already given its own module* — `i18n` lives in `locale.nix`, the firewall in `firewall.nix`, identity in `users.nix`, the default editor in `editor-defaults.nix`. The palette was the lone exception. Factoring it out makes foundation internally consistent (a uniform imports list) and resolves the contradiction **without** a carve-out, a rule relaxation, or a structural foundation-vs-bundle distinction — preserving this ADR's "distinguished only by convention" claim intact.

**Alternatives weighed.** (A) Carve foundation out of the no-inline-config clause — rejected: it reintroduces exactly the structural foundation-vs-bundle distinction this ADR fought to erase, trading one contradiction for another. (C) Drop the no-inline-config clause entirely (lint enforces only ≥ 2 imports) — rejected: that clause legitimately keeps *bundles* honest (a bundle named `cli-tooling` must not secretly set `services.foo`); discarding a good rule to fix a misapplication of it is the wrong trade. (B, chosen) costs one small module and is what foundation's own established pattern already dictated.

This unblocks #54 P5.1: `bundle-purity` can now be implemented and wired into CI as written, with foundation passing. The naming parallels the home side — `modules/nixos/stylix-palette.nix` (system: defines the per-host palette) and `home/shared/stylix-targets.nix` (home: whitelists which tools consume it). See ADR-028 §History for the cross-reference. No decision in this ADR changes; this is a clarifying application of the taxonomy it already defines.

### `bundle-purity` lint narrowed to the shape check (2026-06-06)

Per [ADR-032](./ADR-032-proportionate-enforcement-and-rationale.md) (Rule 1 — proportionate enforcement), the `bundle-purity` lint now gates only the load-bearing invariant — pure aggregation, no inline configuration. The "≥ 2 distinct modules" and "no duplicate entries" sub-rules stated in this ADR's Decision and Consequences survive as **conventions** (author/reviewer-enforced), no longer mechanically gated: duplicate imports are idempotent in Nix, and forbidding single-module bundles is structural rather than correctness-bearing. The hand-rolled paren-tokeniser those two checks needed, and the separate self-test harness that locked in its behaviour, were removed with them. The composition model this ADR decides is unchanged — only the enforcement *mechanism* is lighter.
