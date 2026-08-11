# niri sourcing after niri-flake — taking the compositor off an abandoned dependency

**Status:** Proposed — design note (`docs/design/`). Not built; design ruled through stage 3, de-risk and build next. [#763](https://github.com/dannyfaris/nix-config/issues/763) · relates [ADR-029](../decisions/ADR-029-niri-only-desktop.md) (niri-only desktop, unchanged by this note) and [#770](https://github.com/dannyfaris/nix-config/issues/770) (theming authority, which waits on the outcome).

## Summary

niri reaches this fleet through `sodiboo/niri-flake`, a third-party flake that is no longer maintained, and that dependency has become a gate rather than a conduit: it blocks the weekly lockfile bump fleet-wide, blocks a mechanism decision in #770, and carries a single-maintainer binary-cache trust delegation that was never chosen on merit. This note removes the dependency outright — niri and its NixOS module from nixpkgs, and the KDL config surface owned by this repo as plain data rendered through a vendored 224-line MIT serializer. The typed `programs.niri.settings` option tree is deliberately not reproduced; `niri validate` at build time replaces what it guarded.

## Motivation

The immediate break is mechanical. nixpkgs removed `libdisplay-info_0_2` (alias throw dated 2026-08-04); niri-flake's `make-niri` still carries `assert libdisplay-info_0_2.version == "0.2.0";`, and `flake.nix:92` sets `niri-flake.inputs.nixpkgs.follows = "nixpkgs"`, so niri is built against our bumped nixpkgs where that attribute throws. PR [#761](https://github.com/dannyfaris/nix-config/pull/761) failed `flake-check` on both systems and was closed unmerged; the failure is structural and recurs on every bump.

The reason it is worth a design note rather than a patch is that upstream is not coming back. Two contributors have already sent the fix (niri-flake PRs #1849 and #1850); both were closed unmerged, the bug report has no maintainer response, and the repo's only recent activity is an automated lockfile bot. Waiting is not a strategy against a repo that has stopped merging.

The blast radius is disproportionate to the defect. One stalled third-party repo holds the entire fleet's nixpkgs freshness hostage, because a single flake input that `follows` our nixpkgs can veto every host's bump. It also holds up #770: that issue cannot choose a theming mechanism without knowing which niri we build against and who owns its `config.kdl`.

**Forces any solution must satisfy:**

1. **No residual dependency on an unmaintained upstream.** Narrowing the dependency (package from nixpkgs, modules still from niri-flake) leaves the same failure mode latent.
2. **No new trust delegation as the price of the fix.** Swapping to a fork substitutes one single-maintainer flake and one single-maintainer cachix key for another. That is a deferral, not a fix.
3. **The weekly bump cannot be blocked by a third party again.** Whatever lands must fail closed on *our* code, not someone else's unmerged PR.
4. **Desktop capability is preserved end to end** on both niri hosts: the compositor starts, greetd offers the session, the theme-menu include resolves, screencast works.
5. **Config validation survives the migration.** Losing build-time validation in exchange for runtime discovery of a broken config would trade one gate for a worse one.

**Scope boundary (operator ruling, 2026-08-11):** this is about niri and only niri. It is not a stance about single-maintainer inputs generally, and explicitly does not open an audit of other flake inputs — Noctalia included.

**Target hosts: alcyone and alnair** — the only remaining niri hosts since metis was retired (#387, PRs #799/#800). There is no third graphical host to fall back on while one is being changed.

## Design

Three forks were ruled in operator dialogue on 2026-08-12; the mechanism follows from them.

**System layer — nixpkgs, wholesale.** `modules/nixos/niri.nix` imports nixpkgs' `programs.niri` module instead of niri-flake's nixosModule, and takes `pkgs.niri` as the package. The nixpkgs module supplies the side effects this repo currently inherits: the session package greetd reads, `systemd.packages` plus the `systemd.user.services.niri` drop-in, the `xdg.portal` config including `xdg-desktop-portal-gnome` for screencast, `wayland-session.nix`, and `gnome-keyring.enable`. The `niri-flake` input is removed from `flake.nix`, and with it the `niri.cachix.org` substituter and trusted key (see Rationale). niri-flake's KDE polkit agent disappears too, which retires part of why `home/nixos/polkit-agent.nix` exists.

**Config layer — plain data, authored as KDL nodes (ruling 1 + 2).** `programs.niri.settings` and its 3785-line option tree are not reproduced. niri config becomes an ordinary Nix expression built from KDL node constructors — `plain "layout" [ (leaf "gaps" 16) ]` rather than `layout.gaps = 16` — serialized by a vendored copy of niri-flake's `kdl.nix` (224 lines, MIT, self-contained: it takes only `lib`) at `lib/kdl.nix` with upstream attribution and licence retained. The rendered document is written to `~/.config/niri/config.kdl` via `xdg.configFile`.

This is a *smaller* vendored surface than it looks, and deliberately so: `kdl.nix` is the KDL writer only. The attrset→node mapper that would let us keep today's authoring shape lives separately in `settings.nix` (`render`, from :3297, ~490 lines) and is niri-schema-specific — taking it would reintroduce the schema-mirror maintenance that ruling 1 rejected. Authoring as nodes means a new niri config key is a new node, not a schema extension.

**Keybind registry.** `lib/capabilities.nix`'s niri emitter (`niriBindsFor`, :1092) currently produces `{ "<chord>" = { action = { focus-column-left = {}; }; }; }`. It emits KDL nodes instead. The unit tests in `lib/tests/capabilities.nix` move with it. The emitter is Linux-only, so the AeroSpace/Darwin path is untouched; `kdl.nix` takes only `lib`, so it composes with the repo-decoupled constraint ADR-039 §9 places on that file.

**The theme-menu include.** Today `home/nixos/niri.nix:86-91` reaches *through* niri-flake's option default — `settings.render cfg.settings` — serializes it, and appends `include optional=true "~/.local/state/theme-menu/niri.kdl"`. That contortion exists only because niri-flake owns the rendering. Under this design we own the document, so the include is simply the last node appended to it. `optional=true` still requires niri 26.04, which is satisfied (see De-risk evidence).

**Validation (force 5).** `niri validate` runs over the generated `config.kdl` in a derivation that the home-manager configuration depends on, so a bad config fails the build — locally at `nh os switch` and in CI alike — rather than surfacing at session start. This is what replaces the eval-time name checking the typed surface gave: a misspelled key becomes a build failure instead of an eval failure. The diagnostic points at generated KDL rather than a Nix line, which is the accepted cost of ruling 1.

**Version cadence (ruling 3).** niri rides nixpkgs' cadence with no bespoke pin; the weekly bump carries it. `niri validate` is the guard rather than a pin — a release with breaking KDL syntax becomes a failed build, which is the same protection niri-flake gave and the same failure mode we want. A release that changes *semantics* without changing syntax passes validate and would surface as behaviour on alcyone; no route protects against that, and a pin would only delay it.

**How this meets the forces.** Forces 1–3 are met by construction: no flake input remains, no cache key replaces the one dropped, and every remaining failure mode is in code this repo owns. Force 4 is a build-and-verify claim, discharged at stage 7 on alcyone, not asserted here. Force 5 is met by the validate derivation — conditional on the one assumption still untested below.

## De-risk evidence

**Verified 2026-08-12** (this session, against the pinned inputs):

- **nixpkgs ships `niri-26.04`** — `nix eval .#nixosConfigurations.alcyone.pkgs.niri.version`. This is the version floor `include optional=true` requires, and it clears the note's largest open risk. It is also *better* than the status quo: `modules/nixos/niri.nix:46-53` currently reaches for niri-flake's `niri-unstable` slot precisely because its stable slot is still 25.08.
- **`kdl.nix` is self-contained and MIT.** 224 lines; `grep` for `import`, `pkgs`, `inputs`, or relative paths returns nothing — its only argument is `lib`. Licence: MIT, Copyright (c) 2024 sodiboo. Vendoring it carries no transitive dependency.
- **The schema mapper is separate and large.** `settings.nix` is 3785 lines; `render` begins at :3297 and is niri-schema-specific. This is the measurement that decided ruling 2 against keeping today's authoring shape.
- **niri-flake is already consumed as a library, not just a module** — `home/nixos/niri.nix:87` calls `inputs.niri-flake.lib.kdl.serialize.nodes` directly on the option's default. The migration formalises a coupling that already exists rather than introducing one.
- **The nixpkgs module's contents** were read directly from the pinned nixpkgs (`nixos/modules/programs/wayland/niri.nix`): it provides `services.displayManager.sessionPackages`, `systemd.packages`, the `systemd.user.services.niri` drop-in with `enableDefaultPath = false`, the full `xdg.portal` config with `xdg-desktop-portal-gnome`, `wayland-session.nix`, and `services.gnome.gnome-keyring.enable` — the last being what `modules/nixos/libsecret.nix` documents as inherited from niri-flake. Its option surface is only `enable`, `package`, `useNautilus`.
- **Consumer surface** enumerated by grep: `home/nixos/niri.nix` (384 lines), `home/nixos/niri-laptop.nix` (37), `modules/nixos/niri.nix` (111), the niri emitter in `lib/capabilities.nix`, plus side-effect dependents `greetd.nix`, `libsecret.nix`, `xdg-portal.nix`, `polkit-agent.nix`, `pointer-icons.nix`, `theme-menu.nix`.

**Recorded in #763 but NOT re-verified here** — treat as claims, not findings: the niri-flake PR closures (#1849, #1850) and issue #1851; `libdisplay-info-sys`'s declared `>= 0.1.0, < 0.4.0` range and the 0.4 wall; the `epireyn` fork's output surface and cache.

**Still unverified, and load-bearing:**

- **That `niri validate` can run over generated config in a derivation** — force 5 rests on it entirely. This is the stage-4 de-risk and should be tested before any module is rewritten. A negative result does not kill the direction but does force a different validation story.
- Whether nixpkgs' `withScreencastSupport` default matches what the desktop bundle needs.
- Whether anything else in the tree forces niri-flake's package set once the input is removed.
- Whether `niri validate` accepts a config containing an `include` of a file that does not exist at build time (the theme-menu include is `optional=true`, but validate's behaviour on it is unconfirmed).

## Drawbacks

The strongest argument against this direction is that it converts a maintained-by-someone-else surface into a maintained-by-us one. The KDL serializer and the config's structural correctness become this repo's problem, and the compositor config is not a place where a subtle regression is cheap.

Authoring as KDL nodes is more verbose than the attrset form and less familiar to read. `home/nixos/niri.nix` is the most-edited desktop module in the repo; every future edit pays a small legibility tax so that no future niri release costs a schema migration.

The change lands on the login path for both remaining graphical hosts. A wrong session entry means greetd offers nothing and recovery is the physical console at alcyone.

One drawback anticipated at stage 2 has been **refuted rather than accepted**: the worry that nixpkgs' niri would lag the 26.04 line the theming include needs. It does not — nixpkgs is at 26.04 while niri-flake's own stable slot is at 25.08.

## Cost

Standing price once chosen: this repo owns `lib/kdl.nix` (224 vendored lines) and the node-shaped authoring of niri config permanently. A niri release that changes KDL syntax becomes our migration to absorb rather than an upstream flake bump — though `niri validate` makes that arrive as a failed build rather than a broken desktop.

The eval-time diagnostic is permanently worse: a misspelled key is caught by `niri validate` against generated KDL, not by the module system against a Nix line. Accepted knowingly under ruling 1.

## Rationale & alternatives

The route was ruled by the operator on 2026-08-11: **no posture that keeps this repo reliant on an abandoned flake**, with the additional effort accepted explicitly. Against the forces:

- **Migrate to `epireyn/niri-flake`** — fails force 2. It substitutes one single-maintainer flake for another whose recent commits are almost entirely bot lockfile updates, and swaps `niri.cachix.org` for a newer, less-proven single-maintainer cache. Same dependency shape, same failure available later.
- **Wait for upstream** — fails force 3. The fix has been written twice and closed twice with no maintainer response; there is no event to wait for.
- **Carry a local patch or overlay** — fails force 1 as a destination. The flake stays and we pin ourselves to patching someone else's stale assert indefinitely. Viable only as a stopgap.
- **Package from nixpkgs, retain niri-flake for its modules** (#763's original reading of route (a)) — fails force 1. The unmaintained input remains load-bearing for the config surface; the gate is narrowed, not removed.

Within the chosen route, three sub-decisions were weighed:

- **Keep a typed option surface** (vendor `settings.nix`'s option tree) — rejected. It is the largest and fastest-moving part of niri-flake and duplicates what `niri validate` checks authoritatively. Owning a schema mirror means re-chasing every niri release; owning a serializer does not.
- **Vendor `kdl.nix` + `render` and keep the attrset authoring shape** — rejected as internally inconsistent. It re-imports the schema-mirror maintenance the first ruling rejected, through the back door: a new niri key would need `render` extended.
- **Write our own serializer** — rejected. It re-derives the same 224 lines including the subtle parts (escaping, int-versus-float stringification — the reason today's config coerces corner radii with `+ 0.0`, properties-versus-arguments folding) for no compensating benefit over vendoring MIT code from a frozen upstream.
- **Pin niri explicitly rather than ride nixpkgs' cadence** — rejected. It reintroduces a bespoke pin, a smaller version of what is being removed, and buys delay rather than safety once build-time validation is in place.

Vendoring is normally objectionable because it forks from a moving upstream. That objection does not apply here: upstream has stopped merging, so there is no divergence to track.

**Doing nothing** leaves the weekly bump failing every Monday and #770 blocked behind it.

#763's decision 2 resolves as a consequence rather than a separate choice: `niri.cachix.org` is **dropped, not replaced**, and the explicit trust delegation at `modules/nixos/niri.nix:57-67` goes with it — one fewer single-maintainer cache key under the whitelist-over-blanket stance (relates #579 / #568).

## Prior art

niri-flake's own README, and the fork's, name `programs.niri.package = pkgs.niri;` as the supported escape hatch for operators who do not want the maintainer's cache — the migration path is one upstream anticipated, even if it does not cover the settings surface.

This repo has already rendered KDL from Nix without niri-flake: `home/nixos/theme-menu.nix` emits `niri-{dark,light}.kdl` artefacts consumed through the conductor's include. That is a working precedent at smaller scale, and its flat colour blocks are what showed a hand-rolled renderer would not generalise to the full config.

The closest procedural precedent in-tree is [`docs/research/noctalia-v5-native-theming.md`](../research/noctalia-v5-native-theming.md): a source-level audit of a pinned upstream whose §4 finding was accurate at its pin and wrong three weeks later. Every upstream claim in this note is therefore dated, and the ones carried from #763 are flagged as un-re-verified rather than absorbed.

## Unresolved questions

**Loop state (dialogue-centric; the loop stays open through implementation and runtime validation, not closed at this note).**

- **Stage 1 — Intent: agreed.** Scoped to niri only, abandoned-flake framing, no generalised stance about other inputs.
- **Stage 2 — Size: heavy loop, full note.** Login-path surface, two hosts. **VM rehearsal ruled out** (2026-08-12): alcyone has a physical console attached, and a VM could only have proven the boot-to-login path anyway, never GPU behaviour or alnair's laptop specifics.
- **Stage 3 — Design: ruled.** Questions 1 (plain data over typed surface), 2 (vendor `kdl.nix` only, author as nodes), 3 (nixpkgs cadence, validate as guard).
- **Stage 4 — De-risk: next.** The `niri validate`-in-a-derivation assumption above.
- **Stages 5–7** — build, peer review, reconcile + runtime validation on alcyone: not started.

**Deferred from #763:** whether this crosses the `selecting-tooling` threshold (its decision 4). It reads as a sourcing change for an already-selected tool rather than a tool selection, so the working assumption is no; revisit if the build says otherwise.

**Expected to resolve at implementation:** where the vendored serializer lives and how its attribution is recorded; whether `home/nixos/niri-laptop.nix`'s merge survives unchanged under node authoring; how much of `polkit-agent.nix`'s rationale is retired with niri-flake's KDE agent.

**Out of scope:** any other flake input, the compositor selection itself (ADR-029 stands), and what niri does functionally.

## Future possibilities

If the node-authoring shape proves comfortable, the vendored serializer is a candidate for a proper `lib/` unit with its own tests alongside the existing constructors — or for upstreaming to nixpkgs' niri module, which today has no settings surface at all and would be the natural home for one.

Removing the input also simplifies the #770 theming decision: with `config.kdl` unambiguously owned by this repo, the question of whether Noctalia's niri template can append its `include` line has a definite answer rather than an inferred one.
