# Fuzzel

Wayland-native application launcher. Same project family as foot
(dnkl on codeberg); same philosophy — small closure, no runtime
ballast, built for the wlroots/niri lineage. Bound to Mod+Space per
the macOS Spotlight pattern.

## Selection

**fuzzel** on metis. Enabled via `home/nixos/fuzzel.nix` (HM
module `programs.fuzzel.enable = true`). Bound to `Mod+Space` in
`home/nixos/niri.nix`. Stylix integration via
`stylix.targets.fuzzel.enable = true` in
`home/shared/stylix-targets.nix`.

## Rationale

**Same dnkl family as foot; same architectural fit for niri.** Foot
and fuzzel are both written by dnkl, share idioms (INI config, signal
handling, debug output), and are designed for the wlroots/niri/sway
lineage. We accepted that family for the terminal (#72); fuzzel is
the consistent extension on the launcher side. Small Wayland-native
compositor, small Wayland-native terminal, small Wayland-native
launcher — same posture across the chrome.

**Niri community default.** Fuzzel is the launcher most niri configs
reach for; niri's own docs reference it; sodiboo's niri-flake
examples include it. Not deterministic, but a strong signal that the
combination is well-trodden.

**Mod+Space matches macOS Spotlight muscle memory.** The operator's
day-to-day spans Linux desktop + macOS; binding the launcher to the
same key on both platforms keeps muscle memory consistent without
forcing either side to adopt the other's conventions.

## Alternatives considered

**rofi-wayland** — Wayland fork of the X11-only upstream rofi.
Mature, lots of themes, dmenu + launcher in one. Passed over: larger
closure (cairo + GTK dependencies); fork status means it tracks
upstream rofi rather than being a first-class project; heavier than
necessary when we don't exercise the theme/plugin breadth.

**anyrun** — Plugin-based Rust launcher. Active. Passed over because
the plugin model adds complexity we won't exercise for a single-user
solo setup; closure includes Rust runtime + plugin host overhead.

**walker** — Go-based launcher with plugin support. Active. Passed
over for similar reasons to anyrun; smaller community + niri-specific
adoption than fuzzel.

**tofi** — Single-binary minimal launcher, similar philosophy to
fuzzel. The real alternative if fuzzel didn't exist. Passed over
because fuzzel is the niri-community default and is part of the
dnkl family alongside foot — project-coherence outweighs tofi's
narrowly-comparable footprint.

**bemenu** — Wayland-native dmenu clone. Different category (dmenu
mode only, no `.desktop` app launcher). Could pair with another tool
to do what fuzzel does in one — extra moving part for no win.

## Configuration

**HM module** — `home/nixos/fuzzel.nix`:

```nix
{ ... }:
{
  programs.fuzzel = {
    enable = true;
    settings.main = {
      layer = "overlay";       # Spotlight-like full-screen takeover
      anchor = "top";          # Anchored toward the top edge
      terminal = "foot";       # For .desktop files with Terminal=true
    };
  };
}
```

Lives under `home/nixos/` because fuzzel is Wayland-only and
doesn't compile off Linux — there is no cross-platform variant to
share. Same placement reasoning as `home/nixos/foot.nix`; the
shared-purity rule (ADR-027) gates `home/shared/` on packages
that build on both NixOS and Darwin, which fuzzel doesn't. Imported
into the desktop-env HM bundle.

Visible-line count, width, padding, and other layout values use
fuzzel's defaults — explicitly not tuned for pixel-Spotlight parity.
See Sharp edges if visual footprint reads wrong later.

**Stylix integration** — `home/shared/stylix-targets.nix`:

```nix
stylix.targets.fuzzel.enable = true;
```

Stylix writes two sets of `programs.fuzzel.settings`:
- `colors.*` — full base16 palette mapped to fuzzel's eleven colour
  slots (background, text, prompt, match, selection, etc.).
- `main.icon-theme` — picked from `stylix.polarity` via
  `stylix.icons.{dark,light}`.

`home/nixos/fuzzel.nix` makes a few overrides. **Font**: `main.font` is
set to the mono Nerd Font (`JetBrainsMono Nerd Font` at
`stylix.fonts.sizes.popups`) via `lib.mkForce`, rather than the
sansSerif slot (Inter) Stylix defaults to — so the launcher matches the
rest of the chrome (foot, waybar). **Border**: `border.width = 2` (crisp
on metis's 4K panel at scale 1.5) and `colors.border → base0D`, the
idiomatic focus accent, matching niri's window border. Stylix maps the
border to base0E; the two slots are equal on metis's palette today, so
the colour is a no-op *there* but correct by slot for portability. Other
colours come from Stylix unchanged; the operator-facing settings
(layer/anchor/terminal) are behaviour, not theming. See the accent map
(#108).

**Keybind** — `home/nixos/niri.nix`:

```nix
"Mod+Space".action.spawn = "fuzzel";
```

Per the macOS Spotlight muscle-memory pattern. This is the
launcher-side interim deviation flagged in `keybinds.md`'s
Implementation status table; the philosophical target if a Hyper
layer is ever realised would be `Hyper+Space`. The keybinds doc
updates in this PR's third commit.

## Sharp edges

**`Mod+Space` is reserved space in the keybinds philosophy.** The
three-namespace model in `keybinds.md` reserves `Hyper+Space` for
launcher under a hypothetical Hyper modifier (via keyd or
equivalent). The Hyper layer isn't implemented; `Mod+Space` is the
interim home. If Hyper ever lands, this bind migrates to
`Hyper+Space` cleanly (one line in niri config). Restated here so a
future contributor reading fuzzel.md alone doesn't wonder why we're
on `Mod+` instead of `Hyper+`.

**Layout values stay at fuzzel's defaults.** Visible-line count
(15), width (30 chars), padding, and similar layout values are
fuzzel's defaults — explicitly accepted day-1 rather than tuned
toward pixel-Spotlight parity. If the visual footprint reads wrong
in actual use, add `lines = N`, `width = N`, or padding tweaks to
`settings.main`. The shape is easier to feel than to spec, so we
defer the tuning until the desktop sees real wear.

**`.desktop`-file Terminal=true requires the `terminal` setting.**
Without `terminal = "foot"`, fuzzel falls back to whatever it
guesses for CLI apps (often `xterm`, which we don't install) and
the launch silently fails. The setting above wires it explicitly.

**`icon-theme` not written until `stylix.icons` is configured.**
The §Configuration claim that Stylix writes
`programs.fuzzel.settings.main.icon-theme` is conditional on
`stylix.icons.{dark,light}` being set. We haven't configured those,
so the generated `fuzzel.ini` carries no `icon-theme=` line and
fuzzel falls back to whatever icon theme it picks by default. Not a
launcher-functionality blocker (`.desktop` apps still launch); only
affects icon glyph rendering inside the launcher overlay. Separate
follow-up if/when icon-theme integration matters.

**Wayland-only; Linux-only build.** Fuzzel doesn't compile off
Linux — same constraint as foot. Hence the `home/nixos/`
placement (per Configuration). If a Darwin host ever imports the
desktop-env HM bundle directly, eval will fail on `pkgs.fuzzel`.
Mac side gets its own launcher when `home/darwin/` lands
(per the mac-mini onboarding epic #11) — likely Raycast or
Alfred via nix-darwin's app management, not a port of fuzzel.

## References

- [`home/nixos/fuzzel.nix`](../../home/nixos/fuzzel.nix)
  — the HM module enabling fuzzel.
- [`home/shared/stylix-targets.nix`](../../home/shared/stylix-targets.nix)
  — `stylix.targets.fuzzel.enable = true`.
- [`home/nixos/niri.nix`](../../home/nixos/niri.nix) —
  `Mod+Space` → fuzzel bind.
- [keybinds.md](./keybinds.md) — modifier-namespace philosophy;
  Implementation status's "interim deviations" section captures the
  `Mod+Space` → eventual `Hyper+Space` migration story.
- [foot.md](./foot.md) — sibling dnkl-family project; terminal that
  fuzzel spawns for `.desktop` files with `Terminal=true`.
- fuzzel upstream — https://codeberg.org/dnkl/fuzzel
