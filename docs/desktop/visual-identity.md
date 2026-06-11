# Visual identity

The desktop's aesthetic north-star. Living document — the styling tickets (display #106, wallpaper #109, pointer/icons #110, compositor styling #111) and the per-surface selection docs (`fonts.md`, `niri.md`, `fnott.md`, `waybar.md`, `fuzzel.md`) reference and implement against it, rather than each making locally-sensible but divergent choices. It sets *intent* across every axis of the desktop's look — typography, colour, line weight, radii, spacing, padding, motion, pointer/icons, imagery; the per-surface docs record the specific selections that serve it.

## Principles

These are method, and they apply to *every* dimension below — not just colour.

- **Stylix is the theme source-of-truth** (ADR-028). Every themed surface derives from one base16 palette and one font/size config; nothing is hand-hard-coded.
- **Start from a thoughtful, pre-defined default, then review on the running system for deviations.** Adopt a mature, pre-existing pattern wholesale as the baseline, live with it, and override only where rendered reality warrants — a small, documented deviation set. This is cheaper and more coherent than hand-rolling: the worked example is wholesale-theming niri from Stylix's defaults, then making a handful of deliberate overrides. It is why each dimension below names an adopted *baseline* (a framework's scale) before any divergence.
- **Lean on the framework's idiom; deviate only deliberately.** Use the conventional defaults — base16 slots for colour, Stylix's font slots for type, established scales for geometry — and override only at named seams where the default genuinely doesn't fit. A deviation is a conscious, documented choice, never drift.
- **Bind to host-intent; never hard-pin.** Track the host's theme, polarity, and scale rather than a fixed look: colour by *slot* (not tone), pointer/icons by *polarity*, sizes by *scale*. The test of any decision — does it still hold if the scheme or polarity changes?
- **Hardware is a design input.** The panel and scale (metis: 3840×2160 at scale 1.5 — the decided scale, with deliberate *pinning* still open under #106) drive concrete values — line weight, type size, cursor size, and how a radius reads — not just aesthetics.
- **Decide against rendered reality, not the config.** Appearance decisions are made by looking at the running system, not predicted from a setting.
- **One definition, many consumers.** A value is named once and inherited everywhere it is used; surfaces reference the definition rather than restating a literal (see *Theming mechanism*).

## Dimensions

Each axis records its adopted baseline, what we deliberately diverge on, and any literal still pending an on-system test; the per-surface docs carry the specifics. The concrete values land as design tokens (see *Theming mechanism*, #369).

### Typography

Current state: one mono Nerd Font across the chrome / TUI / GTK app-UI, Inter for web body (`fonts.md`; #283 / #349 / #351).

**Proposed direction — a stance change reversing #283 / #349 / #351:** confine monospace to where it is functionally required — the terminal (`foot`, plus the TUIs inside it: gh-dash, zellij) keeps the mono Nerd Font — and move all UI chrome (waybar, fnott, fuzzel, GTK dialogs) to a **proportional UI sans** (the Stylix `sansSerif` slot); browser body is already sans. The rule inverts to *mono = terminal only; sans = all UI chrome*. waybar's Nerd glyphs (network/tray) come via a `Symbols Nerd Font` fontconfig fallback; fnott/fuzzel icons come from the icon theme (#110), not the font.

This is the conventional sans-UI / mono-code split, and it makes the adopted **type *ramp* apply directly** — the M3 type scale is tuned for a proportional font, so its role steps land cleanly on a sans chrome: bar ≈ `label-medium` (12), notification / launcher / dialog ≈ `body-medium` / `body-large` (14–16), terminal sized on its own legibility terms. (The prior universal-mono setup mapped a proportional ramp onto a mono face, which doesn't translate 1:1; this removes that mismatch.) The ramp is adopted whole even though only a few steps are consumed today, ready for hierarchy.

**Sans face — open, framework-derived front-runners** (the slot moves off Inter, per operator preference): **IBM Plex Sans** (the IBM Carbon family — coheres with the Carbon spacing scale already adopted; distinctive but restrained) and **Roboto** (the M3 family — the type ramp's native font, so its metrics apply most faithfully, though ubiquitous). Chosen on framework coherence + rendered reality at small UI sizes on the 4K/1.5 panel; both are in nixpkgs.

**Open:** the sans face; the role-derived chrome sizes, tested on-panel (M3 px values are verify-before-pinning — the role logic is the load-bearing part); whether web/document body text also goes mono. Sizes land as `type.size.*` ramp tokens; the sans swap + mono-only scoping are experimented and decided during the token build (#369).

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

Thin, crisp edges with a gentle radius. **Baseline adopted:** the M3 corner-radius ladder as the radius *vocabulary* (`sm` 8 / `md` 12 / `lg` 16 dp); border width is **2px** = Carbon `spacing-01` (on-scale, and hardware-justified — an even logical width renders crisp on the 4K panel at scale 1.5, where 1px lands on the half-pixel grid). `clip-to-geometry` trims each client's square surface to the rounded rect. **Dropped:** the off-vocab **10px** radius is discarded — `sm` (8) and `md` (12) are to be **tested on the panel** and the winner adopted (the crispness argument that justified the 2px border does not transfer to a radius — a corner is anti-aliased regardless). Values land as tokens (#369); the radius literal is finalised against rendered reality under #111. (#358 landed the first treatment.)

### Spacing & density

**Baseline adopted:** the IBM Carbon spacing scale — multiples of 2/4/8, "stay on the scale." Two distinct scales:

- **Inter-window spacing** — the gaps *between* tiles: niri's single `gaps` value, currently 16px = Carbon `spacing-05`, untuned by this config.
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

**Design tokens — `theme-tokens.nix` (#369).** The design language is expressed as one DTCG-shaped Nix token module: colour roles and type sizes *alias* what Stylix centralizes; geometry, spacing, layout, and motion become canonical tokens there; surfaces reference tokens instead of restating literals (the cure for the #333-class drift, where a `base0D` typed independently across modules silently fell out of sync). This follows the design-token framework research (#369 §Background; the research note is `visual-identity-research.md`): rather than adopt a comprehensive design system (Material Design 3 / IBM Carbon / Fluent 2) — whose value sits in component/elevation/branded tiers this desktop never builds, and whose aesthetic contradicts the flat/minimal north-star — we adopt a **lightweight token *structure* (DTCG naming)** and mine the comprehensive systems only for their flat *scales* (Carbon spacing; M3 radius/motion ladders). Nix references *are* DTCG aliasing; a conformant `tokens.json` emit stays latent until a design tool needs it.

## Cadence

Living document, same conventions as `keybinds.md` and `fonts.md`. Decisions land here (or in the relevant per-surface doc) *before* the implementing commit. The document grows by accretion — dimensions gain their adopted baseline as it is settled, and their final literals as they are tested; nothing is pre-decided.

## See also

- [ADR-028](../decisions/ADR-028-stylix-foundation-and-desktop-env.md) — Stylix foundation; the palette source-of-truth.
- `fonts.md` / `niri.md` / `fnott.md` / `waybar.md` / `fuzzel.md` — per-surface and per-dimension selections that implement this.
- `visual-identity-research.md` — the design-token framework comparison (M3 / Carbon / Fluent / Open Props / DTCG / libadwaita) this draws on.
- #369 — `theme-tokens.nix`: the DTCG-shaped token module + the framework research that scoped it.
- #106 / #109 / #110 / #111 — the styling tickets that reference this north-star.
