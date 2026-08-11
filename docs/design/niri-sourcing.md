# niri sourcing after niri-flake — taking the compositor off an abandoned dependency

**Status:** **Superseded — parked, not landed.** Design note (`docs/design/`). Both slices are built and green here, but this route was NOT taken: #763 landed route A instead (the blessed `epireyn/niri-flake` fork with `pkgs.niri`), on evidence that arrived after this design was ruled. **This branch has never been activated on a host** — it is preserved as a costed, working alternative should the fork stall. See §Rationale for why the decision reversed. [#763](https://github.com/dannyfaris/nix-config/issues/763)

## Summary

niri reaches this fleet through `sodiboo/niri-flake`, a third-party flake that is no longer maintained, and that dependency has become a gate rather than a conduit: it blocks the weekly lockfile bump fleet-wide, blocks a mechanism decision in #770, and carries a single-maintainer binary-cache trust delegation that was never chosen on merit. This note removes the dependency outright — niri and its NixOS module from nixpkgs, and the KDL config surface owned by this repo as plain data rendered through a vendored 151-line MIT serializer. The typed `programs.niri.settings` option tree is deliberately not reproduced; `niri validate` at build time replaces what it guarded.

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

Three forks were ruled in operator dialogue on 2026-08-12; the mechanism follows from them. This section is written as designed, with **as-built** notes where the implementation (slices A and B, 2026-08-12) taught the design something.

**System layer — nixpkgs, wholesale.** `modules/nixos/niri.nix` takes nixpkgs' `programs.niri` module instead of niri-flake's nixosModule, and `pkgs.niri` as the package. The nixpkgs module supplies the side effects this repo inherits rather than re-asserts: the session package greetd reads, `systemd.packages` plus the `systemd.user.services.niri` drop-in, the `xdg.portal` config including `xdg-desktop-portal-gnome` for screencast, `wayland-session.nix`, and `gnome-keyring.enable`. The `niri-flake` input leaves `flake.nix`, and with it the `niri.cachix.org` substituter and trusted key on both the hosts and the CI runner (see Rationale). niri-flake's KDE polkit agent goes too, which retires part of why `home/nixos/polkit-agent.nix` exists. **As built:** the module needs no `imports` line at all — nixpkgs' `programs.niri` is already in NixOS's default module list — so `modules/nixos/niri.nix` is two options and its comment block. `home/nixos/polkit-agent.nix` survives with its selection intact but its framing inverted: mate-polkit is now the session's *only* agent rather than a replacement for one, because nixpkgs' module runs none.

**Config layer — plain data, authored as KDL nodes (ruling 1 + 2).** `programs.niri.settings` and its 3785-line option tree are not reproduced. niri config becomes an ordinary Nix expression built from KDL node constructors — `plain "layout" [ (leaf "gaps" 16) ]` rather than `layout.gaps = 16` — serialized by a vendored copy of niri-flake's `kdl.nix` (upstream 224 lines; 151 as vendored — MIT, self-contained: it takes only `lib`) at `lib/kdl.nix` with upstream attribution and licence retained. The rendered document is written to `~/.config/niri/config.kdl` via `xdg.configFile`.

This is a *smaller* vendored surface than it looks, and deliberately so: `kdl.nix` is the KDL writer only. The attrset→node mapper that would let us keep today's authoring shape lives separately in `settings.nix` (`render`, from :3297, ~490 lines) and is niri-schema-specific — taking it would reintroduce the schema-mirror maintenance that ruling 1 rejected. Authoring as nodes means a new niri config key is a new node, not a schema extension.

**Keybind registry.** `lib/capabilities.nix`'s niri emitter (`niriBindsFor`, :1092) produced `{ "<chord>" = { action = { focus-column-left = {}; }; }; }`. It emits KDL nodes instead. The unit tests in `lib/tests/capabilities.nix` move with it. The emitter is Linux-only, so the AeroSpace/Darwin path is untouched; `kdl.nix` takes only `lib`, so it composes with the repo-decoupled constraint ADR-039 §9 places on that file. **As built:** slice A added `niriBindNodesFor` / `niriBindNodes` alongside the attrset pair, slice B deleted the attrset pair and its one test (`testNiriBindsShape`) after grepping the whole tree — not just `*.nix` — for surviving consumers. `isNiriAction` is shared by both emitters and stayed.

**The theme-menu include.** Before this change `home/nixos/niri.nix:86-91` reached *through* niri-flake's option default — `settings.render cfg.settings` — serialized it, and appended `include optional=true "~/.local/state/theme-menu/niri.kdl"`. That contortion existed only because niri-flake owned the rendering. Under this design we own the document, so the include is simply the last node of it. `optional=true` still requires niri 26.04, which is satisfied (see De-risk evidence).

**Validation (force 5).** `niri validate` runs over the generated `config.kdl` in a derivation that the home-manager configuration depends on, so a bad config fails the build — locally at `nh os switch` and in CI alike — rather than surfacing at session start. This is what replaces the eval-time name checking the typed surface gave: a misspelled key becomes a build failure instead of an eval failure. The diagnostic points at generated KDL rather than a Nix line, which is the accepted cost of ruling 1. **As built:** the dependency is not a side gate but the file itself — `xdg.configFile."niri/config.kdl".source` *is* the validating derivation, so there is no path by which an unvalidated document reaches a host. The derivation copies the text to a file literally named `config.kdl` before validating, per the stage-4 finding that the diagnostic cites whatever path it was handed.

**Version cadence (ruling 3).** niri rides nixpkgs' cadence with no bespoke pin; the weekly bump carries it. `niri validate` is the guard rather than a pin — a release with breaking KDL syntax becomes a failed build, which is the same protection niri-flake gave and the same failure mode we want. A release that changes *semantics* without changing syntax passes validate and would surface as behaviour on alcyone; no route protects against that, and a pin would only delay it.

**How this meets the forces.** Forces 1–3 are met by construction and confirmed by the built tree: no flake input remains, no cache key replaces the one dropped, and every remaining failure mode is in code this repo owns. Force 5 is met by the validate derivation, tested at stage 4 and confirmed to fail closed. **Force 4 is not met yet and must not be read as met.** It is a runtime claim — the compositor starts, greetd offers the session, the theme-menu include resolves, screencast works — and nothing has been activated on either host. Everything recorded here is eval and build evidence; CLAUDE.md's set-≠-enforced rule (#303) applies in full until alcyone and alnair have each logged in.

## De-risk evidence

**Verified 2026-08-12** (this session, against the pinned inputs):

- **nixpkgs ships `niri-26.04`** — `nix eval .#nixosConfigurations.alcyone.pkgs.niri.version`. This is the version floor `include optional=true` requires, and it clears the note's largest open risk. It is also *better* than the status quo it replaced: `modules/nixos/niri.nix` then reached for niri-flake's `niri-unstable` slot precisely because its stable slot was still 25.08.
- **`kdl.nix` is self-contained and MIT.** 224 lines upstream; `grep` for `import`, `pkgs`, `inputs`, or relative paths returns nothing — its only argument is `lib`. Licence: MIT, Copyright (c) 2024 sodiboo. Vendoring it carries no transitive dependency. **As vendored it is 151 lines:** upstream's `types` block (:109-203) and its export are omitted, since those exist solely to give `programs.niri.settings` its typed option surface — the thing ruling 1 rejects — and `serialize` has no dependency on them. `node`, `plain`, `leaf`, `flag` and `serialize` are byte-identical to upstream.
- **The schema mapper is separate and large.** `settings.nix` is 3785 lines; `render` begins at :3297 and is niri-schema-specific. This is the measurement that decided ruling 2 against keeping today's authoring shape.
- **niri-flake is already consumed as a library, not just a module** — `home/nixos/niri.nix:87` calls `inputs.niri-flake.lib.kdl.serialize.nodes` directly on the option's default. The migration formalises a coupling that already exists rather than introducing one.
- **The nixpkgs module's contents** were read directly from the pinned nixpkgs (`nixos/modules/programs/wayland/niri.nix`): it provides `services.displayManager.sessionPackages`, `systemd.packages`, the `systemd.user.services.niri` drop-in with `enableDefaultPath = false`, the full `xdg.portal` config with `xdg-desktop-portal-gnome`, `wayland-session.nix`, and `services.gnome.gnome-keyring.enable` — the last being what `modules/nixos/libsecret.nix` documents as inherited from niri-flake. Its option surface is only `enable`, `package`, `useNautilus`.
- **Consumer surface** enumerated by grep: `home/nixos/niri.nix` (384 lines), `home/nixos/niri-laptop.nix` (37), `modules/nixos/niri.nix` (111), the niri emitter in `lib/capabilities.nix`, plus side-effect dependents `greetd.nix`, `libsecret.nix`, `xdg-portal.nix`, `polkit-agent.nix`, `pointer-icons.nix`, `theme-menu.nix`. **Corrected 2026-08-12 (slice B recon):** this split understated two of them. `home/nixos/pointer-icons.nix` was not a side-effect dependent but an active *writer* of `programs.niri.settings.cursor`, so it would have failed to evaluate the moment the option vanished; its two values are now threaded into the document instead. And `home/nixos/theme-menu.nix` read `config.programs.niri.package` for its `load-config-file` call, which likewise ceased to exist.

**Recorded in #763 but NOT re-verified here** — treat as claims, not findings: the niri-flake PR closures (#1849, #1850) and issue #1851; `libdisplay-info-sys`'s declared `>= 0.1.0, < 0.4.0` range and the 0.4 wall; the `epireyn` fork's output surface and cache (its maintenance status and blessing HAVE since been verified — see Rationale).

**Stage-4 de-risk — force 5's assumption tested and HELD (2026-08-12).** Probed against the pinned niri (`/nix/store/y32xfvyx99qp91s2g3d2dr8wsx7k3gb0-niri-26.04`, confirmed identical to `inputs.nixpkgs.legacyPackages.x86_64-linux.niri`):

- **`niri validate` runs headless and in the Nix build sandbox.** A `runCommand` with `niri` in `nativeBuildInputs`, validating a config passed via `passAsFile`, builds successfully. No Wayland socket, DRM device, or display is required.
- **The gate fails closed.** The same derivation with one character changed (`gaps` → `gpas`) fails the build with exit 1 and the parse diagnostic in the build log. This is the property force 5 needs: a bad config cannot reach a host.
- **Coverage is broader than the design assumed.** Validate rejects unknown nodes (`layuot` → `` unexpected node `layuot` ``), misspelled bind actions (`focus-column-lefft`), and wrong value types (`gaps "sixteen"`) — all exit 1. That is most of what the discarded typed surface would have caught, which strengthens ruling 1 rather than merely excusing it.
- **The `optional=true` theme-menu include is accepted with the target absent** — logged as `WARN optional include not found`, exit 0. The include can therefore be present in the validated document without the runtime file existing at build time.

**Implementation notes from the probe:** the diagnostic cites the file it was handed, so the derivation should copy the config to a meaningfully-named path before validating rather than passing `passAsFile`'s `.attr-…` temp name, or build errors will point at an opaque filename. Separately, niri's parser requires newline-separated nodes — a single-line `layout { gaps 16 }` is rejected — so the serializer's line breaking is load-bearing, not cosmetic. A missing trailing newline at end of file is fine.

**Both stage-4 open items are now answered — at build, 2026-08-12:**

- **`withScreencastSupport` defaults to `true`** in nixpkgs' `pkgs/by-name/ni/niri/package.nix` (`:24`), which is what adds `pipewire` to the build inputs and the `xdp-gnome-screencast` cargo feature (`:71`, `:78`). Nothing in the desktop bundle needs an override; the screencast chain is preserved end to end at the *declared* level (`docs/desktop/screen-sharing.md` carries the runtime acceptance test, which is still outstanding).
- **Nothing else in the tree forced niri-flake's package set.** With the input removed, `nix flake check --no-build` passes and both host toplevels build; the one indirect consumer, `home/nixos/theme-menu.nix`, took `pkgs.niri` — the same derivation `modules/nixos/niri.nix` installs, since home-manager runs with `useGlobalPkgs`.

**Still unverified — and this is the whole of what remains:** everything runtime. See the Status line and force 4 above.

## Drawbacks

The strongest argument against this direction is that it converts a maintained-by-someone-else surface into a maintained-by-us one. The KDL serializer and the config's structural correctness become this repo's problem, and the compositor config is not a place where a subtle regression is cheap.

Authoring as KDL nodes is more verbose than the attrset form and less familiar to read. `home/nixos/niri.nix` is the most-edited desktop module in the repo; every future edit pays a small legibility tax so that no future niri release costs a schema migration.

The change lands on the login path for both remaining graphical hosts. A wrong session entry means greetd offers nothing and recovery is the physical console at alcyone. This is the drawback the built-but-unverified state leaves live: the session entry was checked as hard as eval allows — both hosts resolve `services.displayManager.sessionData.desktops` to the same store path, holding exactly one `wayland-sessions/niri.desktop` with `Name=Niri` / `Exec=niri-session` / `DesktopNames=niri`, which is what tuigreet reads — but that is evidence about the file greetd will find, not that the session starts.

One drawback anticipated at stage 2 has been **refuted rather than accepted**: the worry that nixpkgs' niri would lag the 26.04 line the theming include needs. It does not — nixpkgs is at 26.04 while niri-flake's own stable slot is at 25.08.

## Cost

Standing price once chosen: this repo owns `lib/kdl.nix` (151 vendored lines) and the node-shaped authoring of niri config permanently. A niri release that changes KDL syntax becomes our migration to absorb rather than an upstream flake bump — though `niri validate` makes that arrive as a failed build rather than a broken desktop.

The eval-time diagnostic is permanently worse: a misspelled key is caught by `niri validate` against generated KDL, not by the module system against a Nix line. Accepted knowingly under ruling 1.

## Rationale & alternatives

The route was ruled by the operator on 2026-08-11: **no posture that keeps this repo reliant on an abandoned flake**, with the additional effort accepted explicitly. Against the forces:

- **Migrate to `epireyn/niri-flake`** — rejected on the dependency *shape*, and the record here has been corrected twice in its favour. #763 called the fork "unblessed by sodiboo" and characterised it as "11 of its last 12 commits are bot lockfile updates"; both are wrong, raised by [@peedrr on #763](https://github.com/dannyfaris/nix-config/issues/763#issuecomment-5257916601) and verified 2026-08-12. Issue [#1813](https://github.com/sodiboo/niri-flake/issues/1813) announcing the fork **is pinned** in `sodiboo/niri-flake` — pinning takes maintainer write access, so it reads as a deliberate handoff — and across the fork's last 100 commits 32 are human, from four contributors, with feature work as recent as 2026-08-07 and the `libdisplay-info_0_3` fix landed 2026-07-30. It is a healthy project and the pragmatic choice for most setups. It is rejected here anyway because it preserves the property this change exists to remove: a single upstream's availability gating every host's nixpkgs bump. That is a narrower claim than "the fork is unhealthy", and it does not depend on the fork being unhealthy.
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

#763's decision 2 resolves as a consequence rather than a separate choice: `niri.cachix.org` is **dropped, not replaced**, and the explicit trust delegation in `modules/nixos/niri.nix` went with it — as did the CI runner's mirror of the same substituter and key in `.github/workflows/ci.yaml`, which had no reason to outlive it. One fewer single-maintainer cache key under the whitelist-over-blanket stance (relates #579 / #568).

## Prior art

niri-flake's own README, and the fork's, name `programs.niri.package = pkgs.niri;` as the supported escape hatch for operators who do not want the maintainer's cache — the migration path is one upstream anticipated, even if it does not cover the settings surface.

This repo has already rendered KDL from Nix without niri-flake: `home/nixos/theme-menu.nix` emits `niri-{dark,light}.kdl` artefacts consumed through the conductor's include. That is a working precedent at smaller scale, and its flat colour blocks are what showed a hand-rolled renderer would not generalise to the full config.

The closest procedural precedent in-tree is [`docs/research/noctalia-v5-native-theming.md`](../research/noctalia-v5-native-theming.md): a source-level audit of a pinned upstream whose §4 finding was accurate at its pin and wrong three weeks later. Every upstream claim in this note is therefore dated, and the ones carried from #763 are flagged as un-re-verified rather than absorbed.

## Unresolved questions

**Loop state (dialogue-centric; the loop stays open through implementation and runtime validation, not closed at this note).**

- **Stage 1 — Intent: agreed.** Scoped to niri only, abandoned-flake framing, no generalised stance about other inputs.
- **Stage 2 — Size: heavy loop, full note.** Login-path surface, two hosts. **VM rehearsal ruled out** (2026-08-12): alcyone has a physical console attached, and a VM could only have proven the boot-to-login path anyway, never GPU behaviour or alnair's laptop specifics.
- **Stage 3 — Design: ruled.** Questions 1 (plain data over typed surface), 2 (vendor `kdl.nix` only, author as nodes), 3 (nixpkgs cadence, validate as guard).
- **Stage 4 — De-risk: done.** The `niri validate`-in-a-derivation assumption tested and held; coverage is broader than assumed (see De-risk evidence).
- **Stage 5 — Build, both slices: done (2026-08-12).** The build was sliced in two so the risky half is verified rather than hoped for. **Slice A (inert):** vendor the serializer, add a node-emitting bind function *alongside* the live one, and port the config document — while niri-flake kept generating the live config, so both could be rendered and diffed. Its inertness is proven, not asserted: alcyone's and alnair's toplevel `drvPath`s were byte-identical to a clean checkout of the preceding commit. **Slice B (the flip):** the nixpkgs module, the generated document behind the validate gate, `home/nixos/niri-laptop.nix` deleted, and the input, the cache delegation (host *and* CI) and the dead attrset emitter all removed. `nix flake check --no-build` passes and both hosts build.
- **Stage 6 — Peer review, slice A: done. Slice B: not yet reviewed.** Slice A ran four adversarial lenses (port correctness, inertness, licence/provenance, repo conventions), each finding independently refuted before reaching the operator. Eight major findings raised, all eight refuted; two of the nine minors were adjudicated as real and fixed — a one-action-per-bind guard restated in `lib/capabilities.nix` (the typed surface used to hold it, and a bare `mapAttrsToList` would have rendered a two-key payload as two children silently), and this note's own stale line counts. Slice B's diff has had no equivalent pass, and it is the half that touches the login path.
- **Stage 7 — runtime validation on alcyone and alnair: not started.** No activation has been run. Until it has, force 4 is undischarged and every claim above is eval or build evidence only. What stage 7 owes, at minimum: greetd offers the niri session and it starts on both hosts; the polkit dialog appears with mate-polkit now unopposed rather than competing — a state never observed live; the theme-menu `include` resolves and `theme` still reloads the config; screencast delivers frames; and alnair's touchpad still behaves, since its block moved file.

**Deferred from #763:** whether this crosses the `selecting-tooling` threshold (its decision 4). It reads as a sourcing change for an already-selected tool rather than a tool selection, so the working assumption is no; revisit if the build says otherwise.

**Ruled before slice B — alcyone's touchpad block: the drop is accepted (operator, 2026-08-12).** The rendered documents were equivalent on every setting except one: the old config emitted `input.touchpad { tap; natural-scroll }` on alcyone, and the node-form document does not. This was not a dropped niri default. niri's own `struct Touchpad` derives `Default` with no override, so niri defaults both to *false*; the flags were present only because niri-flake's option defaults were `true`. The ruling is that they were never a choice this repo made, and declaring settings for absent hardware is the implicitness this repo avoids — alcyone has no touchpad, and alnair declares its own block. The two flags are not to be re-added.

**Resolved at implementation:** `home/nixos/niri-laptop.nix` did **not** survive — it was a home-manager fragment whose only job was to merge a second `programs.niri.settings` attrset into the first, and with the document a single expression there is nothing left to merge into. It is deleted, its settings live in `lib/niri-config.nix` behind a `laptop` boolean, and the selector is a new `hostContext.laptop` option (`lib/mk-host-context.nix`, `true` on alnair only). `polkit-agent.nix`'s rationale was retired in *framing* rather than in substance: the module and the mate-polkit selection stand, the "replacing niri-flake's KDE agent" basis and the `niri-flake-polkit.enable = false` lever are gone, and `RestartSec = 1` kept its why (slow a crash-loop on the privilege-escalation path) minus its provenance. **Closed (operator-approved, 2026-08-12):** nothing evaluated `lib/niri-config.nix`, so an eval error in it would have gone unnoticed between the slices. `parts/checks.nix` now forces both host shapes to render (`niri-config-renders`, ADR-033's eval-check rung); confirmed to fail closed against an injected regression, not merely to pass today. That check keeps earning its keep after the flip for a different reason — each host build renders only the shape its own `laptop` flag selects, so without it a regression in the other branch reaches one host unseen.

**Left to the operator at acceptance:** whether this graduates to an ADR. It amends live rationale in two places — ADR-030's unstable-channel case names niri-flake as one of its two pillars, and ADR-036's pin-risk paragraph reasons about Noctalia lagging Quickshell "while niri-flake moves" — and ADRs are amended by ADRs, never edited (ADR-037). Deliberately not written here: the loop is still open through stage 7, and the freeze belongs at acceptance, not at build.

**Out of scope:** any other flake input, the compositor selection itself (ADR-029 stands), and what niri does functionally.

## Future possibilities

If the node-authoring shape proves comfortable, the vendored serializer is a candidate for a proper `lib/` unit with its own tests alongside the existing constructors — or for upstreaming to nixpkgs' niri module, which today has no settings surface at all and would be the natural home for one.

Removing the input also simplifies the #770 theming decision: with `config.kdl` unambiguously owned by this repo, the question of whether Noctalia's niri template can append its `include` line has a definite answer rather than an inferred one.
