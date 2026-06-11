# Visual identity

The desktop's aesthetic north-star. Living document — the styling tickets (display #106, wallpaper #109, pointer/icons #110, compositor styling #111) and the per-surface selection docs (`fonts.md`, `niri.md`, `fnott.md`, `waybar.md`, `fuzzel.md`) reference and implement against it, rather than each making locally-sensible but divergent choices. It sets *intent* across every axis of the desktop's look — typography, colour, line weight, radii, spacing, padding, motion, pointer/icons, imagery; the per-surface docs record the specific selections that serve it.

## Principles

These are method, and they apply to *every* dimension below — not just colour.

- **Stylix is the theme source-of-truth** (ADR-028). Every themed surface derives from one base16 palette and one font/size config; nothing is hand-hard-coded.
- **Lean on the framework's idiom; deviate only deliberately.** Use the conventional defaults — base16 slots for colour, Stylix's font slots for type, sensible geometry — and override only at named seams where the default genuinely doesn't fit. A deviation is a conscious, documented choice, never drift.
- **Bind to host-intent; never hard-pin.** Track the host's theme, polarity, and scale rather than a fixed look: colour by *slot* (not tone), pointer/icons by *polarity*, sizes by *scale*. The test of any decision — does it still hold if the scheme or polarity changes?
- **Hardware is a design input.** The panel and scale (metis: 3840×2160 at scale 1.5 — the decided scale, with deliberate *pinning* still open under #106) drive concrete values — line weight, type size, cursor size, and how a radius reads — not just aesthetics.
- **Decide against rendered reality, not the config.** Appearance decisions are made by looking at the running system, not predicted from a setting.
- **One definition, many consumers.** A value is named once and inherited everywhere it is used; surfaces reference the definition rather than restating a literal (see *Theming mechanism*).

## Dimensions

Each axis records its settled intent and what remains open; the per-surface docs carry the specifics.

### Typography

One mono Nerd Font (JetBrainsMono Nerd Font) across the Wayland chrome, the TUI, and GTK app-UI, at one unified chrome size; Inter for web/document body text. **Decided** — see `fonts.md` (family #283, size #349, GTK app-UI #351). **Open:** whether web/document body text also goes mono — the maximalist last step of the font question (no ticket yet; see this issue's history).

### Colour

base16-idiomatic, named by slot. The chrome speaks a small vocabulary of semantic signals, each pinned to one slot:

| Role | Slot | Meaning | Surfaces |
|---|---|---|---|
| **Focus** | `base0D` | the surface that holds focus | niri active window, fuzzel, waybar active workspace, gh-dash focused section |
| **Attention** | `base09` | chrome shown *without* taking focus | fnott normal-urgency notification |
| **Critical** | `base08` | error / urgent | fnott critical, waybar urgent |
| **Muted** | `base03` | inactive | niri inactive window, fnott low |

The boundary is behavioural: a surface uses *focus* if it holds focus when active — which includes overlays like the launcher and the auth prompt, because when active they *become* the focused window, so their accent can never clash with a focus they don't own. *Attention* is for chrome that appears **without** taking focus — today only notifications — which coexists with a separately-focused window and must read as distinct from it. Focus rides base16's canonical accent slot; the other roles are deliberate app-level assignments to tonally-fitting slots — base16 doesn't itself prescribe UI-chrome roles, so this map is ours to hold consistently. On metis the per-host override parks `base0E` on `base0D`'s tone, so the two are equal today and every focus surface reads identically; the discipline is held *by slot* so it stays coherent under any scheme where they diverge. **Decided** — implemented in #358; specifics in the per-surface docs.

### Line weight & radii

Thin, crisp edges with a gentle radius. **Decided:** window/chrome borders are **2px** with a **10px corner radius** (`clip-to-geometry`, so each client's square surface is trimmed to the rounded rect). 2px is hardware-driven — an even logical width renders crisp on the 4K panel at scale 1.5, where 1px lands on the half-pixel grid and looks grainy on the curve (#358; `niri.md`, `fnott.md`, `fuzzel.md`). **Open:** the radius *value* — 10px today; revisit if it reads heavy on large windows (#111).

### Spacing & density

Two distinct scales, both **open** (#111):

- **Inter-window spacing** — the gaps *between* tiles, currently niri's built-in default (16px), untuned by this config.
- **Intra-surface padding** — breathing room *inside* a surface (foot `pad`, popup insets, bar padding). Currently unset, so e.g. foot's text crowds the window edges and reads cramped. A shared value or scale should be settled so each surface doesn't make a locally-sensible but divergent call — the same coherence argument this document serves.

### Motion

Window and workspace animation and transition character. Unconfigured today (niri's defaults). **Open** (#111).

### Pointer & icons

Cursor theme and application/notification icon theme, cohering with the host polarity and the chrome's restrained mood; cursor *size* driven by the 4K panel. `stylix.cursor` / `stylix.icons` are unwired today. **Open** (#110). Note the grain of control: cursors are essentially monochrome, so this axis coheres by polarity + size + theme mood, not by base16-palette precision.

### Imagery / wallpaper

Wallpaper direction and any desktop imagery. **Open** (#109).

## Theming mechanism

Stylix runs `autoEnable = false` — the `whitelist > blanket` stance: each target is enabled deliberately, in `home/nixos/stylix-targets-desktop.nix` (desktop) and `home/shared/stylix-targets.nix` (TUI). Surfaces join the palette by being whitelisted. Where Stylix maps an element to a slot or value that doesn't match this document's intent (fuzzel's border → `base0E`, waybar's active workspace → `base05`), the per-surface module overrides it — the deliberate-deviation list this document governs. A spike that flipped `autoEnable = true` to discover such cases also surfaced two targets worth keeping off — `qt` (large closure, no Qt apps) and `gnome` (font conflict) — which reaffirmed the whitelist over a blanket-enable.

**Planned — `lib/theme-tokens.nix`.** The design *tokens* this document defines — colour roles, type sizes, line weights, radii, spacing — are today bare literals repeated at each site (`base0D` typed independently in several modules; `10` in `niri.nix` / `fnott.nix`), the scattering that let the gh-dash/niri accent claim drift out of sync (#333). A thin `lib/theme-tokens.nix` would name each token once (`roles.focus`, `geometry.cornerRadius`, … derived from `config.lib.stylix.colors` so it stays per-host/per-theme correct) and have sites reference it instead of restating it — making this document's vocabulary something the config *inherits* rather than duplicates, optionally guarded by a `lib/stances.nix`-style eval-check. Not yet built; a fast-follow.

## Cadence

Living document, same conventions as `keybinds.md` and `fonts.md`. Decisions land here (or in the relevant per-surface doc) *before* the implementing commit. The document grows by accretion — dimensions are filled in as they are settled, not pre-decided.

## See also

- [ADR-028](../decisions/ADR-028-stylix-foundation-and-desktop-env.md) — Stylix foundation; the palette source-of-truth.
- `fonts.md` / `niri.md` / `fnott.md` / `waybar.md` / `fuzzel.md` — per-surface and per-dimension selections that implement this.
- #106 / #109 / #110 / #111 — the styling tickets that reference this north-star.
