# Visual identity

The desktop's aesthetic north-star. Living document — the styling tickets (display #106, wallpaper #109, pointer/icons #110, compositor styling #111) and the per-surface selection docs (`fonts.md`, `niri.md`, `fnott.md`, `waybar.md`, `fuzzel.md`) reference and implement against it, rather than each making locally-sensible but divergent choices. It sets *intent* across every axis of the desktop's look — typography, colour, line weight, radii, spacing, padding, motion, pointer/icons, imagery; the per-surface docs record the specific selections that serve it.

## Principles

These are method, and they apply to *every* dimension below — not just colour.

- **Type is fontconfig-conducted; colour stays Stylix's base16** (ADR-028; #390). Fonts no longer derive from Stylix on the desktop — every surface asks for a fontconfig *generic* (`monospace` / `sans-serif`), resolved at runtime by one user-space mapping (see *Typography* and `fonts.md`). Colour still derives from one base16 palette; nothing is hand-hard-coded.
- **Start from a thoughtful, pre-defined default, then review on the running system for deviations.** Adopt a mature, pre-existing pattern wholesale as the baseline, live with it, and override only where rendered reality warrants — a small, documented deviation set. This is cheaper and more coherent than hand-rolling: the worked example is wholesale-theming niri from Stylix's defaults, then making a handful of deliberate overrides. It is why each dimension below names an adopted *baseline* (a framework's scale) before any divergence.
- **Lean on the framework's idiom; deviate only deliberately.** Use the conventional defaults — base16 slots for colour, fontconfig generics for type, established scales for geometry — and override only at named seams where the default genuinely doesn't fit. A deviation is a conscious, documented choice, never drift.
- **Bind to host-intent; never hard-pin.** Track the host's theme, polarity, and scale rather than a fixed look: colour by *slot* (not tone), pointer/icons by *polarity*, sizes by *scale*. The test of any decision — does it still hold if the scheme or polarity changes?
- **Hardware is a design input.** The panel and scale (metis: a 27" 4K LG UltraFine, 3840×2160 / 600×340mm, run at a **2× niri output scale** — chosen after an on-panel A/B against 1× and 1.5×) drive concrete values — line weight, type size, cursor size, and how a radius reads — not just aesthetics. 2× won on pixel-perfect crispness, a clean point/pixel model, and macOS parity, at the cost of ≈44% logical desktop space (1920×1080 logical, vs 2560×1440 at 1.5×). The scale, the per-surface font sizes, and the geometry are coupled through one switchable knob, `lib/display-profiles.nix` (active = "2.0"; 1.0/1.5 retained for retuning), calibrated so every scale renders at the same apparent size. Display *pinning* stays open under #106 ("2× chosen, harness retained", not closed).
- **Decide against rendered reality, not the config.** Appearance decisions are made by looking at the running system, not predicted from a setting.
- **One definition, many consumers.** A value is named once and inherited everywhere it is used; surfaces reference the definition rather than restating a literal (see *Theming mechanism*).

## Dimensions

Each axis records its adopted baseline, what we deliberately diverge on, and any literal still pending an on-system test; the per-surface docs carry the specifics. The concrete values land as design tokens (see *Theming mechanism*, #369).

### Typography

**Adopted — fontconfig-conducted, two Nix-managed faces.** The desktop's fonts resolve through fontconfig generics rather than being pinned per-surface (the runtime-conductor model — `fonts.md`, #390). Two faces are Nix-managed: **Monaspace Argon Nerd Font** (GitHub's humanist mono superfamily; the Nerd Font variant carries the TUI glyphs) backs the terminal (`foot`) and the TUIs inside it (gh-dash, zellij, starship); the proportional **Inter** backs the content surfaces fontconfig still serves — GTK dialogs and web/document body. Noctalia owns its own shell surfaces' fonts (bar / launcher / notifications) and, left at its generic defaults, follows the same fontconfig mapping (ADR-036; `noctalia.md`). Icons come from the icon theme (#110), not the font.

This supersedes the earlier **hybrid** split (mono for the driven chrome — terminal / status bar / launcher; sans for content — notifications / dialogs / web), itself the third stance after universal-mono (#283 / #349 / #351) and all-sans chrome (#369). Noctalia subsumed the bar / launcher / notification surfaces (ADR-036), collapsing the split to: mono for terminal/TUIs, sans for GTK/web, Noctalia self-theming. See `fonts.md` §History.

**Sizing is restrained, macOS-style — a flat band of close sizes in regular weights, not a dramatic ramp.** Hierarchy comes from layout, not a steep type scale. Sizes are **driven by the display profile** (see the *Hardware is a design input* principle and §"Line weight & radii"): metis (the first NixOS desktop host) runs a **2× niri output scale**, and `lib/display-profiles.nix` couples the scale to the per-surface sizes so they hold a constant apparent size across scales. At 2× the Nix-managed band is foot 8 / GTK 9 (1.5× reference: foot 11 / GTK 12); Noctalia sizes its own surfaces. Sizes live on `stylix.fonts.sizes` (aliased by the `type.size.*` tokens — Stylix stays enabled under E1, and the surviving GTK/Firefox targets read the slots); a re-tune or scale change is a one-line edit to `display-profiles.nix`.

The sans face is **Inter** — a screen-first UI sans, neutral and legible at small sizes, well-suited to the GTK chrome and web body the sans now backs (and to Noctalia's Material-3 surfaces). This **reverses the earlier IBM Plex Sans choice**: Plex was picked to cohere with the Carbon spacing scale, but with Noctalia owning the rendered look and fontconfig owning the mapping, that coherence no longer governs the narrower GTK/web role. The mono is **Monaspace Argon** (preferred over IBM Plex Mono for its humanist warmth). Per-surface selections, the runtime UX, and the dpi-aware sizing story live in `fonts.md`. **Re-decided (#390); was Decided (IBM Plex Sans).**

### Colour

base16-idiomatic, named by slot. base16/Stylix stays the colour foundation and is the deliberate-divergence axis — no framework colour model is adopted, because base16 is a **flat-slot** scheme, unlike the tonal palettes of M3 / Material You. The chrome speaks a small vocabulary of semantic signals, each pinned to one slot:

| Role | Slot | Meaning | Surfaces |
|---|---|---|---|
| **Focus** | `base0D` | the surface that holds focus | niri active window, fuzzel, waybar active workspace, gh-dash focused section |
| **Attention** | `base09` | chrome shown *without* taking focus | fnott normal-urgency notification |
| **Critical** | `base08` | error / urgent | fnott critical, waybar urgent |
| **Muted** | `base03` | inactive | niri inactive window, fnott low |

The boundary is behavioural: a surface uses *focus* if it holds focus when active — which includes overlays like the launcher and the auth prompt, because when active they *become* the focused window, so their accent can never clash with a focus they don't own. *Attention* is for chrome that appears **without** taking focus — today only notifications — which coexists with a separately-focused window and must read as distinct from it. Focus rides base16's canonical accent slot; the other roles are deliberate app-level assignments to tonally-fitting slots — base16 doesn't itself prescribe UI-chrome roles, so this map is ours to hold consistently. On metis the per-host override parks `base0E` on `base0D`'s tone, so the two are equal today and every focus surface reads identically; the discipline is held *by slot* so it stays coherent under any scheme where they diverge. Pursuing Material You (matugen) would mean reconstructing a tonal scheme — matugen does not accept base16 — so it is against the grain and not pursued. **Decided** — implemented in #358; role tokens alias the slots (#369).

### Line weight & radii

Thin, crisp edges with a gentle radius. **Baseline adopted:** the M3 corner-radius ladder as the radius *vocabulary* (`sm` 8 / `md` 12 / `lg` 16 dp); border width on-vocab is **2px** = Carbon `spacing-01`. `clip-to-geometry` trims each client's square surface to the rounded rect. **Dropped:** the off-vocab **10px** radius is discarded — replaced by the on-vocab `md` (12) reference (M3 puts larger radii on larger surfaces, and the window / launcher / notification chrome are medium-large; `md` also keeps the radius *gentle*, where `sm` 8 would tighten it). The rung is an aesthetic call: `md` (12) is the on-vocab reference, a one-line retest away from `sm` (8) against rendered reality.

**Geometry is scaled by the display profile** (the same `lib/display-profiles.nix` knob that drives type size — see *Hardware is a design input* and §Typography). The on-vocab values above are the 1.5× reference (border 2 / radius 12 / gap 16); the 1× and 2× profiles scale them by ≈1/scale to hold a constant apparent size. At metis's active **2×** profile this renders **gap 12 / radius 9 / border 2** — the same apparent size as the on-vocab 16 / 12 / 2 at 1.5×. The token surface (`theme-tokens.nix`, #369) now reads the active profile's geometry, with the static Carbon/M3 scales (`spacing.*`, `radius.*`) retained as the vocabulary; niri / fnott / fuzzel reference the tokens for border width, gap, and radius. (#358 landed the first treatment; #369 centralised the literals; the values became profile-driven with the display-scale work, #106.)

### Spacing & density

**Baseline adopted:** the IBM Carbon spacing scale — multiples of 2/4/8, "stay on the scale." Two distinct scales:

- **Inter-window spacing** — the gaps *between* tiles: niri's single `gaps` value, now an explicit token; #369 made it explicit rather than riding niri's implicit default. On-vocab it is Carbon `spacing-05` (16px); like border and radius it is **scaled by the display profile** (§"Line weight & radii"), so metis's active 2× renders **gap 12** — the same apparent gap as 16 at 1.5×.
- **Intra-surface padding** — breathing room *inside* a surface (foot `pad`, popup insets, bar padding). Currently unset, so e.g. foot's text crowds the window edges and reads cramped. To be set on-scale so each surface doesn't make a locally-sensible but divergent call — the same coherence argument this document serves.

The responsive layout *grid* (columns/gutters/margins/breakpoints) is **not** adopted: niri collapses gutter and margin into a single `gaps` value and is scrollable (an unbounded strip of columns, no breakpoints), so only the 8px base unit transfers — niri layout stays its own primitive (`default-column-width`, presets, single gap, struts). Values land as tokens (#369); padding literals under #111.

### Motion

Window and workspace animation and transition character. **Baseline adopted:** the M3 / Open Props motion *taxonomy* — a few named duration tiers + standard/emphasized easings, kept restrained. Unconfigured today (niri's defaults); exact values remain **open** (#111) and are decided against rendered reality. Values land as tokens (#369).

### Pointer & icons

Cursor theme and application/notification icon theme, cohering with the host polarity and the chrome's restrained mood; cursor *size* driven by the 4K panel. `stylix.cursor` / `stylix.icons` are unwired today. **Open** (#110). Note the grain of control: cursors are essentially monochrome, so this axis coheres by polarity + size + theme mood, not by base16-palette precision.

### Imagery / wallpaper

Wallpaper direction and any desktop imagery. **Open** (#109).

## Theming mechanism

Stylix runs `autoEnable = false` — the `whitelist > blanket` stance: each target is enabled deliberately, in `home/nixos/stylix-targets-desktop.nix` (desktop) and `home/shared/stylix-targets.nix` (TUI). Surfaces join the palette by being whitelisted. Where Stylix maps an element to a slot or value that doesn't match this document's intent (fuzzel's border → `base0E`, waybar's active workspace → `base05`), the per-surface module overrides it — the deliberate-deviation list this document governs. A spike that flipped `autoEnable = true` to discover such cases also surfaced two targets worth keeping off — `qt` (large closure, no Qt apps) and `gnome` (font conflict) — which reaffirmed the whitelist over a blanket-enable.

**Design tokens — `theme-tokens.nix` (#369).** The design language lives in one DTCG-shaped Nix token module (`lib/theme-tokens.nix`): colour roles and type sizes *alias* what Stylix centralizes; the Carbon spacing and M3 radius scales are canonical vocabulary there; geometry and layout read the active display profile (`lib/display-profiles.nix`, #106); motion carries structure only. Surfaces reference tokens instead of restating literals (the cure for the #333-class drift, where a `base0D` typed independently across modules silently fell out of sync). This follows the design-token framework research (#369 §Background; the research note is [`visual-identity-research.md`](../research/visual-identity-research.md)): rather than adopt a comprehensive design system (Material Design 3 / IBM Carbon / Fluent 2) — whose value sits in component/elevation/branded tiers this desktop never builds, and whose aesthetic contradicts the flat/minimal north-star — we adopt a **lightweight token *structure* (DTCG naming)** and mine the comprehensive systems only for their flat *scales* (Carbon spacing; M3 radius/motion ladders). Nix references *are* DTCG aliasing; a conformant `tokens.json` emit stays latent until a design tool needs it. **Landed (#369, first pass):** the module plus the colour-role, geometry (border + radius), and layout (gap) rewire across niri / fnott / fuzzel / waybar / gh-dash; `type.size` aliases the chrome sizes and `motion` carries structure only (values open, #111). The typography follow-up grew `type.size`; the type model has since moved off that hybrid to the fontconfig-conducted state (see §Typography). The display-scale work (#106) then made the geometry and per-surface sizes **profile-driven** — the static Carbon/M3 scales remain the vocabulary, but the live values track the active scale.

## Cadence

Living document, same conventions as `keybinds.md` and `fonts.md`. Decisions land here (or in the relevant per-surface doc) *before* the implementing commit. The document grows by accretion — dimensions gain their adopted baseline as it is settled, and their final literals as they are tested; nothing is pre-decided.

## See also

- [ADR-028](../decisions/ADR-028-stylix-foundation-and-desktop-env.md) — Stylix foundation; the palette source-of-truth.
- `fonts.md` / `niri.md` / `fnott.md` / `waybar.md` / `fuzzel.md` — per-surface and per-dimension selections that implement this.
- [`visual-identity-research.md`](../research/visual-identity-research.md) — the design-token framework comparison (M3 / Carbon / Fluent / Open Props / DTCG / libadwaita) this draws on.
- #369 — `theme-tokens.nix`: the DTCG-shaped token module + the framework research that scoped it.
- #106 / #109 / #110 / #111 — the styling tickets that reference this north-star.
