# Fonts

Font selections for the desktop. Living document — updated when faces
change or installation model evolves.

## Selections

| Family | Package | Name (fontconfig) | Role |
|---|---|---|---|
| Monospace | `pkgs.nerd-fonts.monaspace` | `MonaspiceAr Nerd Font` | terminal + TUIs, status bar, launcher |
| Sans-serif | `pkgs.ibm-plex` | `IBM Plex Sans` | notifications, GTK dialogs, web/document body |
| Serif | `pkgs.dejavu_fonts` | `DejaVu Serif` | Stylix default (rarely consulted) |
| Emoji | `pkgs.noto-fonts-color-emoji` | `Noto Color Emoji` | — |

The governing rule is a **hybrid** split: **mono for the shell
chrome you drive — terminal / status bar / launcher (Omarchy-style);
sans for content surfaces — notifications / dialogs / web
(macOS-style).** Monospace (Monaspace Argon Nerd Font) backs foot and
the TUIs inside it (gh-dash, zellij, starship) *and* waybar *and*
fuzzel; the mono Nerd Font carries waybar's network/tray glyphs
directly, so there is no separate symbols-fallback face. Sans (IBM
Plex Sans) backs the content surfaces: fnott notifications, GTK
dialogs, and web/document body.

This is the third stance on the question. The earlier universal-mono
setup (#283 / #349 / #351) put the terminal's mono face on *every*
chrome surface; the #369 typography pass then reversed it to
all-sans-chrome (mono confined to the terminal). The current hybrid
keeps the sans on content surfaces but returns the *driven* chrome —
bar and launcher — to mono, alongside the terminal, dropping the
`Symbols Nerd Font` fallback the all-sans bar had needed.

## Rationale

**Monospace — Monaspace Argon Nerd Font.** The face for the
terminal (foot plus the TUIs inside it) *and* the driven chrome — the
status bar (waybar) and the launcher (fuzzel). Monaspace is GitHub's
monospace superfamily; Argon is its humanist variant — a warmer, more
readable code face than the geometric JetBrains Mono it replaces,
while still a true fixed-width font. The Nerd Font variant
(`MonaspiceAr Nerd Font`, the family's abbreviated naming) brings the
powerline / devicon / file-type glyphs that starship / zellij / lazygit
rely on — and, on the bar, carries waybar's network/tray glyphs
directly, so no separate glyph-fallback face is installed. Confined to
desktop hosts (metis); not installed on headless hosts (mercury,
nixos-vm), which render no fonts directly.

**Sans-serif — IBM Plex Sans.** The content-surface face and the
`sansSerif` fontconfig slot. Plex Sans is IBM's open humanist sans; it
coheres with the IBM Carbon spacing scale already adopted for
geometry/spacing (visual-identity.md) — distinctive but restrained at
small sizes. It backs the content surfaces — fnott notifications and
GTK dialogs (see §Sizing) — and web/document body text (Firefox)
via the `sans-serif` alias. Replaces Inter, which under the prior
universal-mono stance backed only the web body. (The driven chrome —
bar and launcher — is *not* sans; it rides the terminal mono. See the
governing rule above.)

**Serif — Stylix default (DejaVu Serif).** No explicit selection.
Serif is rarely consulted on this desktop — niri/foot/GTK apps don't
default-render serif. The Stylix default is acceptable until a real
serif need surfaces.

**Emoji — Noto Color Emoji.** Comprehensive emoji coverage with sane
defaults. Coincidentally also provided by NixOS's
`fonts.enableDefaultPackages = true`, so installed on every host (not
just desktop).

## Sizing

The per-surface font sizes are **display-profile-driven**, not fixed
literals. metis runs a **2× niri output scale** (chosen after an
on-panel A/B against 1× and 1.5× — see visual-identity.md §Typography
and niri.md), and one switchable knob, `lib/display-profiles.nix`,
couples the scale to the surface sizes (and the geometry) so they move
in lockstep. The profiles hold *apparent* size constant across scales:
the 1.5× profile carries the agreed on-vocab band, and the 1× / 2×
profiles scale those values by ≈1/scale to render at the same apparent
size at each scale.

At metis's active **2×** profile the rendered sizes are:

- **foot** (terminal) — `terminal` slot, **8**.
- **waybar** (the bar, mono) — `desktop` slot, **10**.
- **fuzzel** (the launcher, mono) — its own profile value (`launcher`),
  **11** — the one deliberately-larger focal element (Spotlight-style).
- **fnott / GTK dialogs** (the sans content surfaces) — `popups` slot,
  **9**.

The 1.5× profile carries the same band one scale up — foot 11 /
waybar 13 / fuzzel 14 / fnott + GTK 12 — which is the on-vocab
reference the other profiles are calibrated against.

**Sizing philosophy: macOS-style restraint, not a dramatic ramp.** The
sizes form a flat band of close values in regular weights, with the
launcher the single intentionally-larger element (Spotlight's prompt).
There is no large role-step ramp — the surfaces sit close together,
and hierarchy comes from the launcher's focal size and from layout, not
from a steep type scale.

Stylix exposes the chrome size taxonomy
(`fonts.sizes.{terminal,desktop,popups,applications}`); the slots are
set from the active profile in `modules/nixos/desktop-fonts.nix`, and
the `type.size` tokens (theme-tokens.nix) alias them. fuzzel's mono
size is read from the profile directly in `home/nixos/fuzzel.nix` (it is
not a Stylix slot). `applications` (the Stylix slot) keeps its default —
it sizes Firefox's variable (body) web text (Stylix derives
`font.size.variable.x-western` from it) and would size Qt apps if any
existed (none today). A re-tune — or a scale change — is a one-line
edit to `display-profiles.nix`.

**GTK application UI uses the sans content face at the popups size.**
GTK app chrome — the polkit prompt, file pickers, app dialogs —
renders in `IBM Plex Sans` at the `popups` size (2× profile: 9), a
`gtk.font` `lib.mkForce` in `home/nixos/stylix-targets-desktop.nix`, so
dialogs match the fnott notification body. GTK is a *content* surface
under the hybrid split (it stays sans), not driven chrome (which is
mono). This is distinct from the earlier mono-app-UI boundary, under
which GTK app-UI was reassigned to the mono Nerd Font (#349; the #108
"how far does Nerd Font go into app-UI" question). Web/document body
text is the `sansSerif` *fontconfig* slot (also IBM Plex Sans). Qt
theming would be a separate lever (none needed — no Qt apps on metis).

**Why the bar and launcher are mono, sized close to the rest.** The
driven chrome (terminal / bar / launcher) shares the terminal's mono
face — an Omarchy-style cohesion across the surfaces the operator
actively drives — while content surfaces (notifications / dialogs /
web) stay sans (macOS-style). Within the mono chrome, the bar sits
small and the launcher larger; the terminal is sized on its own
legibility terms. The band stays flat by intent (see the sizing
philosophy above), so the surfaces read as one family rather than a
stepped scale.

**Why foot's size is a profile value, not a bare literal (the
dpi-aware story).** foot pins `dpi-aware = no` (written by Stylix's
foot target; documented in `home/nixos/foot.nix`). Under `no`,
`:size=N` is sized by the **output scale factor**, not the monitor's
physical DPI — the same factor the Wayland apps scale by — so the
profile's per-scale calibration (size ∝ 1/scale) lands a consistent
apparent size across surfaces and scales. Pinning `no` is a deliberate
*portability* choice: under foot's former `auto` default an identical
`:size=N` rendered at different apparent sizes across monitors of
differing DPI/scale (foot issue #714); `no` makes it reproducible, and
is what lets the display profile own the sizing.

A prior revision of this doc claimed a fixed value (`11`)
"approximates the prior visual size" lost when foot 1.15.0 flipped
`dpi-aware` from `auto` to `no`. That rationale was unfounded: `auto`
only used DPI-based sizing when *every* output was at scale 1, and used
scale-factor sizing otherwise — so on any scaled output (metis is
scaled) the `auto → no` change was a **no-op**: foot rendered `:size=N`
identically before and after. The terminal size is a deliberate
legibility choice carried by the display profile, not DPI compensation.
(The 1.15.0 default change itself is real — confirmed against foot's
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

No glyph-only face is installed. Under the all-sans-chrome stance the
bar's sans needed a `nerd-fonts.symbols-only` fallback for its
network/tray glyphs; the hybrid model returns the bar to the mono Nerd
Font (Monaspace Argon), which carries those glyphs inline, so the
extra package was dropped along with the fallback.

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
the NixOS module sizes its surfaces from the active display profile
(see §Sizing) and on Darwin Ghostty owns its own sizing, so there's
nothing to mirror.

Consequence: Darwin installs the faces but has no fontconfig alias
layer. Stylix's ghostty target *does* set Ghostty's font-family from
the monospace slot (`home/darwin/ghostty.nix`), so the terminal
re-renders to Monaspace Argon — one terminal face across hosts (the
operator keeps Ghostty's own size pin). The sans is availability-only:
macOS chrome uses the system font, so IBM Plex Sans backs the
sans-serif alias for fontconfig-aware apps rather than re-skinning
native UI. The module is imported from `modules/darwin/foundation.nix`
rather than a desktop bundle, because every Darwin host is GUI (no
headless gate to respect). Per #209.

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
  issue #714), and what lets the display profile own the terminal's
  sizing (size ∝ 1/scale, holding apparent size). See §Sizing for the
  full story, including why an earlier "fixed size compensates for the
  1.15.0 change" rationale was unfounded. Original landing: PR #63.

- **No universal monospace.** Earlier iterations claimed monospace
  was a foundation-level concern (universal across all hosts); this
  was a misread. Headless NixOS hosts don't render fonts. The mono
  face (Monaspace Argon) configuration lives on *GUI* hosts only —
  every desktop NixOS host (via the desktop-env bundle) and every
  Darwin host (via foundation, since all Darwin hosts are GUI).
  Headless NixOS hosts (mercury, nixos-vm) still get nothing.

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
