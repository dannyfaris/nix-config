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
on-screen reading at small sizes. Backs the `sansSerif` fontconfig
slot — web/document sans-serif body text (Firefox/Zen page content)
and the `sans-serif` alias generally. (GTK *application* chrome was
reassigned to the mono Nerd Font for cohesion — see §Sizing.) Common
choice for Linux desktop UI; well-supported by fontconfig.

**Serif — Stylix default (DejaVu Serif).** No explicit selection.
Serif is rarely consulted on this desktop — niri/foot/GTK apps don't
default-render serif. The Stylix default is acceptable until a real
serif need surfaces.

**Emoji — Noto Color Emoji.** Comprehensive emoji coverage with sane
defaults. Coincidentally also provided by NixOS's
`fonts.enableDefaultPackages = true`, so installed on every host (not
just desktop).

## Sizing

The four desktop surfaces — foot (terminal), waybar (status bar),
fuzzel (launcher), fnott (notifications) — render at **one shared
point size (11)** for cross-surface cohesion. Stylix exposes a size
taxonomy (`fonts.sizes.{terminal,desktop,popups,applications}`); the
three slots those four surfaces consume (`terminal`, `desktop`,
`popups`) are pinned equal in `modules/nixos/desktop-fonts.nix`.
`applications` (the Stylix size slot, 12) keeps its default — on metis
it now sizes Firefox's variable (body) web text (Stylix derives
`font.size.variable.x-western` from this slot) and would size Qt apps
if any existed (none today). GTK app-UI no longer consumes it (see
below).

**GTK application UI also uses the mono Nerd Font.** GTK app chrome —
the polkit prompt, GTK file pickers, GTK app dialogs — would otherwise
render in the `sansSerif` slot (Inter 12) that Stylix's `gtk` target
defaults to, standing out against the mono chrome. It's overridden to
the mono Nerd Font at 11 (a `gtk.font` `lib.mkForce` in
`home/nixos/stylix-targets-desktop.nix`), so GTK dialogs match
foot/waybar/fuzzel/fnott. This realizes the #108 "how far does Nerd
Font go into app-UI" boundary for GTK app-UI; **web/document body text
is unaffected** — that is the `sansSerif` *fontconfig* slot, still
Inter. Qt theming would be a separate lever (none needed — no Qt apps
on metis).

**Why one size, not a larger terminal.** There is no documented
typographic basis for a terminal to sit *larger* than surrounding
chrome; design-system practice sizes type by role and content-length,
and the continuously-read body surface (the terminal) warrants a size
*at least equal to* chrome, never smaller — equal satisfies that. A
deliberate per-surface delta would be a legibility preference, not a
rule; absent one, a single number reads consistently and is the
simpler default.

**Why a bare number works here (the dpi-aware story, corrected).**
foot pins `dpi-aware = no` (written by Stylix's foot target;
documented in `home/nixos/foot.nix`). Under `no`, `:size=N` is sized
by the **output scale factor**, not the monitor's physical DPI — the
same factor the Wayland chrome apps scale by — so a numerically-equal
size scales together across all four surfaces and reads consistently
regardless of the display's scale. Pinning `no` is a deliberate
*portability*
choice: under foot's former `auto` default an identical `:size=N`
rendered at different apparent sizes across monitors of differing
DPI/scale (foot issue #714); `no` makes it reproducible.

A prior revision of this doc claimed the value `11` "approximates the
prior visual size" lost when foot 1.15.0 flipped `dpi-aware` from
`auto` to `no`. That rationale was unfounded: `auto` only used
DPI-based sizing when *every* output was at scale 1, and used
scale-factor sizing otherwise — so on any scaled output (metis runs
at scale 1.5) the `auto → no` change was a **no-op**: foot rendered
`:size=N` identically before and after. The `11` is a deliberate
legibility/cohesion choice, not DPI compensation. (The
1.15.0 default change itself is real — confirmed against foot's
CHANGELOG and `foot.ini(5)` — only the causal sizing story was wrong.)

## Installation model

Stylix's design distinguishes *naming* (what fontconfig advertises
for the configured monospace / serif / sansSerif / emoji) from
*installation* (what packages actually exist on disk). Both rely on
the operator wiring Stylix's intent into NixOS's surfaces — neither
is automatic.

Two wires, both in `modules/nixos/desktop-fonts.nix`:

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

### Darwin

macOS hosts mirror the *install* wire but not the *naming* one.
`modules/darwin/desktop-fonts.nix` declares the same monospace / sans /
emoji selections and installs them via nix-darwin's `fonts.packages =
config.stylix.fonts.packages`, which symlinks the faces into
`/Library/Fonts` (the system-wide font directory). After activation the
faces are selectable by name in any Mac app through Core Text / Font
Book.

The fontconfig wire is deliberately absent: macOS resolves fonts via
Core Text, which reads `/Library/Fonts` directly, so
`stylix.targets.fontconfig.enable` would write a `defaultFonts` map
nothing on the platform consults. Font sizes are likewise omitted —
the NixOS module unifies the desktop surfaces on one point size (see
§Sizing) and on Darwin Ghostty owns its own sizing, so there's nothing
to mirror.

Consequence: Darwin installs the faces but has no alias layer, and
Ghostty bundles its own JetBrainsMono — so the practical effect is
*availability + parity*, not an automatic re-render anywhere. The
module is imported from `modules/darwin/foundation.nix` rather than a
desktop bundle, because every Darwin host is GUI (no headless gate to
respect). Per #209.

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
  from `auto` to `no` (and removed `auto`), which Stylix's foot target
  adopts verbatim. Under `no`, `:size=N` is sized by the output scale
  factor, not the monitor DPI — a deliberate portability win (foot
  issue #714), and the basis for one shared size reading consistently
  across surfaces. See §Sizing for the full story, including why an
  earlier "11 compensates for the 1.15.0 change" rationale was
  unfounded. Original landing: PR #63.

- **No universal monospace.** Earlier iterations claimed monospace
  was a foundation-level concern (universal across all hosts); this
  was a misread. Headless NixOS hosts don't render fonts. JetBrains
  Mono Nerd Font configuration lives on *GUI* hosts only — every
  desktop NixOS host (via the desktop-env bundle) and every Darwin
  host (via foundation, since all Darwin hosts are GUI). Headless
  NixOS hosts (mercury, nixos-vm) still get nothing.

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

- `modules/nixos/desktop-fonts.nix` — Stylix font config + install
  wiring for desktop NixOS hosts.
- `modules/darwin/desktop-fonts.nix` — Darwin parallel: same
  selections, install-only (no fontconfig target), imported by
  Darwin foundation.
- `modules/nixos/stylix-palette.nix` — Stylix base config: the
  module enable + per-host base16 palette (no font selections;
  deliberately). Imported by foundation, so it reaches every host.
- `home/nixos/foot.nix` — foot terminal config; consumes
  `stylix.fonts.monospace.name` via Stylix's foot target.
- `home/shared/stylix-targets.nix` — Stylix target enablement
  whitelist.
- `docs/desktop/keybinds.md` — companion living document, same cadence.
- #69 — the foundational close-out under which this document was
  established.
