# Niri

Wayland compositor. Scrollable-tiling paradigm — windows arrange in a horizontal strip; you scroll the workspace to bring different sections into view.

## Selection

**niri 26.04 from nixpkgs**, with the NixOS/home integration from [`epireyn/niri-flake`](https://github.com/epireyn/niri-flake) — the maintained fork, blessed by the original maintainer after `sodiboo/niri-flake` stopped merging (#763, [niri-sourcing.md](../design/niri-sourcing.md)). Runs on alcyone and alnair. Enabled at the system layer via `modules/nixos/niri.nix`; user settings (binds, layout) at `home/nixos/niri.nix` via the flake's auto-injected `homeModules.config`.

The package/module split is deliberate: taking the binary from nixpkgs means the flake dependency is eval-time module code with no binary and no signing key behind it, which is what let the `niri.cachix.org` trust delegation retire outright rather than move to the fork's cache.

## Rationale

**Scrollable-tiling fits the operator's workflow.** Traditional tilers (sway, river) carve the screen into bsp/manual tiles; the layout reflows when a new window opens. Niri's scroll-the-workspace model means the existing layout never reflows — a new window slots to the right and the rest of the workspace stays put. For the operator's pattern of running 3–6 tasks side-by-side and occasionally spinning up a new context, the no-reflow behaviour is meaningful.

**Recent, actively maintained, narrowly scoped.** niri's author (YaLTeR) ships releases regularly. The codebase deliberately avoids feature creep common to larger compositors — no extensions, no scripting layer, no plugin manifest. The narrow scope means fewer breaking changes per upgrade.

**`niri-flake` provides the NixOS integration.** The flake gives us the nixosModule + homeModules-based settings interface (the package now comes from nixpkgs). Sharp edges discovered (see below) but the integration works. Originally sodiboo's; since #763 the maintained `epireyn` fork, which sodiboo pinned as the successor after ceasing to merge.

## Alternatives considered

**sway** — mature, well-supported in NixOS. Traditional bsp tiling. Passed over because reflow-on-new-window fights the operator's pattern of spinning up new contexts without disturbing existing layout.

**river** — manual tiling with scriptable layout-engine. More flexible than sway; passed over because the layout-as-external-script cognitive surface didn't earn its keep for a solo-user setup.

**Hyprland** — popular, feature-rich, animations + effects. Passed over because the feature surface is much larger than we'd exercise. The minimal niri model + clean NixOS integration outweighs Hyprland's polish for our use.

## Configuration

**System layer** — `modules/nixos/niri.nix`:

- Imports `inputs.niri-flake.nixosModules.niri` and enables `programs.niri.enable = true`.
- Sets `programs.niri.package = pkgs.niri` (nixpkgs' 26.04) rather than the flake's own build.
- Keeps `niri-flake.cache.enable = false`. No substituter replaces it — `cache.nixos.org` serves `pkgs.niri`. The line is load-bearing, not vestigial: the option defaults to *true*, so removing it would have the fork add its maintainer's cachix and signing key to every host importing the module.
- Registers niri's package-shipped systemd user units via `systemd.packages = [ config.programs.niri.package ]`. Load-bearing — without it, niri.service is invisible to systemd-user. See sharp edges.

**User layer** — `home/nixos/niri.nix`:

- Sets `programs.niri.settings.binds` directly. Full bind taxonomy + modifier-namespace philosophy lives in [keybinds.md](./keybinds.md).
- Deliberate layout/decoration overrides: `prefer-no-csd = true` (niri draws its own focus-ring border instead of clients' titlebars — wasted space when tiling) and `layout.default-column-width =
  proportion 2/3` (new windows open two-thirds wide; niri otherwise honours each client's preferred size, which opened foot narrow at its ~80×24 default). Exactly `2/3` (not an approximate `0.66`) so a fresh window lands on niri's stock preset cycle (`Hyper+Shift+R`). Remaining layout/input/cursor settings still flow from niri-flake defaults.
- Focus + centering behaviour (#366): `input.focus-follows-mouse` (`max-scroll-amount = "17%"`) lets the pointer focus nearby windows on hover while *not* yanking the workspace on larger off-screen moves — niri measures `max-scroll-amount` as the scroll distance needed to activate the target, as a fraction of working-area width. `17%` is a candidate threshold tuned to the `2/3` default-width geometry (a centered 2/3 column → adjacent 1/3 column needs ≈16% scroll; the extra point is headroom for gaps/rounding), **to be confirmed by live testing on the desktop hosts** — lower it if hover moves too much, raise it if the back-to-adjacent transition fails. `layout.center-focused-column =
  "on-overflow"` centers the focused column only when it doesn't fit on screen together with the previously-focused column; `layout.always-center-single-column = true` centers a lone column too (rather than scrolling it to an edge). This automatic centering is distinct from the manual `Hyper+Shift+C` `center-column` bind ([keybinds.md](./keybinds.md) §Window geometry).

**Display configuration (#106)** — the desktop output DP-1 (the LG UltraFine 4K, `3840×2160`). Of the three display knobs — resolution, scale, refresh — only **scale** is pinned: `outputs."DP-1".scale` carries the display calibration's scale (`lib/display-profiles.nix` — `1.5×`, settled in #715). The 2× value the ramp was originally built around was chosen on-panel on this host, against 1× and 1.5×; how the fleet later moved to 1.5× is recorded in visual-identity.md §"Hardware is a design input". **Resolution and refresh are deliberately left to niri's auto-detection** and not pinned: niri selects the EDID *preferred* mode, which for this panel is `3840×2160 @ 59.997 Hz` — native resolution at the highest mode it advertises (a 60 Hz panel; there is no higher-refresh mode to force). Pinning them would only re-assert that auto-detected value through an exact-match mode string (`3840x2160@59.997`) that silently falls back if it ever fails to match the EDID, and that a monitor swap would force you to hand-edit — maintenance cost with no defect to fix. Scale is the sole knob the hardware can't infer (apparent size is a human preference, not encodable in EDID), so it is the sole knob pinned. Mode-pinning would earn its keep only against an observed defect — a high-refresh panel whose preferred mode is wrongly 60 Hz, EDID mode-flapping, or multi-output placement — none of which apply on this panel.

**Window decorations** — the Stylix `niri` target was removed in #385; the window **border** colour now comes from Noctalia's own native theme engine (ADR-048, reversing ADR-044/#609 for Linux — #819 Epic G), through a pre-declared mount-point `home/nixos/niri.nix` appends to the rendered config (`include optional=true "noctalia.kdl"`, resolved relative to niri's own config directory — niri's builtin `apply.sh`, enabled via the template whitelist in `home/nixos/noctalia.nix`, detects it by a basename-anchored regex and writes only that file). `border.enable = true` / `focus-ring.enable = false` are re-asserted in `home/nixos/niri.nix`, since Stylix used to assert both. (An earlier revision of this doc claimed Stylix themed niri's focus-ring with no explicit target enable; that was never true — #333. The explicit target that replaced the claim is the one #385 removed.) On top of that, `home/nixos/niri.nix` draws its border width, inter-window gap, and corner radius from the design tokens (`lib/theme-tokens.nix`, #369): `layout.border.width` (Carbon `spacing-01` on-vocab), `layout.gaps` (Carbon `spacing-05` on-vocab, formerly niri's implicit default), and a catch-all `window-rule` with `geometry-corner-radius` from the M3-ladder radius token (`md` on-vocab) + `clip-to-geometry = true` (rounded corners on every window, client content trimmed to the rounded rect). These geometry tokens come from the **display calibration** (`lib/display-profiles.nix`, #106): at the settled 1.5× they render the on-vocab **border 2 / gap 16 / radius 12** directly. (The output scale itself is pinned by the same file, `outputs."DP-1".scale`.) An even logical border width maps to whole physical pixels, which is why the border value stays even. The focus/attention colour vocabulary is defined in the visual-identity north-star (#108); cursor theme/size selection stays a Stylix responsibility (`home/nixos/pointer-icons.nix`, #110 — a named ADR-048 residue, #825), consumed by niri via `programs.niri.settings.cursor`.

## Sharp edges

**niri-flake's nixosModule doesn't register systemd user units.** The niri package ships `niri.service` + `niri-shutdown.target` at `$out/{lib,share}/systemd/user/`, but niri-flake's nixosModule installs the package via `environment.systemPackages` *only* — no `systemd.packages = [ cfg.package ]`. Without that wire, systemd-user never sees the units; greetd → niri-session line 47 (`systemctl --user --wait start niri.service`) fails with "Unit not found". This blocked the first metis activation ([#67](https://github.com/dannyfaris/nix-config/issues/67)) and was resolved by [PR #68](https://github.com/dannyfaris/nix-config/pull/68) (the `systemd.packages` line above). niri-flake's README claims *"The niri package will be installed, including its systemd units"* — overstates the module's behaviour. Potential upstream report.

**Niri does NOT merge user config with `default-config.kdl`.** When `programs.niri.settings.binds` is set at all, niri's 60+ default binds are **replaced wholesale**, not layered. This is a niri design choice, not a niri-flake limitation. The bind set must be curated explicitly — there is no "use defaults plus my additions" mode. This shaped the curated essential set documented in [keybinds.md](./keybinds.md).

**The `include` directive is unsupported in niri 25.08.** Documenting the historical gotcha: DMS's HM module generated `include
"hm.kdl"`-style directives expecting niri to parse them; niri 25.08 returns `unexpected node include`. niri-flake's PR #1548 (unmerged) plans to add support; meanwhile, DMS's approach was untenable for our niri pin. Captured in [ADR-029](../decisions/ADR-029-niri-only-desktop.md) §Context.

**The flake's cache default is a trust trap.** `niri-flake.cache.enable` defaults to *true*, which silently adds its maintainer's cachix substituter and signing key to `nix.settings` on every host importing the module. We pin it to `false`. Since #763 nothing replaces it: the package comes from nixpkgs, so `cache.nixos.org` serves it and no delegation is taken at all. The trap is that the `false` line looks vestigial once the substituter block is gone — deleting it re-takes the delegation under the fork's name. Caught in adversarial review, not by design.

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
