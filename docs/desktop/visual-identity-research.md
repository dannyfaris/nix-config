# Research note — design-token frameworks vs. our visual identity

Status: **research note, not a decision.** Captured from a deep-research run (5 angles, 23 vetted sources, 87 claims → 24 adversarially verified via 3-vote, 1 killed) plus a synthesis pass. Feeds the open dimensions of [`visual-identity.md`](./visual-identity.md) (#108) and the planned `theme-tokens.nix`. Final literals are still decided *against rendered reality* per our principles, not from this note.

## 1. Strategic verdict

Do **not** adopt any comprehensive system (M3 / Carbon / Fluent) wholesale. Adopt a **lightweight token *structure* (DTCG-format naming)** expressed in `theme-tokens.nix`, and mine the comprehensive systems only for their **scales** — primarily IBM Carbon for spacing/grid, M3 for shape/motion ladders. Open Props is the closest off-the-shelf embodiment of this philosophy (framework-agnostic, non-prescriptive, incrementally adoptable — [open-props.style](https://open-props.style/)) and is the right *reference model*, though we re-express the idea in Nix rather than consume its CSS.

The decisive fact is our own framing: *we theme third-party surfaces, we don't build toolkit widgets.* The value of M3/Carbon/Fluent is concentrated in their component token tier and prescribed component *look* (elevation, density, branded chrome) — exactly the layer this desktop never implements and whose aesthetic contradicts the flat/thin/keyboard-driven north-star. What survives is each system's flat *scale wisdom*. This also matches the proven workflow: "adopt the baseline, then review for deviations" is cheap when the baseline is a flat named scale you copy and override at named seams; expensive when it's a coupled system whose colour model you must reconstruct to even enter.

## 2. Adopt vs. deliberately diverge, per dimension

| Dimension | Baseline to adopt | Deliberate divergence | How it lands |
|---|---|---|---|
| **Colour** | Stylix/base16 (base24-capable). Keep entirely; borrow only DTCG's *aliasing* for role→slot indirection. | Diverge from every framework's colour model — base16 is a flat-slot scheme, unlike M3's tonal palette. Keep the role map: focus→`base0D`, attention→`base09`, critical→`base08`, muted→`base03`. | `roles.*` derived from `config.lib.stylix.colors`. Doc's **Colour** dimension (decided). |
| **Typography** | Stylix font slots (one mono Nerd Font chrome/TUI/GTK, Inter body). No multi-size *type ramp* adopted — chrome is single-size by design. | If a ramp is ever wanted, M3's type scale is a reference (unverified here). | `type.*` referencing Stylix font config. **Typography** dimension. |
| **Shape / radii** | M3 corner-radius ladder as the *vocabulary*: none 0 / xs 4 / sm 8 / md 12 / lg 16 / xl 28 dp ([m3.material.io shape](https://m3.material.io/styles/shape/corner-radius-scale), 0/4/8/12/16/28 confirmed). | **Test the on-vocab values (8 / 12) on the actual panel first**; keep an off-ladder value (e.g. 10px) only if neither reads right — a documented deviation, not a default. No elevation/shadow tokens (M3 elevation rejected). | `geometry.cornerRadius` + radius scale. **Line weight & radii** (radius value open, #111). |
| **Spacing / padding** | IBM Carbon spacing scale — multiples of 2/4/8, from `$spacing-01 = 0.125rem` (2px), prescribes "stay on the scale" ([carbon spacing](https://carbondesignsystem.com/elements/spacing/overview/)). | Adopt the discipline + lower rungs only (border 2px = spacing-01; gap 16px = spacing-05; foot/popup padding snaps to scale). | `spacing.*` + `border.width`. **Spacing & density** (open, #111). |
| **Layout grid** | Only the **8px base unit** as the spacing substrate. | The responsive columns/gutters/margins/breakpoints grid is **debunked** for niri (see §3). | `layout.gap` (single value) + `layout.presetColumnWidths`. niri.md. |
| **Motion** | M3 / Open Props motion *taxonomy* (named short/medium/long duration tiers + standard/emphasized easings, [m3 motion](https://m3.material.io/styles/motion/easing-and-duration/tokens-specs)). | Adopt the structure, not exact curves; stay restrained. niri motion unconfigured today. | `motion.duration.*` / `motion.easing.*`. **Motion** (open, #111). Exact values **unverified**. |

## 3. niri layout grid — mostly debunked

The suspected "design-system column grid ↔ niri columns" congruence is **superficial**. A responsive grid is columns + gutters + margins + breakpoints reflowing content within one fixed viewport. niri **collapses gutter and margin into a single `gaps` value** (with separate `struts` as outer margins) and is **scrollable** — an unbounded horizontal strip of user-driven columns, with no breakpoint concept. What maps: the 8px base unit, and loosely the "preset column widths" idea (niri defaults 1/3, 1/2, 2/3). What doesn't: the columns/gutters/margins/breakpoints model. **Verdict: borrow the 8px unit, discard the grid model, treat niri layout as its own primitive** (`default-column-width`, presets, single gap, struts). ([niri Layout](https://niri-wm.github.io/niri/Configuration:-Layout.html))

## 4. Colour — base16 stays, explicitly

base16/Stylix remains the colour foundation, unchanged, as the deliberate-divergence axis. Our existing semantic layer (focus/attention/critical/muted, each pinned to one slot) is the same *idea* as a design system's semantic colour tier and is sufficient — do not import a framework's role names. libadwaita's named colour variables (`--accent-color`, `--window-bg-color`, oklab-based) are the closest platform-native analogue (relevant because we theme GTK) but are widget-shaped, not a portable token set. Borrow at most the DTCG aliasing pattern.

Cost of ever pursuing matugen / Material-You: **high and against the grain.** matugen does **not** natively accept a base16 theme — it generates a full M3 tonal palette, so adopting it means reconstructing a tonal scheme (duplicating the colour source-of-truth, or abandoning Stylix's base16-everything). Stylix **#2031** records a proposed Material-You integration — status **open/unresolved** (direction not asserted). ([matugen](https://github.com/InioX/matugen), [stylix#2031](https://github.com/nix-community/stylix/issues/2031))

## 5. Recommended `theme-tokens.nix` shape (DTCG-aligned)

```nix
# lib/theme-tokens.nix — name once; sites reference instead of restating.
{ config }:
let colors = config.lib.stylix.colors; in {
  # COLOUR ROLES — source: base16/Stylix (flat slots); DTCG-style aliases to slots.
  roles = {
    focus     = colors.base0D;  # active/focused surface
    attention = colors.base09;  # chrome shown without taking focus (notifications)
    critical  = colors.base08;  # error / urgent
    muted     = colors.base03;  # inactive
  };
  # GEOMETRY — radius vocabulary ref M3 ladder; border width = Carbon spacing-01.
  geometry = {
    cornerRadius = 10;          # TEST 8/12 on-panel before committing (#111)
    radius = { sm = 8; md = 12; lg = 16; };
    border.width = 2;
  };
  # SPACING — source: IBM Carbon (multiples of 2/4/8; "stay on the scale").
  spacing = { s01 = 2; s02 = 4; s03 = 8; s04 = 12; s05 = 16; s06 = 24; s07 = 32; };
  # LAYOUT — niri primitives, NOT a responsive grid.
  layout = { gap = 16; presetColumnWidths = [ "1/3" "1/2" "2/3" ]; };
  # MOTION — taxonomy from M3/Open Props; values OPEN (#111), restrained.
  motion = {
    duration = { quick = 120; moderate = 200; };  # ms — PLACEHOLDER, verify
    easing.standard = "...";                       # cubic-bezier — UNVERIFIED
  };
  # TYPE — source: Stylix font slots; single chrome size (no ramp adopted).
  type = { /* reference config.stylix.fonts.* */ };
}
```

## 6. Caveats / unverified / open

- **Fluent 2** "two-tier global/alias token hierarchy" was **refuted (1–2)** — not relied on; Fluent not recommended (branded, component-heavy).
- **Unverified — verify before pinning literals:** Carbon spacing rungs above 16px; M3 2025 "expressive" extra shape steps (large-increased / xx-large / full dp values); **all M3 motion ms/easing values** (M3 pages are JS-walled; motion values above are placeholders).
- **DTCG** reached first stable `2025.10` (2025-10-28, [w3.org](https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/)); editor's draft moves ahead. We borrow the *idea* (`$value`/`$type`/aliasing), not a conformant parser.
- **base24** extends base16 with 8 more colours — headroom only; not needed for the 4-role map now.
- **Open Props** used as reference model only (it's a web CSS library; we don't consume its CSS).
- Radius value (10px) and both spacing scales remain **open under #111**; final literals decided against rendered reality.
