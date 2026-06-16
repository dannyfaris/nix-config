# Zen — retired (#127)

Zen was wired on metis as an audit-phase parallel install alongside Firefox (#127) to evaluate whether its intra-browser context model (workspaces, essentials, sidebar, split-view) and Stylix-target chrome theming justified displacing Firefox. **The audit concluded in Firefox's favour: Zen is retired, and Firefox remains the chosen browser and default URL handler.** See [firefox.md](./firefox.md).

## Outcome

Zen's distinguishing primitives did not earn displacing Firefox on this setup. The split-view / tab-workspace workflow overlaps with what niri already does at the WM layer — the tiling compositor handles window arrangement, so the in-browser equivalents were redundant rather than additive. Firefox's stock chrome plus niri tiling covers the workflow without carrying a second browser, its community-flake input, and its non-declarative workspace/essentials state to maintain. (This is the same niri-overlap reasoning firefox.md recorded for Zen pre-audit; the parallel install confirmed it rather than overturning it.)

## What was removed

The retirement removed the full audit footprint:

- `home/nixos/zen-browser.nix` — the HM module (`programs.zen-browser` + stub profile).
- The `zen-browser` flake input (`0xc000022070/zen-browser-flake`) from `flake.nix`, and its `flake.lock` node.
- The `../zen-browser.nix` import from the desktop-env home bundle.
- `stylix.targets.zen-browser` from `home/nixos/stylix-targets-desktop.nix`.
- Incidental Zen mentions in `portal-color-scheme.nix`, `stylix-palette.nix`, `home-manager.nix`, and the bundle/target comments.

Firefox's wiring (`home/nixos/firefox.nix`, its Stylix target, the `xdg.mimeApps` default-handler registration) was untouched — Firefox was always the default URL handler during the audit, so no handover was needed.

The `inputs` forwarding into home-manager (`modules/nixos/home-manager.nix`) was kept, not removed: Zen was its only consumer, but it stays as the extension point for future flake-input HM modules. Pruning it is a separate decision, deliberately out of scope here.

## History

The full audit-phase rationale — the parallel-install design, the Stylix-Zen target coverage (font/reader/`userChrome.css`/`userContent.css`), the community-flake selection criteria, and the sharp edges weighed (non-declarative workspace state, `font.size` asymmetry vs Firefox, Stylix-vs-Zen-Mods interaction) — lived in this doc's prior revision; `git log` and #127 carry it. This record is intentionally short: a retired tool needs the decision and what it touched, not a live selection doc.

## References

- #127 — the Firefox→Zen revisit; this retirement is its conclusion.
- [firefox.md](./firefox.md) — the retained browser; §Alternatives considered records Zen post-audit.
