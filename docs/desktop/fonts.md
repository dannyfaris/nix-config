# Fonts

Font selections and the runtime font model for the desktop. Living document — updated when faces change or the installation/runtime model evolves.

## Model — fontconfig owns fonts at runtime

The desktop's fonts are **conducted by fontconfig**, not pinned per-app by Stylix. Every surface that can asks for a *generic* family (`monospace`, `sans-serif`, `serif`); fontconfig resolves each generic to a concrete face through one mapping; changing that mapping re-themes every generic-consuming surface at once. This is the font analogue of how Noctalia owns colour at runtime (ADR-036): theming is mutable, user-space, and not re-stamped by `nh os switch`.

Two consequences fall out, and both are deliberate goals (#390):

1. **Runtime, user-space, persistent control.** The generic→face mapping lives in `~/.config/fontconfig/conf.d/`; new faces drop into `~/.local/share/fonts`. Editing either takes effect on the next surface launch — no rebuild — and persists across rebuilds, because Nix does not manage those paths. See §Runtime UX.
2. **Consistency by construction.** Because every surface resolves the same generic, one mapping drives the terminal, GTK chrome, the web fallback, and Noctalia's own shell surfaces together.

Stylix is no longer the font source of truth on the desktop. Its model is to hardcode a concrete face into each app's config and re-assert it on rebuild — which clobbers an imperative change and scatters faces instead of pointing at one mapping, incompatible with both goals. So the desktop's fonts moved off it (#390). Stylix stays the static colour table under E1 (ADR-036, §Refinement) and remains fully authoritative on every non-desktop host.

## Selections

| Generic | Face | Package | Backs |
|---|---|---|---|
| `monospace` | Monaspace Argon Nerd Font | `pkgs.nerd-fonts.monaspace` | foot + the TUIs inside it (gh-dash, zellij, starship, lazygit) |
| `sans-serif` | Inter | `pkgs.inter` | GTK dialogs, Firefox web body, the fontconfig sans default; Noctalia's own surfaces (it defaults to the `Sans Serif` generic) |
| `serif` | DejaVu Serif (uncurated) | — (NixOS base) | rare serif-requesting web pages; resolves to the base face, not a curated pick |
| `emoji` | Noto Color Emoji | `pkgs.noto-fonts-color-emoji` | colour-emoji glyphs (web, notifications) |

Only the faces something actually consumes are installed (whitelist > blanket): the NixOS desktop set is **Monaspace + Inter + Noto emoji**. Serif is *not* installed as a desktop selection — it resolves to the DejaVu the NixOS base set already ships (§Installation model). Headless hosts (mercury, nixos-vm) render no fonts and install none.

**Mono — Monaspace Argon Nerd Font.** GitHub's humanist monospace superfamily; the Nerd Font variant carries the powerline/devicon/file-type glyphs starship/zellij/lazygit rely on. Backs the terminal and the TUIs inside it. The fontconfig name is the family's abbreviation, `MonaspiceAr Nerd Font`.

**Sans — Inter.** Backs the `sans-serif` generic — GTK chrome and web body. Replaces IBM Plex Sans; the *why*, and the reversal of the prior "Decided" choice, are single-sourced in `visual-identity.md` §Typography.

**Serif — uncurated.** Nothing on the desktop default-renders serif; the only consumer is a web page that explicitly requests `serif`. It resolves to the base `DejaVu Serif` (shipped by `fonts.enableDefaultPackages`), so we install no serif of our own and stop curating the slot. (Firefox carries a `serif` web-font pref, so the slot is not literally unconsumed — but it resolves to the base face either way.)

**Emoji — Noto Color Emoji.** Comprehensive coverage with sane defaults; also provided by `fonts.enableDefaultPackages`, so present fleet-wide.

### History — the retired hybrid model

Before Noctalia (ADR-036) the desktop ran a per-tool stack (waybar / fuzzel / fnott), and this doc governed a **hybrid** typography split: mono for the *driven* chrome (terminal / bar / launcher, Omarchy-style) and sans for *content* surfaces (notifications / dialogs / web, macOS-style) — the third stance after universal-mono (#283 / #349 / #351) and all-sans-chrome (#369). Noctalia subsumed the bar / launcher / notification surfaces and themes them itself, so that split no longer applies: the Nix-managed faces back only the terminal/TUIs (mono) and GTK/web (sans), and Noctalia's surfaces follow the generics on their own. The `Symbols Nerd Font` fallback the all-sans bar once needed is also gone — the mono Nerd Font carried those glyphs, and the bar is Noctalia's now regardless.

## Runtime UX — changing a font

The runtime knob is `~/.config/fontconfig/conf.d/` — a directory you own (home-manager manages only its *own* files there and never touches yours, so overrides persist across rebuilds). The `set-font` helper (packaged in Nix, on every desktop host) is the everyday front-end: it writes a small per-generic override file (`99-setfont-<generic>.conf`) so a change is a one-liner rather than hand-authored XML:

```bash
set-font sans Inter            # remap the sans-serif generic
set-font mono "JetBrains Mono" # remap monospace; signals open foot
set-font --reset               # remove the override, fall back to the Nix baseline
set-font --show                # fc-match the generics
set-font mono X --reload-shell # any of the above, plus restart Noctalia (opt-in)
```

The *tool* is declarative (Nix); the *selection it writes* is the mutable user-space seam. `--reset` clears the files it wrote; editing a `conf.d/*.conf` by hand works too — `set-font` just automates the common case. To use a face that isn't in the Nix baseline, drop it into `~/.local/share/fonts`, run `fc-cache -f`, then `set-font`.

**What updates, and when.** The edit is instant for `fc-match`; a surface picks it up when it next starts — fontconfig is not a live-repaint bus (no different from Noctalia's colour story, which signals per app). New foot/GTK windows reflect the change, and `set-font` nudges already-open foot automatically (`USR1`). **Noctalia caches fonts at process start**, so its bar/launcher re-resolve only on a restart — `set-font … --reload-shell` does that on demand (opt-in; bouncing the shell is disruptive, so it is not the default), and `set-font` prints a hint when a Noctalia is running and the flag was omitted. The override wins over the Nix baseline by fontconfig's **include order** (user `conf.d` is read early, via `/etc/fonts/conf.d/50-user.conf`, and `<prefer>` prepends to the family list) — *not* because of the `99-` number, which is cosmetic.

The mapping is a *global generic* remap, not a per-surface override; a single surface's font is its own (declarative) config. fontconfig conducts the *face*, not the *size* — sizes stay a declarative concern (§Sizing).

## Sizing

The per-surface font sizes are **display-profile-driven**, not fixed literals — a NixOS desktop host's sizes track its niri output scale. metis (the first such host) runs a **2× scale** (chosen after an on-panel A/B against 1× and 1.5× — see visual-identity.md §Typography and niri.md), and one switchable knob, `lib/display-profiles.nix`, couples the scale to the surface sizes (and the geometry) so they move in lockstep. The profiles hold *apparent* size constant across scales: the 1.5× profile carries the on-vocab band, and the 1× / 2× profiles scale those values by ≈1/scale to render at the same apparent size.

At metis's active **2×** profile the Nix-managed rendered sizes are:

- **foot** (terminal) — `terminal` slot, **8**, read from the profile directly in `home/nixos/foot.nix`.
- **GTK dialogs** (the polkit prompt, file pickers, app dialogs) — `popups` slot, **9**, a `gtk.font` `lib.mkForce` in `home/nixos/stylix-targets-desktop.nix`.
- **Firefox** web body — the `applications` slot (Stylix default, **12**), from which the Firefox target derives `font.size.variable.x-western`.

Noctalia sizes its *own* surfaces (its `fontScale` / per-widget settings); waybar / fuzzel are gone. The 1.5× profile carries the same band one scale up (foot 11 / GTK 12) as the on-vocab reference the other profiles calibrate against.

**Sizing philosophy: macOS-style restraint.** Close values in regular weights; hierarchy comes from layout, not a steep type scale. The size taxonomy still lives on `stylix.fonts.sizes.{terminal,popups,applications}` (set from the active profile in `modules/nixos/desktop-fonts.nix`, aliased by the `type.size` tokens in theme-tokens.nix) — Stylix stays enabled under E1, and the surviving GTK and Firefox targets read those size slots. A re-tune or a scale change is a one-line edit to `display-profiles.nix`.

**Why foot's size is a profile value, not a bare literal (the dpi-aware story).** foot pins `dpi-aware = no` (foot 1.15.0's default, written by Stylix's foot target; documented in `home/nixos/foot.nix`). Under `no`, `:size=N` is sized by the **output scale factor**, not the monitor's physical DPI — the same factor the Wayland apps scale by — so the profile's per-scale calibration (size ∝ 1/scale) lands a consistent apparent size across surfaces and scales. Pinning `no` is a deliberate *portability* choice: under foot's former `auto` an identical `:size=N` rendered at different apparent sizes across monitors of differing DPI/scale (foot issue #714); `no` makes it reproducible. (An earlier revision claimed a fixed `11` "compensated" for the 1.15.0 `auto → no` flip; that was unfounded — `auto` already used scale-factor sizing on any scaled output, so on metis the change was a no-op. The size is a deliberate legibility choice carried by the profile, not DPI compensation.)

## Installation model

fontconfig does three jobs for the desktop's fonts; all three are wired explicitly in `modules/nixos/desktop-fonts.nix`, replacing what Stylix's fontconfig target used to do:

1. **Install the faces.** `fonts.packages = [ Monaspace, Inter, Noto emoji ]` — an explicit list (only what's consumed), not `config.stylix.fonts.packages`.
2. **Map the generics.** `fonts.fontconfig.defaultFonts.{monospace,sansSerif,emoji}` names the baseline faces; `stylix.targets.fontconfig.enable = false` so Stylix no longer writes a competing map. This system-level map (`/etc/fonts/conf.d`) is the baseline the user `99-local.conf` overrides (§Runtime UX).
3. **Point surfaces at the generics.** `home/nixos/foot.nix` sets foot's font family to the `monospace` generic (`font = "monospace:size=…"`, replacing the prior concrete `stylix.fonts.monospace.name`); GTK's `gtk.font` name is `Sans`. Both resolve through the map (and thus through any user override).

The font list stays **inline** in `desktop-fonts.nix` — the module is imported only by desktop hosts (via the `desktop-env` bundle), so it is already host-agnostic; a shared `lib/fonts.nix` waits until a second desktop host actually needs it.

**The lockstep hazard.** The map name and the installed package must change together. If the map names a face that isn't installed, `fc-match` silently falls through to the proportional `DejaVu Sans` (the #283/#349 "DejaVu isn't monospace" class) — a *silent* downgrade, not a build error. Changing a baseline face means changing both the `fonts.packages` entry and the `defaultFonts` name in the same commit, and verifying with `fc-match` on-box.

**Firefox is face-swap-only under E1.** Stylix's Firefox target writes per-profile font *and* chrome-colour prefs as one unit, with no font-only toggle. So `stylix.fonts.{monospace,sansSerif=Inter,sizes}` stay set for that target to read: Firefox's web body becomes Inter (consistent with the rest), but it is *pinned*, not generic — it does not follow a runtime `99-local.conf` override, and Stylix re-pins it on rebuild. Full Firefox font-freedom (Firefox on pure generics) rides with the colour severance that takes Stylix off the desktop entirely — the deferred E2 / Part B (#390, ADR-036).

The general font base comes from NixOS's `fonts.enableDefaultPackages = true` (set as `mkDefault true` by niri-flake): `dejavu_fonts`, `freefont_ttf`, `gyre-fonts`, `liberation_ttf`, `unifont`, and `noto-fonts-color-emoji`. This is what makes "drop serif" safe — `DejaVu Serif` is present regardless, so the `serif` generic still resolves. Flipping `enableDefaultPackages = false` would mean curating the entire base set ourselves; deliberately not done.

### Darwin

neptune keeps Stylix (it is not Stylix-severed) and installs **Monaspace only** — the one face anything on the Mac consumes, via Ghostty's Nerd glyphs. `modules/darwin/desktop-fonts.nix` sets an explicit `fonts.packages = [ pkgs.nerd-fonts.monaspace ]` and keeps `stylix.fonts.monospace` set (Stylix's ghostty target renders Ghostty's font-family from it; the operator keeps Ghostty's own size pin). No sans, serif, or emoji is installed: macOS native UI is San Francisco, emoji is Apple Color Emoji, and nothing on the Mac is fontconfig-aware — so a desktop sans there would be unconsumed weight (install only what's consumed). There is no fontconfig wire (macOS resolves via Core Text) and no size mirror (Ghostty owns its sizing). The module is imported from `modules/darwin/foundation.nix` because every Darwin host is GUI. Per #209.

## Sharp edges

- **Silent DejaVu fallback (lockstep).** A `defaultFonts` name with no matching installed package resolves silently to `DejaVu Sans`, not an error. Keep the map name and the `fonts.packages` entry in lockstep, and verify with `fc-match` on-box. (Historically this surfaced as foot's "DejaVu Sans: font does not appear to be monospace" when neither the install nor the name wire was active.)
- **`pkgs.inter` ships two families.** A static **`Inter`** (in `Inter.ttc`) and **`Inter Variable`** (in `InterVariable.ttf`). The `sans-serif` generic and the friendly `Inter` name resolve to the static `Inter` — no alias needed. (`fc-match Inter` → `Inter`; request `Inter Variable` by that name if you want the variable build explicitly.)
- **The override seam wins by include-order, not filename.** A user `~/.config/fontconfig/conf.d/*.conf` beats the system baseline because user `conf.d` is included early (`50-user.conf`) and `<prefer>` prepends — not because of its number. Don't reason about "higher number = higher priority."
- **Firefox doesn't follow the runtime knob (E1).** Face-swap-only — see §Installation model. It joins the conductor at E2 / Part B.
- **foot's `dpi-aware = no`.** foot 1.15.0's default, adopted via Stylix's foot target; `:size=N` is scaled by output factor, letting the display profile own terminal sizing. See §Sizing. Original landing: PR #63.
- **No universal monospace.** The mono face lives on *GUI* hosts only — desktop NixOS hosts (via the desktop-env bundle) and Darwin hosts (via foundation). Headless NixOS hosts (mercury, nixos-vm) render nothing and install nothing.

## Cadence

Living document — same conventions as `keybinds.md`. Font changes are rare.

- **Doc precedes implementation.** A face change lands first as a §Selections row here; the implementing commit follows in the same PR.
- **The mapping is user-owned at runtime.** The Nix baseline is the reproducible starting point; the live selection is the user's `99-local.conf` (via `set-font`), deliberately not flake-captured — the runtime-state posture of ADR-036, extended to fonts.
- **No silent installs.** Anything in `fonts.packages` beyond the consumed baseline or the NixOS defaults is a cadence bug — document the addition here.

## See also

- `modules/nixos/desktop-fonts.nix` — the fontconfig install + generic-map wiring for desktop NixOS hosts.
- `modules/darwin/desktop-fonts.nix` — Darwin parallel: Monaspace-only install, Stylix-themed Ghostty, imported by Darwin foundation.
- `home/nixos/foot.nix` — foot terminal config; uses the `monospace` generic.
- `home/nixos/stylix-targets-desktop.nix` — the surviving GTK + Firefox Stylix targets (GTK font `mkForce`; Firefox face-swap-only under E1).
- `docs/desktop/noctalia.md` — Noctalia is colour-only and self-scoped for fonts; its surfaces follow the fontconfig generics.
- `docs/desktop/visual-identity.md` — the typography north-star this implements; the IBM-Plex-Sans reversal lives there.
- ADR-036 — Noctalia as desktop theming authority; the runtime-state posture this extends to fonts. #390 — the font conductor + severance work.
