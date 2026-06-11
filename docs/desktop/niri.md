# Niri

Wayland compositor. Scrollable-tiling paradigm — windows arrange in a
horizontal strip; you scroll the workspace to bring different sections
into view.

## Selection

**niri 25.08** (the `niri-stable` channel from
[`niri-flake`](https://github.com/sodiboo/niri-flake)) on metis.
Enabled at the system layer via `modules/nixos/niri.nix`; user
settings (binds, layout) at `home/nixos/niri.nix` via niri-flake's
auto-injected `homeModules.config`.

## Rationale

**Scrollable-tiling fits the operator's workflow.** Traditional tilers
(sway, river) carve the screen into bsp/manual tiles; the layout
reflows when a new window opens. Niri's scroll-the-workspace model
means the existing layout never reflows — a new window slots to the
right and the rest of the workspace stays put. For the operator's
pattern of running 3–6 tasks side-by-side and occasionally spinning up
a new context, the no-reflow behaviour is meaningful.

**Recent, actively maintained, narrowly scoped.** niri's author
(YaLTeR) ships releases regularly. The codebase deliberately avoids
feature creep common to larger compositors — no extensions, no
scripting layer, no plugin manifest. The narrow scope means fewer
breaking changes per upgrade.

**`niri-flake` provides the NixOS integration.** sodiboo's niri-flake
gives us the package + nixosModule + homeModules-based settings
interface. Sharp edges discovered (see below) but the integration
works and is in active development.

## Alternatives considered

**sway** — mature, well-supported in NixOS. Traditional bsp tiling.
Passed over because reflow-on-new-window fights the operator's pattern
of spinning up new contexts without disturbing existing layout.

**river** — manual tiling with scriptable layout-engine. More flexible
than sway; passed over because the layout-as-external-script cognitive
surface didn't earn its keep for a solo-user setup.

**Hyprland** — popular, feature-rich, animations + effects. Passed
over because the feature surface is much larger than we'd exercise.
The minimal niri model + clean NixOS integration outweighs Hyprland's
polish for our use.

## Configuration

**System layer** — `modules/nixos/niri.nix`:
- Imports `inputs.niri-flake.nixosModules.niri` and enables
  `programs.niri.enable = true`.
- Owns the cachix trust delegation explicitly
  (`niri-flake.cache.enable = false`; `nix.settings.substituters` +
  `trusted-public-keys` carry `niri.cachix.org` deliberately per
  CLAUDE.md's "whitelist > blanket" stance).
- Registers niri's package-shipped systemd user units via
  `systemd.packages = [ config.programs.niri.package ]`. Load-bearing
  — without it, niri.service is invisible to systemd-user. See sharp
  edges.

**User layer** — `home/nixos/niri.nix`:
- Sets `programs.niri.settings.binds` directly. Full bind taxonomy +
  modifier-namespace philosophy lives in [keybinds.md](./keybinds.md).
- Deliberate layout/decoration overrides: `prefer-no-csd = true` (niri
  draws its own focus-ring border instead of clients' titlebars —
  wasted space when tiling) and `layout.default-column-width =
  proportion 0.66` (new windows open at two-thirds; niri otherwise
  honours each client's preferred size, which opened foot narrow at its
  ~80×24 default). Remaining layout/input/cursor settings still flow
  from niri-flake defaults.

**Window decorations** — niri is a whitelisted Stylix target
(`stylix.targets.niri.enable = true` in
`home/nixos/stylix-targets-desktop.nix`). An earlier revision of this
doc claimed Stylix themed niri's focus-ring with no explicit target
enable; that was never true (#333). With the target enabled, Stylix
writes the window **border** — active `base0D` (the focus accent) /
inactive `base03` — and **disables the focus-ring**, so the
active-window accent rides the idiomatic `base0D` slot instead of
niri's built-in blue. On top of that, `home/nixos/niri.nix` sets
`layout.border.width = 2` (2px renders crisp on metis's 4K panel at
scale 1.5 — an even logical width maps to whole physical pixels) and a
catch-all `window-rule` with `geometry-corner-radius = 10` +
`clip-to-geometry = true` (rounded corners on every window, client
content trimmed to the rounded rect). The focus/attention colour
vocabulary is defined in the visual-identity north-star (#108); cursor
theme/size cohesion (`stylix.cursor`) remains unwired (#110).

## Sharp edges

**niri-flake's nixosModule doesn't register systemd user units.** The
niri package ships `niri.service` + `niri-shutdown.target` at
`$out/{lib,share}/systemd/user/`, but niri-flake's nixosModule
installs the package via `environment.systemPackages` *only* — no
`systemd.packages = [ cfg.package ]`. Without that wire, systemd-user
never sees the units; greetd → niri-session line 47
(`systemctl --user --wait start niri.service`) fails with "Unit not
found". This blocked the first metis activation
([#67](https://github.com/dannyfaris/nix-config/issues/67)) and was
resolved by [PR #68](https://github.com/dannyfaris/nix-config/pull/68)
(the `systemd.packages` line above). niri-flake's README claims
*"The niri package will be installed, including its systemd units"*
— overstates the module's behaviour. Potential upstream report.

**Niri does NOT merge user config with `default-config.kdl`.** When
`programs.niri.settings.binds` is set at all, niri's 60+ default binds
are **replaced wholesale**, not layered. This is a niri design choice,
not a niri-flake limitation. The bind set must be curated explicitly —
there is no "use defaults plus my additions" mode. This shaped the
curated essential set documented in [keybinds.md](./keybinds.md).

**The `include` directive is unsupported in niri 25.08.** Documenting
the historical gotcha: DMS's HM module generated `include
"hm.kdl"`-style directives expecting niri to parse them; niri 25.08
returns `unexpected node include`. niri-flake's PR #1548 (unmerged)
plans to add support; meanwhile, DMS's approach was untenable for our
niri pin. Captured in
[ADR-029](../decisions/ADR-029-niri-only-desktop.md) §Context.

**Trust delegation for `niri.cachix.org`.** niri-flake's default
(`niri-flake.cache.enable = true`) would silently add the substituter
to `nix.settings`. We override to `false` and add the substituter +
trusted-public-key explicitly so the trust delegation is recorded in
source, dated, and revokable in one place. The substituter is
necessary in practice — without it, niri rebuilds from source on every
niri-flake bump (~10–30 min on metis-class hardware), and the nixpkgs
Rust-crate fetcher has been unreliable with crates.io 403 cascades.
See `modules/nixos/niri.nix:7-32` for the inline rationale.

## References

- [ADR-027](../decisions/ADR-027-foundation-and-bundles.md) —
  foundation + bundles model.
- [ADR-028](../decisions/ADR-028-stylix-foundation-and-desktop-env.md) —
  Stylix foundation; bundle composition; metis as first desktop host.
  Items 1–2 stand; item 3 retracted by ADR-029.
- [ADR-029](../decisions/ADR-029-niri-only-desktop.md) — formal record
  of the niri-only direction after the DMS retraction.
- [#67](https://github.com/dannyfaris/nix-config/issues/67) — the
  slice-5 incident (niri.service stub).
- [PR #68](https://github.com/dannyfaris/nix-config/pull/68) — the
  niri-flake systemd-units fix.
- [#69](https://github.com/dannyfaris/nix-config/issues/69) — the
  niri-only baseline close-out (all five acceptance criteria met).
- [keybinds.md](./keybinds.md) — bind taxonomy that depends on niri's
  no-merge-with-defaults behaviour.
- [fonts.md](./fonts.md) — font installation model; niri's chrome
  participates in the Stylix flow.
- niri upstream — https://github.com/niri-wm/niri
- niri-flake — https://github.com/sodiboo/niri-flake
