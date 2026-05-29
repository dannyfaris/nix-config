# Fonts

Font selections for the desktop. Living document — updated when faces
change or installation model evolves.

## Selections

| Family | Package | Name (fontconfig) |
|---|---|---|
| Monospace | `pkgs.nerd-fonts.jetbrains-mono` | `JetBrainsMono Nerd Font` |
| Sans-serif | `pkgs.inter` | `Inter` |
| Serif | `pkgs.dejavu_fonts` | `DejaVu Serif` |
| Emoji | `pkgs.noto-fonts-color-emoji` | `Noto Color Emoji` |

## Rationale

**Monospace — JetBrains Mono Nerd Font.** Primary terminal face. Nerd
Font variant brings the icon glyphs (powerline, devicons, file-type
markers) that starship/zellij/lazygit and other TUI chrome rely on.
Ligature support is welcome for code work in foot. Confined to desktop
hosts (metis); not installed on headless hosts (mercury, nixos-vm)
since nothing on those hosts renders fonts directly — SSH clients use
their own.

**Sans-serif — Inter.** Modern humanist UI typeface optimised for
on-screen reading at small sizes. Used by GTK/Qt application chrome
via Stylix's targets. Common choice for Linux desktop UI;
well-supported by fontconfig.

**Serif — Stylix default (DejaVu Serif).** No explicit selection.
Serif is rarely consulted on this desktop — niri/foot/GTK apps don't
default-render serif. The Stylix default is acceptable until a real
serif need surfaces.

**Emoji — Noto Color Emoji.** Comprehensive emoji coverage with sane
defaults. Coincidentally also provided by NixOS's
`fonts.enableDefaultPackages = true`, so installed on every host (not
just desktop).

## Installation model

Stylix's design distinguishes *naming* (what fontconfig advertises as
the configured monospace / serif / sansSerif / emoji) from
*installation* (what packages actually exist on disk). Stylix sets
the names via `fonts.fontconfig.defaultFonts`; it populates a
`stylix.fonts.packages` list of the configured packages (declared at
`stylix/fonts.nix:119` in the Stylix source — the sole producer of
the list, with no consumer) **but does not push that list to
`fonts.packages`.** Installation is the operator's responsibility.

We wire installation centrally on desktop hosts via:

```nix
fonts.packages = config.stylix.fonts.packages;
```

in `modules/core/nixos/desktop-fonts.nix`. This installs all four
Stylix-configured families on desktop hosts only. Headless hosts
don't import `desktop-fonts.nix` and don't pay the font-package
closure cost.

The general (non-desktop-specific) font base comes from NixOS's
`fonts.enableDefaultPackages = true` (set as `mkDefault true` by
niri-flake): `dejavu_fonts`, `freefont_ttf`, `gyre-fonts`,
`liberation_ttf`, `unifont`, and `noto-fonts-color-emoji`. These
give sensible coverage for terminals, console, and apps that don't
consult the Stylix-configured names. Flipping
`enableDefaultPackages = false` would mean curating the entire base
set ourselves; deliberately not done.

## Sharp edges

- **DejaVu Sans fallback warning** (foot launching with "DejaVu Sans:
  font does not appear to be monospace"). Symptom of the installation
  gap: Stylix set `fonts.fontconfig.defaultFonts.monospace =
  "JetBrainsMono Nerd Font"` but the package was never in
  `fonts.packages`, so fontconfig substituted to whatever it had —
  on metis, DejaVu Sans (proportional). Resolved by the
  `fonts.packages = config.stylix.fonts.packages;` wiring on desktop
  hosts. The same gap would silently apply to any future Stylix font
  override that doesn't land in `fonts.packages` — be alert.

- **foot's `dpi-aware = no` default.** foot 1.15.0 changed `dpi-aware`
  from `auto` to `no`, which Stylix's foot target adopts verbatim.
  Under that default, `:size=N` (points) is multiplied by the
  compositor scale rather than the monitor DPI; on a scale-1 output
  the historical sizing reads smaller. `stylix.fonts.sizes.terminal =
  11` approximates the prior visual size on metis. May retune as
  monitor / scale changes accumulate. Original landing: PR #63.

- **No universal monospace.** Earlier iterations claimed monospace
  was a foundation-level concern (universal across all hosts); this
  was a misread. Headless hosts don't render fonts. JetBrains Mono
  Nerd Font configuration lives on desktop hosts only.

## Cadence

Living document — same conventions as `keybinds.md`. Font selections
change rarely (this is not a curation project — see Installation
model), so the cadence is lighter than for keybinds.

- **Doc precedes implementation.** Font changes land first as a
  selection-table row here; the implementing commit follows in the
  same PR.
- **Stylix overrides install themselves.** Adding a `stylix.fonts.*`
  family override on a desktop host needs no extra `fonts.packages`
  wiring — the central `fonts.packages = config.stylix.fonts.packages`
  line picks it up automatically.
- **No silent installs.** Anything in `fonts.packages` not implied
  by `stylix.fonts.*` (via the central wiring above) or NixOS
  defaults is a cadence bug — document the addition here.

## See also

- `modules/core/nixos/desktop-fonts.nix` — Stylix font config + install
  wiring for desktop hosts.
- `modules/core/nixos/foundation.nix` — Stylix base config (no font
  selections; deliberately).
- `home/core/nixos/foot.nix` — foot terminal config; consumes
  `stylix.fonts.monospace.name` via Stylix's foot target.
- `home/core/shared/bundles/theming.nix` — Stylix target enablement
  whitelist.
- `docs/desktop/keybinds.md` — companion living document, same cadence.
- #69 — the foundational close-out under which this document was
  established.
