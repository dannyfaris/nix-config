# Visual identity

The desktop's aesthetic north-star. Living document — the per-surface styling tickets (wallpaper #109, pointer/icons #110, compositor styling #111, display #106) reference and implement against it, rather than each making locally-sensible but divergent choices. It sets *intent*; the per-tool selection docs (`niri.md`, `fnott.md`, `waybar.md`, `fuzzel.md`, `fonts.md`) record the specific selections that serve it.

## Principles

- **Stylix is the theme source-of-truth** (ADR-028). Every themed surface derives from one base16 palette; nothing hard-codes a colour.
- **base16-idiomatic by default; deviate only deliberately.** Lean on the slots' conventional tones — `base0D` as the primary accent, `base08` (red) for error/critical, `base03` for muted/inactive — and assign UI-chrome roles to tonally-fitting slots rather than inventing per-surface colours. A deviation is legitimate only as a conscious override where the default doesn't suit; never as drift.
- **Name colours by slot, never by tone.** `base0D`, not "iris" — a tone is only what a slot resolves to under the *current* theme. Only slot-references survive a theme switch.
- **Coherence must survive a theme/polarity change.** The test of any decision: does it still hold if the scheme changes? If it relies on a tone, it doesn't.

## Accent discipline — semantic role → slot

The chrome speaks a small, fixed vocabulary of signals, each pinned to one slot:

| Role | Slot | Meaning | Surfaces |
|---|---|---|---|
| **Focus** | `base0D` | the surface that holds focus | niri active window, fuzzel, waybar active workspace, gh-dash focused section |
| **Attention** | `base09` | chrome shown *without* taking focus | fnott normal-urgency notification |
| **Critical** | `base08` | error / urgent | fnott critical, waybar urgent |
| **Muted** | `base03` | inactive | niri inactive window, fnott low |

Focus rides base16's canonical accent slot (`base0D`); the other roles are deliberate app-level assignments to tonally-fitting slots — `base09` (a warm tone) for attention, `base08` (red) for critical, `base03` for muted. base16 does not itself prescribe UI-chrome roles, so this map is ours to hold consistently.

The load-bearing rule is the **focus / attention boundary**: a surface uses the *focus* accent if it holds focus when active — which includes overlays like the launcher and the auth prompt, because when active they *become* the focused window, so their accent can never clash with a focus they don't own. The *attention* accent is reserved for chrome that appears **without** taking focus — today only notifications — which therefore coexists with a separately-focused window and must read as distinct from it.

On metis the per-host palette override makes `base0D == base0E` (both resolve to the same tone today), so every focus surface currently reads identically; the discipline is expressed *by slot* so it stays coherent under any other scheme, where the slots diverge.

## Decided treatments

Chrome borders are **2px** with a **10px corner radius** (`clip-to-geometry`, so each client's square surface is trimmed to the rounded rect). 2px is deliberate for metis's 3840×2160 panel at scale 1.5: an even logical width maps to whole physical pixels and renders crisp, where 1px lands on the half-pixel grid and looks grainy on the curve. The role colours and the geometry are applied per surface in the relevant module — compositor target, launcher config, bar CSS, daemon config — with the rationale in each per-surface doc; the cross-surface accent vocabulary is this document's. The first set of these treatments is implemented in #358.

## Theming mechanism

Stylix runs `autoEnable = false` — the `whitelist > blanket` stance: each target is enabled deliberately, in `home/nixos/stylix-targets-desktop.nix` (desktop) and `home/shared/stylix-targets.nix` (TUI). Surfaces join the palette by being whitelisted. Where Stylix maps an accent-role element to a slot that doesn't match the role map (fuzzel's border → `base0E`, waybar's active workspace → `base05`), the per-surface module overrides it to the role's slot; these deliberate deviations are the override list this document governs. A spike that flipped `autoEnable = true` to discover such cases also surfaced two targets worth keeping off — `qt` (large closure, no Qt apps) and `gnome` (font conflict) — which reaffirmed the whitelist over a blanket-enable.

**Planned — `lib/theme-tokens.nix`.** The role map and the 2px/10px geometry are the desktop's design *tokens*, but each is currently a bare literal repeated at every override site (`base0D` typed independently in `fuzzel.nix` / `waybar.nix` / `gh-dash.nix`; `10` in `niri.nix` / `fnott.nix`) — the same scattering that let the gh-dash/niri accent claim drift out of sync (#333). A thin `lib/theme-tokens.nix` would name each token once (`roles.focus`, `geometry.cornerRadius`, … derived from `config.lib.stylix.colors` so it stays per-host/per-theme correct) and have the override sites reference it instead of restating it — making this document's vocabulary something the config *inherits* rather than duplicates, optionally guarded by a `lib/stances.nix`-style eval-check. Not yet built; a fast-follow once this doc lands.

## Open surface

Tracked, not yet decided — each owned by its ticket:

- **Display scale** — 1.5 is the decided scale (the 2px/10px geometry rests on it); the open work is *pinning* it deliberately rather than leaving niri's auto-pick (#106).
- **Spacing / density** — niri gaps are 16px today; not yet deliberately tuned (#111).
- **Motion / animation character** (#111).
- **Corner-radius value** — 10px is the current choice; revisit if it reads heavy on large windows (#111).
- **Cursor + icon feel** — `stylix.cursor` / `stylix.icons` are unwired (#110).
- **Wallpaper direction** (#109).
- **Font maximalism boundary** — chrome, TUI, and GTK app-UI are mono (`fonts.md`); web/document body text stays Inter. Whether body text also goes mono is the remaining open step (see this issue's history and #351).

## Cadence

Living document, same conventions as `keybinds.md` and `fonts.md`. Decisions land here (or in the relevant per-surface doc) *before* the implementing commit. The document grows from decisions actually made, not from aspiration — entries are added as surfaces are settled, not pre-filled.

## See also

- [ADR-028](../decisions/ADR-028-stylix-foundation-and-desktop-env.md) — Stylix foundation; the palette source-of-truth.
- `niri.md` / `fnott.md` / `waybar.md` / `fuzzel.md` / `fonts.md` — per-surface selections that implement this.
- #106 / #109 / #110 / #111 — the styling tickets that reference this north-star.
