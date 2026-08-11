# Niri

Wayland compositor. Scrollable-tiling paradigm — windows arrange in a horizontal strip; you scroll the workspace to bring different sections into view.

## Selection

**niri, sourced from nixpkgs** (`pkgs.niri`, 26.04 at the current pin) on the NixOS desktop hosts. Enabled at the system layer via `modules/nixos/niri.nix`, which turns on nixpkgs' own `programs.niri` module; user settings (binds, layout) at `home/nixos/niri.nix`. Until #763 both the package and the modules came from [`niri-flake`](https://github.com/sodiboo/niri-flake) — the sourcing change and its consequences are [docs/design/niri-sourcing.md](../design/niri-sourcing.md).

## Rationale

**Scrollable-tiling fits the operator's workflow.** Traditional tilers (sway, river) carve the screen into bsp/manual tiles; the layout reflows when a new window opens. Niri's scroll-the-workspace model means the existing layout never reflows — a new window slots to the right and the rest of the workspace stays put. For the operator's pattern of running 3–6 tasks side-by-side and occasionally spinning up a new context, the no-reflow behaviour is meaningful.

**Recent, actively maintained, narrowly scoped.** niri's author (YaLTeR) ships releases regularly. The codebase deliberately avoids feature creep common to larger compositors — no extensions, no scripting layer, no plugin manifest. The narrow scope means fewer breaking changes per upgrade.

**nixpkgs provides the NixOS integration.** `pkgs.niri` plus nixpkgs' `programs.niri` module give the package, the session entry, the systemd user units and the portal wiring. It carries no settings interface, which is deliberate — config.kdl is this repo's, gated by `niri validate` at build time. niri-flake filled that role until #763; why it stopped is [docs/design/niri-sourcing.md](../design/niri-sourcing.md).

## Alternatives considered

**sway** — mature, well-supported in NixOS. Traditional bsp tiling. Passed over because reflow-on-new-window fights the operator's pattern of spinning up new contexts without disturbing existing layout.

**river** — manual tiling with scriptable layout-engine. More flexible than sway; passed over because the layout-as-external-script cognitive surface didn't earn its keep for a solo-user setup.

**Hyprland** — popular, feature-rich, animations + effects. Passed over because the feature surface is much larger than we'd exercise. The minimal niri model + clean NixOS integration outweighs Hyprland's polish for our use.

## Configuration

**System layer** — `modules/nixos/niri.nix`:

- Enables `programs.niri` — nixpkgs' module, already in the NixOS module list, so there is no `imports` line — and sets `programs.niri.package = pkgs.niri`.
- That is the whole file. The session entry greetd reads, `systemd.packages`, the `niri.service` drop-in, the portal wiring and gnome-keyring all come from the module; `modules/nixos/xdg-portal.nix` overrides only the FileChooser routing.
- No binary-cache trust delegation. `niri.cachix.org` was whitelisted here while niri came from niri-flake; nixpkgs' niri is served by `cache.nixos.org`, so #763 dropped the delegation rather than replacing it.

**User layer** — the config document is `lib/niri-config.nix` (KDL nodes + the rationale for every setting); `home/nixos/niri.nix` resolves the four module-system values it needs, gates the render on `niri validate` in a derivation, and places the result at `~/.config/niri/config.kdl` via `xdg.configFile`:

- Because `xdg.configFile`'s *source* is the validated derivation, a config niri rejects fails the build rather than the session. That gate is what replaces niri-flake's typed `programs.niri.settings` surface — [docs/design/niri-sourcing.md](../design/niri-sourcing.md) force 5.
- The `binds` node carries the curated bind set. Full bind taxonomy + modifier-namespace philosophy lives in [keybinds.md](./keybinds.md).
- Per-host variance is one boolean: `hostContext.laptop` (true on alnair only) selects the built-in-panel `output eDP-1`, the touchpad block and `disable-power-key-handling` (#636). It replaced the separate `home/nixos/niri-laptop.nix` fragment, which had nothing left to merge into once the document became a single expression.
- Deliberate layout/decoration overrides: `prefer-no-csd` (niri draws its own border instead of clients' titlebars — wasted space when tiling) and `layout.default-column-width =
  proportion 2/3` (new windows open two-thirds wide; niri otherwise honours each client's preferred size, which opened foot narrow at its ~80×24 default). Exactly `2/3` (not an approximate `0.66`) so a fresh window lands on niri's stock preset cycle (`Hyper+Shift+R`). Anything the document does not set is niri's own default — there is no longer an intermediate layer of module defaults.
- Focus + centering behaviour (#366): `focus-follows-mouse` (`max-scroll-amount = "17%"`) lets the pointer focus nearby windows on hover while *not* yanking the workspace on larger off-screen moves — niri measures `max-scroll-amount` as the scroll distance needed to activate the target, as a fraction of working-area width. `17%` is a candidate threshold tuned to the `2/3` default-width geometry (a centered 2/3 column → adjacent 1/3 column needs ≈16% scroll; the extra point is headroom for gaps/rounding), **to be confirmed by live testing on the desktop hosts** — lower it if hover moves too much, raise it if the back-to-adjacent transition fails. `layout.center-focused-column =
  "on-overflow"` centers the focused column only when it doesn't fit on screen together with the previously-focused column; `layout.always-center-single-column = true` centers a lone column too (rather than scrolling it to an edge). This automatic centering is distinct from the manual `Hyper+Shift+C` `center-column` bind ([keybinds.md](./keybinds.md) §Window geometry).

**Display configuration (#106)** — the desktop output DP-1 (the LG UltraFine 4K, `3840×2160`). Of the three display knobs — resolution, scale, refresh — only **scale** is pinned: `outputs."DP-1".scale` carries whatever the active display profile selects (`lib/display-profiles.nix` — `1.5×` today). The 2× value the ramp was originally built around was chosen on-panel on the first desktop host, against 1× and 1.5×. **Resolution and refresh are deliberately left to niri's auto-detection** and not pinned: niri selects the EDID *preferred* mode, which for this panel is `3840×2160 @ 59.997 Hz` — native resolution at the highest mode it advertises (a 60 Hz panel; there is no higher-refresh mode to force). Pinning them would only re-assert that auto-detected value through an exact-match mode string (`3840x2160@59.997`) that silently falls back if it ever fails to match the EDID, and that a monitor swap would force you to hand-edit — maintenance cost with no defect to fix. Scale is the sole knob the hardware can't infer (apparent size is a human preference, not encodable in EDID), so it is the sole knob pinned. Mode-pinning would earn its keep only against an observed defect — a high-refresh panel whose preferred mode is wrongly 60 Hz, EDID mode-flapping, or multi-output placement — none of which apply on this panel.

**Window decorations** — the Stylix `niri` target was removed in #385; the window **border** colour now comes from the theme-menu conductor (ADR-044, #609), through the runtime `include` that is the last node of the document (`~/.local/state/theme-menu/niri.kdl`). `border` on / `focus-ring off` are asserted in `lib/niri-config.nix`, since Stylix used to assert both. (An earlier revision of this doc claimed Stylix themed niri's focus-ring with no explicit target enable; that was never true — #333. The explicit target that replaced the claim is the one #385 removed.) On top of that, the document draws its border width, inter-window gap, and corner radius from the design tokens (`lib/theme-tokens.nix`, #369, threaded in by `home/nixos/niri.nix`): `layout > border > width` (Carbon `spacing-01` on-vocab), `layout > gaps` (Carbon `spacing-05` on-vocab, formerly niri's implicit default), and a catch-all `window-rule` with `geometry-corner-radius` from the M3-ladder radius token (`md` on-vocab) + `clip-to-geometry = true` (rounded corners on every window, client content trimmed to the rounded rect). These geometry tokens are **display-profile-scaled** (`lib/display-profiles.nix`, #106): the on-vocab reference is border 2 / gap 16 / radius 12 at 1.5×, and at the **2×** profile they render **border 2 / gap 12 / radius 9** — the same apparent size. (The output scale itself is pinned by the same profile, `outputs."DP-1".scale`.) An even logical border width maps to whole physical pixels, which is why the border value stays even across scales. The focus/attention colour vocabulary is defined in the visual-identity north-star (#108); cursor theme/size cohesion is Noctalia's on the Linux desktop (ADR-036), so `stylix.cursor` stays unwired — #110 closed as mooted.

## Sharp edges

**Registering niri's systemd user units — historical, now upstream's job.** The niri package ships `niri.service` + `niri-shutdown.target` at `$out/{lib,share}/systemd/user/`. niri-flake's nixosModule installed the package via `environment.systemPackages` *only*, so systemd-user never saw the units and greetd → niri-session (`systemctl --user --wait start niri.service`) failed with "Unit not found" — this blocked the first metis activation ([#67](https://github.com/dannyfaris/nix-config/issues/67)), resolved by [PR #68](https://github.com/dannyfaris/nix-config/pull/68) adding `systemd.packages` here. nixpkgs' module sets `systemd.packages` itself, and generates its `systemd.user.services.niri` definition as a *drop-in* (`overrideStrategy` defaults to `asDropinIfExists`, and the unit exists) carrying `restartIfChanged = false` + `enableDefaultPath = false` — so `/etc/systemd/user/niri.service` stays a symlink to the package unit with its absolute `ExecStart=`, and the NixOS-stub failure mode is structurally out of reach. Both hardenings are therefore inherited rather than restated; verify them there if this ever regresses.

**Niri does NOT merge user config with `default-config.kdl`.** When a `binds` node is present at all, niri's 60+ default binds are **replaced wholesale**, not layered. This is a niri design choice, and it long predates how the config is generated. The bind set must be curated explicitly — there is no "use defaults plus my additions" mode. This shaped the curated essential set documented in [keybinds.md](./keybinds.md).

**The `include` directive was unsupported in niri 25.08 — history, since resolved by the version floor.** DMS's HM module generated `include
"hm.kdl"`-style directives expecting niri to parse them; niri 25.08 returned `unexpected node include`, which made DMS's approach untenable at that pin. Captured in [ADR-029](../decisions/ADR-029-niri-only-desktop.md) §Context. niri 26.04 — nixpkgs' current version — supports `include` *and* its `optional=true` property, which is what lets the theme-menu conductor's runtime file be the document's last node without the session failing before the seed first creates it.

**A rebuild does not hot-reload `config.kdl`.** `xdg.configFile` writes a symlink into the store, and niri's inotify watch misses symlink swaps ([niri#2658](https://github.com/YaLTeR/niri/issues/2658)) — the running session keeps the old config until relogin or an explicit `niri msg action load-config-file`. The `theme` CLI fires exactly that on every switch (`home/nixos/theme-menu.nix`); nothing else does, so a bind change lands at next login.

**Trust delegation for `niri.cachix.org` — retired.** While niri came from niri-flake, its default (`niri-flake.cache.enable = true`) would have silently added the substituter to `nix.settings`; the repo overrode it to `false` and whitelisted the same cache + key explicitly, so the delegation was recorded in source and revokable in one place. Sourcing from nixpkgs removes the need entirely: `cache.nixos.org` serves `pkgs.niri`, so #763 dropped the substituter, the key and the CI mirror of both rather than replacing them.

## References

- [ADR-027](../decisions/ADR-027-foundation-and-bundles.md) — foundation + bundles model.
- [ADR-028](../decisions/ADR-028-stylix-foundation-and-desktop-env.md) — Stylix foundation; bundle composition; metis as first desktop host. Items 1–2 stand; item 3 retracted by ADR-029.
- [ADR-029](../decisions/ADR-029-niri-only-desktop.md) — formal record of the niri-only direction after the DMS retraction.
- [#67](https://github.com/dannyfaris/nix-config/issues/67) — the slice-5 incident (niri.service stub).
- [PR #68](https://github.com/dannyfaris/nix-config/pull/68) — the niri-flake systemd-units fix.
- [#69](https://github.com/dannyfaris/nix-config/issues/69) — the niri-only baseline close-out (all five acceptance criteria met).
- [keybinds.md](./keybinds.md) — bind taxonomy that depends on niri's no-merge-with-defaults behaviour.
- [fonts.md](./fonts.md) — font installation model; the desktop's fonts are conducted by fontconfig, not Stylix (#390).
- niri upstream — https://github.com/niri-wm/niri
- niri-flake — https://github.com/sodiboo/niri-flake
