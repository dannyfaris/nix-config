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

Stylix's design distinguishes *naming* (what fontconfig advertises
for the configured monospace / serif / sansSerif / emoji) from
*installation* (what packages actually exist on disk). Both rely on
the operator wiring Stylix's intent into NixOS's surfaces — neither
is automatic.

Two wires, both in `modules/core/nixos/desktop-fonts.nix`:

```nix
stylix.targets.fontconfig.enable = true;
fonts.packages = config.stylix.fonts.packages;
```

**`stylix.targets.fontconfig.enable = true`** activates Stylix's
fontconfig target, which writes `stylix.fonts.*.name` values into
`fonts.fontconfig.defaultFonts.{monospace,serif,sansSerif,emoji}`.
This is what `fc-match` consults and what fontconfig-driven
applications (Firefox, GTK/Qt chrome, anything asking for the
`monospace`/`sans-serif`/etc. aliases) ultimately resolve to. Without
the target enabled, Stylix has the names internally but never writes
them; `fc-match` falls through to NixOS defaults (DejaVu variants).
Note that apps like foot which read `stylix.fonts.monospace.name`
*directly* (via Stylix's per-app targets) bypass this layer and work
regardless — but most desktop chrome (Firefox, GTK/Qt apps) doesn't.

**`fonts.packages = config.stylix.fonts.packages`** installs the
package list Stylix populates (declared at `stylix/fonts.nix:119` in
the Stylix source — the sole producer of the list, with no consumer
upstream). Stylix populates the list for our consumption but does
not push it to `fonts.packages` itself.

Both wires live in `desktop-fonts.nix`, so desktop hosts get the
selections and the install; headless hosts (mercury, nixos-vm) don't
import the module and don't pay the font-package closure cost.

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
  font does not appear to be monospace"). Symptom of the two-wires
  gap: Stylix had `stylix.fonts.monospace.name = "JetBrainsMono Nerd
  Font"` configured but neither wire from §Installation model was
  active — the `JetBrainsMono Nerd Font` package was never in
  `fonts.packages` *and* the fontconfig target was never enabled to
  write the name into `fonts.fontconfig.defaultFonts`. fontconfig
  substituted to whatever it had — on metis, DejaVu Sans
  (proportional). Resolved by enabling both wires (target + install)
  in `desktop-fonts.nix`. The same gap would silently apply to any
  future Stylix font override that doesn't have both wires reaching
  it — be alert.

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
- **Stylix overrides pick themselves up.** Adding a `stylix.fonts.*`
  family override on a desktop host needs no extra wiring — both the
  install (via `fonts.packages = config.stylix.fonts.packages`) and
  the name (via `stylix.targets.fontconfig.enable = true`) reach the
  new value automatically.
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
- `home/core/shared/stylix-targets.nix` — Stylix target enablement
  whitelist.
- `docs/desktop/keybinds.md` — companion living document, same cadence.
- #69 — the foundational close-out under which this document was
  established.
