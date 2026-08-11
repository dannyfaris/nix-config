# niri sourcing — off the abandoned flake, onto the maintained fork

**Status:** Accepted — design note (`docs/design/`). Built; **not yet activated** — no host has run a session from it, so the runtime claim below is undischarged. [#763](https://github.com/dannyfaris/nix-config/issues/763) · amends [ADR-028](../decisions/ADR-028-stylix-foundation-and-desktop-env.md) slice 3b.5 (the `niri.cachix.org` whitelist, now retired) · relates [ADR-029](../decisions/ADR-029-niri-only-desktop.md) (niri-only desktop, unchanged) and [#770](https://github.com/dannyfaris/nix-config/issues/770).

## Summary

niri reached this fleet through `sodiboo/niri-flake`, which stopped merging: its stale `libdisplay-info_0_2` assert broke every weekly lockfile bump fleet-wide. The fix is to take the **maintained, upstream-blessed fork** `epireyn/niri-flake` for the module, and **nixpkgs for the niri binary** — which retires the `niri.cachix.org` trust delegation entirely rather than replacing it with the fork's. Three files of real change. A more radical route (own the config outright, vendor the KDL serializer, remove the flake dependency altogether) was designed, built and measured before being set aside; it is preserved on a branch and described under Rationale.

## Motivation

nixpkgs removed `libdisplay-info_0_2` (alias throw dated 2026-08-04). niri-flake's `make-niri` still asserts that exact version, and `flake.nix` set `niri-flake.inputs.nixpkgs.follows = "nixpkgs"`, so niri built against our bumped nixpkgs where the attribute throws. PR [#761](https://github.com/dannyfaris/nix-config/pull/761) failed on both systems and was closed unmerged; the failure recurs on every bump.

Upstream is not coming back: two contributors sent the fix (niri-flake PRs #1849, #1850), both closed unmerged, with no maintainer response on the bug report.

The blast radius is disproportionate to the defect. One stalled third-party repo held the whole fleet's nixpkgs freshness hostage, because a single input that `follows` our nixpkgs can veto every host's bump.

**Forces:**

1. **The weekly bump cannot stay blocked** by a third party's unmerged PR.
2. **No new trust delegation as the price of the fix.** Swapping one single-maintainer cachix key for another is a deferral, not a fix.
3. **Desktop capability preserved end to end** on both niri hosts — compositor starts, greetd offers the session, the theme-menu include resolves, screencast works.
4. **Config validation survives.** Whatever lands must keep catching a bad `config.kdl` before it reaches a host.
5. **Proportionate.** The repo's own stance is the lightest mechanism that holds the guarantee ([ADR-032](../decisions/ADR-032-proportionate-enforcement-and-rationale.md)).

**Target hosts: alcyone and alnair** — the only niri hosts since metis retired (#387).

## Design

**The input moves to `epireyn/niri-flake`.** One line in `flake.nix`. The fork carries the `libdisplay-info_0_3` fix, is actively maintained (32 of its last 100 commits are human, four contributors), and is blessed by the original maintainer — sodiboo pinned the fork's announcement, [sodiboo/niri-flake#1813](https://github.com/sodiboo/niri-flake/issues/1813), in the upstream repo. Its module surface is a drop-in: verified by a full source diff, only `flake.nix` and `settings.nix` differ materially from the pinned original, and the rendered `config.kdl` is byte-identical on both hosts.

**The package comes from nixpkgs, not the flake** — `programs.niri.package = pkgs.niri`. This is what keeps the dependency to eval-time module code with no binary and no signing key behind it, and it is why force 2 is met rather than deferred. Two consequences, both deliberate:

- **niri moves from master snapshots to the 26.04 release line.** The repo tracked niri-flake's `niri-unstable` only because its `stable` slot sat at 25.08 while `include optional=true` — the directive the theme conductor needs (ADR-044) — landed in 26.04. nixpkgs shipping 26.04 retires that reason. The cost is ~45 upstream commits between the release (2026-04-25) and the previously-pinned master snapshot (`feb3e43`, 2026-08-02): mostly wiki, tablet-stylus work and max-bpc features, plus one fix on this repo's path (an orphaned shell from `niri-session`) and a pipewire 0.10 bump behind screencast. No security or crash fixes. Release-line tracking is the better posture for a daily driver, and the next release arrives through the ordinary nixpkgs bump.
- **No binary cache is needed at all.** `cache.nixos.org` already serves `pkgs.niri`, so the `niri.cachix.org` substituter and trusted key retire from `modules/nixos/niri.nix`, `.github/workflows/ci.yaml` and `docs/ci.md` without replacement.

**`niri-flake.cache.enable = false` stays, and is now load-bearing rather than vestigial.** The option defaults to *true* upstream; deleting it alongside the substituter block would have the fork silently add `niri-epireyn.cachix.org` and its signing key to every host importing the module — re-taking the exact delegation this change removes, under a new name. This was caught in adversarial review, not by design.

**Validation is unchanged and still gates the build.** niri-flake's `validated-config-for` runs `cfg.package`'s own `niri validate` at build time; with the package now being the one that actually runs, validation and runtime share a binary.

**How the forces are met.** 1 and 2 by construction. 4 by the unchanged validate gate. 5 is the headline: three files of real change. Force 3 is a runtime claim and is **not** discharged by this note — see below.

## De-risk evidence

**Verified 2026-08-12** against the pinned inputs, on this branch:

- **The fork evaluates and builds** — alcyone and alnair toplevels both build; `nix flake check` passes.
- **`pkgs.niri` satisfies what the module reads off `cfg.package`.** The module forces `cargoBuildNoDefaultFeatures` and `cargoBuildFeatures` to gate the gnome portal (screencast); nixpkgs' niri carries both, with `[dbus, xdp-gnome-screencast, systemd]` — the same branch as before. `passthru.providedSessions = ["niri"]` is present, which is what feeds session discovery.
- **No trust leaked in.** Built `nix.settings.substituters` on alcyone is `["https://cache.nixos.org/"]` and `trusted-public-keys` is the nixos key alone. The fork's cachix did not appear, confirming `cache.enable = false` holds.
- **The rendered `config.kdl` is byte-identical** to the pre-change render on both hosts (`diff` clean), so no config surface moved.
- **The login path is intact in the built system:** `niri.desktop` (`Exec=niri-session`) present in the `desktops` derivation; `/etc/systemd/user/niri.service` linked with `ExecStart=…/niri-26.04/bin/niri --session` and the `overrides.conf` drop-in alongside, so the ADR-029 §67 stub-unit failure mode is absent.
- **niri 26.04 accepts `include optional=true`** with the target absent — warning, exit 0 — so the theme-menu include survives.

**Not verified — the residual:** nothing has been activated. greetd actually launching the session, the live compositor, screencast delivering frames, mate-polkit now unopposed, and alnair's touchpad are all unproven. Per the repo's set-≠-enforced stance ([#303](https://github.com/dannyfaris/nix-config/issues/303)) force 3 stays open until a session runs on both hosts.

## Drawbacks

The dependency shape is unchanged: a single-maintainer flake can still stall and block the bump again. This buys a maintained upstream, not immunity — and the fork is one person's continuation of a project that just demonstrated that failure mode.

Mixing the fork's module with nixpkgs' package is a combination neither upstream's CI exercises. Both READMEs name `programs.niri.package = pkgs.niri` as supported, and the fork's settings module already carries post-26.04 options; those are `nullable` and non-emitting today, but a future fork bump could emit config the 26.04 binary rejects. That surfaces as a failed build via the validate gate, which is the correct failure mode — expect the occasional lockfile-bump failure from this coupling, and treat it as a signal to pin, not to fork.

Release-line tracking means upstream fixes land months later than they did.

## Rationale & alternatives

- **Wait for upstream** — fails force 1. The fix was written twice and closed twice with no maintainer response.
- **Local patch or overlay** — keeps the dead flake and pins us to patching someone else's stale assert indefinitely.
- **`nix-wrapper-modules`** (birdee) — a real project, MIT, well-populated. Rejected: it is another third-party input whose niri module is a config-schema mirror maintained elsewhere, on a slower cadence than the fork, and it wraps the package with config baked in rather than writing `config.kdl` — which would need re-proving against the ADR-044 conductor's runtime include. Same trade, different owner.
- **Fork's own `niri-unstable` package** — keeps master-tracking, but reopens the cache question: adopt `niri-epireyn.cachix.org` (fails force 2) or build niri from source on both hosts and CI.

**Own the config outright — designed, built, and set aside.** The route that removes every third-party dependency for niri: nixpkgs' NixOS module, the KDL config surface owned here, niri-flake's `kdl.nix` vendored under its MIT licence, config authored as KDL nodes, `niri validate` wired into a derivation. It was ruled through the full design loop, de-risked, implemented in two slices, and reviewed — then not taken.

Two things decided it. First, #763's evidence about the fork was **wrong on two counts**: it called the fork "unblessed by sodiboo" and characterised it as "11 of its last 12 commits are bot lockfile updates". Both were corrected on 2026-08-12 after [@peedrr raised it](https://github.com/dannyfaris/nix-config/issues/763#issuecomment-5257916601). The stance that drove the design — *no posture that keeps us reliant on an abandoned flake* — was answering a premise that did not hold: the fork is neither abandoned nor unblessed. Second, once built, the two routes could be measured rather than estimated: **~41 files against ~3**. "Future-proof no matter the effort" is the right stance when the only alternative is an abandoned upstream; it stops being the right stance once a maintained one exists.

That work is preserved on the **`design/niri-sourcing`** branch — both slices, green, with its own design note. It is a costed, working escape hatch: if the fork stalls, it is a rebase away rather than a redesign. It has never been activated, so it would need a runtime rehearsal before it could be trusted.

**Doing nothing** leaves the weekly bump failing every Monday and #770 blocked behind it.

## Prior art

Both niri-flake's README and the fork's name `programs.niri.package = pkgs.niri` as the supported escape hatch for operators who do not want the maintainer's cache — the package/module split this change relies on is one upstream anticipated.

[`docs/research/noctalia-v5-native-theming.md`](../research/noctalia-v5-native-theming.md) is the procedural precedent: an upstream audit that was accurate at its pin and wrong three weeks later. The same lesson applies here in a sharper form — #763's fork evidence was wrong when written, and went unchallenged into a design decision. Upstream claims in this note are dated for that reason.

## Unresolved questions

**Runtime validation on alcyone then alnair** — greetd offering and launching the session, the theme conductor's include resolving and `theme` reloading, screencast delivering frames, mate-polkit unopposed, alnair's touchpad. Alcyone first because it has the physical console; alnair second because it is the host whose laptop-specific config is exercised.

**Whether the fork stays healthy** is the standing bet. The trigger to revisit is the same failure that started this: a bump blocked on an unmerged upstream fix. The answer then is the parked branch, not another evaluation.

**Retro owed** on how the route-C effort was reached before the alternatives were measured (operator request, 2026-08-12).

## Future possibilities

If the fork accumulates enough divergence to be its own project, the calculus does not change — the dependency is eval-time module code with no binary behind it, which is the cheapest form this can take short of owning the config.

If niri's config schema ever moves faster than nixpkgs' release cadence can follow, the parked branch's node-authoring approach becomes the natural answer, since it decouples the config surface from anyone else's schema mirror.
