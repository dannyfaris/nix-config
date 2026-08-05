---
date: 2026-07-25
status: Accepted, Implementation pending
---

# ADR-045: Star host-naming — a flat, non-binding pool, superseding the celestial-substrate framework

> Retires [ADR-038](./ADR-038-celestial-host-naming.md)'s substrate→class thesis (*gravitational binding mirrors operational dependency*) wholesale, and names hosts after **stars** instead: a flat pool that makes no operational claim. The move answers two problems the incoming intake surfaced ([#639](https://github.com/dannyfaris/nix-config/issues/639)): the major-planet pool is exhausted (8 planets − Earth = 7, nearly all assigned, ~2 free against ~5 un-named owned machines inbound), and "moon-capable" had gone dishonest for machines — laptops, service-minis, a NAS — that will never anchor a VM. Both trace to the *name carrying a claim*; a flat star-label dissolves both. The approach is **deliberately non-binding** — taste, not rule; host names remain non-load-bearing (they drive no config, unchanged from ADR-038 §Context). Full fleet re-key, no grandfathering (only `neptune` had landed as a deployed rename, so the live-cutover cost is one box). VMs are just stars — the moon→planet binding is dropped. The collective fleet takes the name **Sidera**. The living naming rule — southern-sky preference, the optional constellation-grouping, the per-host roster — lives in [taxonomy.md](../taxonomy.md#host-naming), **not** frozen here, precisely because it is non-binding. Decided in #639; renames staged per-host as before.

## Context

ADR-038 keyed a host's celestial class on **substrate** (owned metal → moon-capable planet; VPS → moonless planet; pinned VM → moon; else → the minor-body reserve) and made the *name itself carry an operational claim*. An incoming intake — a flagship tower, a NAS, three headless mini PCs, laptops (#639 and its linked issues) — broke that in two ways at once. **The planet pool is exhausted:** seven usable planets, nearly all assigned, leaving ~two free names against ~five un-named owned machines. **The claim went dishonest:** a laptop, a service-mini, or a storage box named a "moon-capable planet" asserts a capability — anchoring pinned VMs — it will never exercise. Both problems share one root: ADR-038 made the name promise something about the machine. #639 framed the options (evolve ADR-038 via moons / minor-body promotion / a new classing axis, **vs.** retire the structure); the operator chose to retire it.

## Decision

1. **Hosts are named after stars** — a single flat pool. ADR-038's substrate→class table and its *gravitational-binding* principle are **retired in full**; a star name encodes nothing about the machine.
2. **The naming rule and roster are deliberately non-binding** — taste, not rule: which star lands on which host constrains nothing, is not load-bearing (host names drive no config; the eval-bearing references remain only the directory name and the handful of keys that move with it, exactly as ADR-038 §Context established), and may change freely. (Adopting stars and re-keying the fleet — items 1 and 3 — is this ADR's binding decision; the non-binding part is the taste layer on top.) Making the name carry no operational claim is the direct antidote to the trap ADR-038 fell into.
3. **Full fleet re-key, no grandfathering.** A half-planets / half-stars fleet is the incoherent namespace the theme exists to prevent. This is the cheapest the re-key will ever be: of ADR-038's planet renames only `neptune` (the #403 pilot) landed as a deployed host. Re-keying now touches barely-started ground rather than locking in a permanent mixed theme.
4. **VMs are just stars.** The moon→planet binding — ADR-038's one structurally load-bearing encoding — is dropped; a pinned VM is simply another star, named ad hoc.
5. **The collective fleet is named Sidera** (Latin, *the stars / constellations*). This ADR adopts the name; *executing* a repository rename (remotes, `flakePath`/`NH_FLAKE`, references) is separate, out-of-scope future work.
6. **The living rule lives in taxonomy.md, not here.** The southern-sky preference, the optional practice of giving a grouped site a shared constellation/cluster (e.g. the main homelab as the Pleiades, an offsite site as Centaurus stars), the laptops-take-unattached-stars lean, and the per-host roster are recorded in taxonomy.md as **non-binding flavour** — deliberately *not* frozen into this immutable record. Freezing a per-host table is exactly what forced ADR-038's #448 correction, and a non-binding preference has no place on an ADR's decision surface.

## Consequences

- ✓ Headroom is effectively unbounded — the planet ceiling and the "VPS caps at two" constraint both disappear permanently.
- ✓ The substrate-vs-practice dishonesty **evaporates** rather than needing a new rule: a flat label makes no claim, so there is nothing to be dishonest about.
- ✓ Cheapest possible transition — only `neptune` had deployed under a celestial name, so no permanent mixed theme is locked in.
- ✓ Stays within ADR-038's celestial spirit, so it reads as a deliberate refinement of the same theme, not a theme-hop.
- ✗ The trade is **encoded meaning → headroom + simplicity**: a star name tells you nothing about the machine, by design. ADR-038's one genuinely-useful encoding (a moon name recording its VM's host) is consciously given up.
- ✗ The one-time re-key churn ADR-038 already carried still applies to the pending renames — `neptune` → its star now carries a real macOS/tailnet cutover (the only landed rename, undone), and `metis` → its star is the substantive Linux rename (eval-bearing keys in lockstep, per the #403 pattern).
- ⚠ **Process note — landed without a separate design-loop note, deliberately.** CLAUDE.md's default routes a cross-cutting change through a `docs/design/` note, and #639's own comment named the design loop. The skip is conscious: the option exploration already happened in #639 (evolve ADR-038 vs retire it) plus the decision discussion, and an ADR *is* the design record for it — so per [ADR-032](./ADR-032-proportionate-enforcement-and-rationale.md)'s proportionality this ADR + the taxonomy rewrite are the fitting mechanism, and a separate `docs/design/` note would only restate #639. Recorded so it is a chosen exception, not an oversight.

## Relationship to prior ADRs

- **[ADR-038](./ADR-038-celestial-host-naming.md) is superseded in full** — its thesis, class table, and per-host selection no longer apply. Its status header is set to `Superseded by ADR-045`; its body is frozen record (ADR-037), annotated not rewritten.
- **[ADR-016](./ADR-016-host-identity.md) (host identity) is unchanged and still holds:** a host name is a stable property of the physical machine; a hardware swap is a new host, a role change is no rename. ADR-038's conscious, one-time overturn of ADR-016's "existing directories are never renamed in place" clause (ADR-016 §Implementation) is **re-affirmed here** — the re-key still lands via `git mv`, which preserves the history that clause protected. The blanket "never" stays lifted for this one themed re-key only, not as a standing licence.

## Implementation

Doc-before-code, then the same staged per-host rollout ADR-038 established — each rename its own peer-reviewed PR citing this ADR:

1. **This ADR** + the rewritten host-naming section in [taxonomy.md](../taxonomy.md#host-naming) (the applied, non-binding rule + current roster) + ADR-038 status → `Superseded by ADR-045` + the matching `decisions/README.md` row. Documentation-only; every `hosts/<name>/` directory stays live until its own rename pass.
2. **Per-host renames**, each on the #403 pattern — `git mv` plus the eval-bearing keys that must move in lockstep or `nix flake check` throws (`parts/{nixos,darwin}.nix` host key, `parts/checks.nix` `host-<name>` + `stances-<name>`, the `lib/palette-for.nix` host-keyed palette selection (the nixos/darwin `stylix-palette.nix` twins throw on a missing `hostName`), `hostName`/`hostContext.hostName`), plus macOS `computerName`/`localHostName` and the operator-run tailnet re-point where applicable. `neptune` → its star and `metis` → its star are the two renames with live hosts behind them; intake hosts are named on onboard; VMs named ad hoc.

## References

- [ADR-038](./ADR-038-celestial-host-naming.md) — superseded by this ADR (substrate-keyed celestial framework retired).
- [ADR-016](./ADR-016-host-identity.md) — host identity; unchanged, its one-time rename overturn re-affirmed here.
- [ADR-037](./ADR-037-doc-mutability-contracts.md) — why the superseded ADR's body is annotated, not rewritten.
- [ADR-032](./ADR-032-proportionate-enforcement-and-rationale.md) — the proportionality basis for the design-loop skip.
- [taxonomy.md](../taxonomy.md#host-naming) — the applied, non-binding naming rule and roster.
- [#639](https://github.com/dannyfaris/nix-config/issues/639) — decision record (planet-ceiling problem + the move to stars); [#368](https://github.com/dannyfaris/nix-config/issues/368) / [#403](https://github.com/dannyfaris/nix-config/issues/403) — the superseded framework and its pilot.

## History

- 2026-08-05 — saturn purged from the repo before it was ever deployed (its machine leaves the fleet, to be managed by hand outside it), so its pending re-key is withdrawn; the star name Acrux is retained in [taxonomy.md](../taxonomy.md#host-naming) as an unassigned reserve name.
