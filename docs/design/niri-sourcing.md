# niri sourcing after niri-flake — taking the compositor off an abandoned dependency

**Status:** Proposed — design note (`docs/design/`). Not built; **partial draft, design loop paused mid-stage-2** (see Unresolved questions for the live loop state). [#763](https://github.com/dannyfaris/nix-config/issues/763) · relates [ADR-029](../decisions/ADR-029-niri-only-desktop.md) (niri-only desktop, unchanged by this note) and [#770](https://github.com/dannyfaris/nix-config/issues/770) (theming authority, which waits on the outcome).

## Summary

niri reaches this fleet through `sodiboo/niri-flake`, a third-party flake that is no longer maintained, and that dependency has become a gate rather than a conduit: it blocks the weekly lockfile bump fleet-wide, blocks a mechanism decision in #770, and carries a single-maintainer binary-cache trust delegation that was never chosen on merit. This note proposes removing the dependency outright — niri from nixpkgs, the NixOS module surface from nixpkgs, and the KDL config surface owned by this repo — rather than narrowing it or replacing it with a fork. **How that config surface is authored once niri-flake's typed `programs.niri.settings` is gone is the open question this note exists to settle, and it is not yet decided.**

## Motivation

The immediate break is mechanical. nixpkgs removed `libdisplay-info_0_2` (alias throw dated 2026-08-04); niri-flake's `make-niri` still carries `assert libdisplay-info_0_2.version == "0.2.0";`, and `flake.nix:92` sets `niri-flake.inputs.nixpkgs.follows = "nixpkgs"`, so niri is built against our bumped nixpkgs where that attribute throws. PR [#761](https://github.com/dannyfaris/nix-config/pull/761) failed `flake-check` on both systems and was closed unmerged; the failure is structural and recurs on every bump.

The reason it is worth a design note rather than a patch is that upstream is not coming back. Two contributors have already sent the fix (niri-flake PRs #1849 and #1850); both were closed unmerged, the bug report has no maintainer response, and the repo's only recent activity is an automated lockfile bot. Waiting is not a strategy against a repo that has stopped merging.

The blast radius is disproportionate to the defect. One stalled third-party repo holds the entire fleet's nixpkgs freshness hostage, because a single flake input that `follows` our nixpkgs can veto every host's bump. It also holds up #770: that issue cannot choose a theming mechanism without knowing which niri we build against and who owns its `config.kdl`.

**Forces any solution must satisfy:**

1. **No residual dependency on an unmaintained upstream.** Narrowing the dependency (package from nixpkgs, modules still from niri-flake) leaves the same failure mode latent; the operator's ruling is that this is not acceptable.
2. **No new trust delegation as the price of the fix.** Swapping to a fork substitutes one single-maintainer flake and one single-maintainer cachix key for another. That is not a fix, it is a deferral.
3. **The weekly bump cannot be blocked by a third party again.** Whatever lands must fail closed on *our* code, not someone else's unmerged PR.
4. **Desktop capability is preserved end to end** on both remaining niri hosts: the compositor starts, greetd offers the session, config is validated *before* it reaches a host, the theme-menu include resolves, screencast works.
5. **Config validation survives the migration.** Losing niri-flake's build-time `niri validate` in exchange for runtime discovery of a broken config would trade one gate for a worse one.

**Scope boundary (operator ruling, 2026-08-11):** this is about niri and only niri. It is not a stance about single-maintainer inputs generally, and explicitly does not open an audit of other flake inputs — Noctalia included.

**Target hosts: alcyone and alnair.** metis is being decommissioned ahead of this work completing and is deliberately excluded, which leaves no third niri host to fall back on while one is being changed.

## Design

**Not yet ruled — this is the stage-3 gate, and the note is paused before it.** What follows states the fork rather than pre-empting it, so the resuming session inherits the question and not an assumed answer.

The system-side swap is settled in shape: the nixpkgs NixOS module (`nixos/modules/programs/wayland/niri.nix`) covers the side effects this repo currently inherits from niri-flake's nixosModule — session package for greetd, `systemd.packages` plus the `systemd.user.services.niri` drop-in, the `xdg.portal` config including `xdg-desktop-portal-gnome` for screencast, `wayland-session.nix`, and `gnome-keyring.enable`. See De-risk evidence.

What is genuinely open is the **KDL authoring route** — how `home/nixos/niri.nix`, `home/nixos/niri-laptop.nix` and the niri-emitting portion of `lib/capabilities.nix` produce a config once `programs.niri.settings` and `inputs.niri-flake.lib.kdl.serialize` no longer exist. Three candidates, none yet weighed against the forces above:

- **Hand-authored KDL text** managed as a home-manager file. Simplest to reason about; loses every structural guarantee, and `lib/capabilities.nix` currently relies on the typed surface to emit binds.
- **A local serializer** — a small repo-owned Nix→KDL renderer. Precedent exists in-tree: `home/nixos/theme-menu.nix` already renders `niri-{dark,light}.kdl`.
- **Vendoring niri-flake's `lib.kdl`** as repo-owned code, under its licence. Keeps the serializer's maturity, takes on its maintenance, and removes the flake without removing the code's origin.

Build-time validation looks recoverable under all three, since `pkgs.niri` ships the `niri validate` binary and can be run over generated config in a derivation — **unverified**, and it is the load-bearing assumption behind force 5.

## De-risk evidence

**Verified 2026-08-11, this session.**

- The nixpkgs niri module's contents were read directly from the pinned nixpkgs (`/nix/store/02ixg0skfsq4dgqna2dsqvynx6rrx6mk-…-source`, `nixos/modules/programs/wayland/niri.nix`). It provides `services.displayManager.sessionPackages`, `systemd.packages`, the `systemd.user.services.niri` drop-in with `enableDefaultPath = false`, the full `xdg.portal` config with `xdg-desktop-portal-gnome`, `wayland-session.nix`, and `services.gnome.gnome-keyring.enable` — the last being what `modules/nixos/libsecret.nix` documents as inherited from niri-flake. Its option surface is only `enable`, `package` and `useNautilus`; there is no settings/KDL surface, which is what makes the authoring question load-bearing.
- The consumer surface was enumerated by grep: `home/nixos/niri.nix` (384 lines, incl. the `lib.kdl.serialize` call at :87), `home/nixos/niri-laptop.nix` (37), `modules/nixos/niri.nix` (111), `lib/capabilities.nix` (niri-emitting portion), plus side-effect dependents `greetd.nix`, `libsecret.nix`, `xdg-portal.nix`, `polkit-agent.nix`, `pointer-icons.nix`, `theme-menu.nix`.
- Affected hosts confirmed from `hosts/*/default.nix`: alcyone, alnair, metis import the desktop bundle; electra is true headless (no desktop-env, #637 decision 3); neptune is Darwin. With metis decommissioning, the target set is alcyone and alnair.

**Recorded in #763 but NOT re-verified here** — treat as claims, not findings: the niri-flake PR closures (#1849, #1850) and issue #1851; `libdisplay-info-sys`'s declared `>= 0.1.0, < 0.4.0` range and the 0.4 wall; the `epireyn` fork's output surface and cache; nixpkgs shipping niri 26.04 built against `libdisplay-info_0_3`.

**Explicitly unverified, and blocking:**

- Whether `niri validate` can be run over generated config in a derivation to replace niri-flake's build-time validation (force 5's load-bearing assumption).
- Whether anything in the tree still forces niri-flake's package set once the input is removed.
- Whether nixpkgs' `withScreencastSupport` default matches what the desktop bundle needs.
- Whether nixpkgs' niri version tracks the 26.04 line that `modules/nixos/niri.nix:45-51` requires for `include optional=true` — the theme-menu include depends on it.

## Drawbacks

The strongest argument against this direction is that it converts a maintained-by-someone-else surface into a maintained-by-us one. niri-flake's typed settings surface, its KDL serializer and its build-time validation are real engineering that this repo would now own, and the compositor config is not a place where a subtle regression is cheap.

nixpkgs' niri may also lag upstream releases in a way niri-flake's `niri-unstable` slot did not, and this repo has a hard version floor: the theming include needs the 26.04 line. Trading a stalled flake for a version cadence we do not control is a real exposure, not a hypothetical one.

Finally, the change lands on the login path for the only two graphical hosts remaining after metis retires. A wrong session entry means greetd offers nothing and recovery is the physical console.

## Cost

Standing price of the direction once chosen: this repo owns niri config generation and its validation permanently. Every niri release that changes KDL syntax becomes our migration to absorb, where previously it arrived as an upstream flake bump. That cost is accepted knowingly — it is the price of force 1 — but it does not go away after the migration lands.

## Rationale & alternatives

The route was ruled by the operator on 2026-08-11: **no posture that keeps this repo reliant on an abandoned flake**, with the additional effort accepted explicitly. Against the forces:

- **Migrate to `epireyn/niri-flake`** (the fork carrying the fix) — fails force 2. It substitutes one single-maintainer flake for another whose last twelve commits are almost entirely bot lockfile updates, and swaps `niri.cachix.org` for a newer, less-proven single-maintainer cache. Same dependency shape, same failure available later.
- **Wait for upstream** — fails force 3. The fix has been written twice and closed twice with no maintainer response; there is no event to wait for.
- **Carry a local patch or overlay** — fails force 1 as a destination. The flake stays, and we pin ourselves to patching someone else's stale assert indefinitely. Viable only as a stopgap if the bump must be unblocked before this note lands.
- **Package from nixpkgs, retain niri-flake for its modules** (#763's original framing of route (a)) — fails force 1. The unmaintained input remains load-bearing for the config surface, so the gate is narrowed rather than removed.

**Doing nothing** leaves the weekly bump failing every Monday and #770 blocked behind it.

Decision 2 of #763 resolves as a consequence rather than a separate choice: `niri.cachix.org` is **dropped, not replaced**, and the explicit trust delegation at `modules/nixos/niri.nix:57-67` goes with it — one fewer single-maintainer cache key under the whitelist-over-blanket stance (relates #579 / #568).

## Prior art

niri-flake's own README, and the fork's, name `programs.niri.package = pkgs.niri;` as the supported escape hatch for operators who do not want the maintainer's cache — the migration path is one upstream anticipated, even if it does not cover the settings surface.

This repo has already rendered KDL from Nix without niri-flake: `home/nixos/theme-menu.nix` emits `niri-{dark,light}.kdl` artefacts consumed through the conductor's include. That is a working precedent for the local-serializer route, at a much smaller scale.

The closest procedural precedent in-tree is [`docs/research/noctalia-v5-native-theming.md`](../research/noctalia-v5-native-theming.md): a source-level audit of a pinned upstream that concluded *not yet* on a migration, with the trigger conditions written down. The lesson carried here is its correction history — an upstream read that was accurate at its pin and wrong three weeks later. Claims about niri-flake and nixpkgs in this note are dated for the same reason.

## Unresolved questions

**Live loop state (paused 2026-08-11, mid-stage-2).** The design loop is dialogue-centric and agreement-gated; it stays open through implementation and runtime validation, not closed at this note.

- **Stage 1 — Intent: agreed.** Scoped to niri only, abandoned-flake framing, no generalised stance about other inputs.
- **Stage 2 — Size: heavy loop, full note.** Agreed. Login-path surface, two hosts, one sticky sub-decision. **Open within this stage:** whether the change gets a VM reboot rehearsal before hardware, per CLAUDE.md's non-waivable rule for auth/boot-path surface. Author's lean: yes.
- **Stage 3 — Design: not started.** The KDL authoring fork above is the first subject.
- **Stages 4–7** — de-risk, build, peer review, reconcile + runtime validation: not started.

**Deferred from #763 into this loop:** version cadence (its decision 3) given the 26.04 floor, and whether the change crosses the `selecting-tooling` threshold (its decision 4).

**Out of scope:** any other flake input, the compositor selection itself (ADR-029 stands), and what niri does functionally.

## Future possibilities

If the local-serializer route wins and matures, the repo-owned Nix→KDL renderer would be a candidate for extraction — either as a shared lib unit alongside the existing `lib/` constructors, or upstreamed to nixpkgs' niri module, which today has no settings surface at all and would be the natural home for one.

Removing the input also simplifies the #770 theming decision: with `config.kdl` unambiguously owned by this repo, the question of whether Noctalia's niri template can append its `include` line has a definite answer rather than an inferred one.
