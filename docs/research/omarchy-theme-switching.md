# Omarchy theme switching — prior-art report

Status: **research note, not a decision.** Captured 2026-06-27 from a direct read of the `basecamp/omarchy` source (`master`): the `themes/`, `default/themed/`, and `bin/` trees, fetched via `raw.githubusercontent.com` and corroborated against the official [Omarchy Manual](https://learn.omacom.io/2/the-omarchy-manual/52/themes). Omarchy is DHH/Basecamp's Arch Linux + Hyprland setup; it ships a mature, runtime theme switcher. This note dissects *how* it defines and switches themes, compares that to the colour-conductor design ([`../design/colour-conductor.md`](../design/colour-conductor.md)), and calls out what is worth mining. Nothing here is adopted; each item is a pattern to evaluate against our own principles. Feeds the colour-conductor design note's §Prior art and the runtime-theming issues (#411 / Epic E #427).

## 1. Strategic verdict

**Mine Omarchy as a *palette upstream* and a *live-repaint cookbook*, not as a mechanism upstream.** Omarchy and the colour conductor are near mirror-images on the reproducibility axis: the conductor exists to keep all theming state in git and survive its shell, whereas Omarchy embraces mutable `~/.config` runtime state and gets, for free, the two things the conductor lists as *costs* — live-repaint plumbing and runtime theme installation. So the rendering/persistence/format halves of Omarchy are where the two diverge and there is little to take. But the **live-switch scripts are the single most mineable part of the whole project for this design**, because they empirically solve exactly what the conductor *defers*: the per-app reload-signal set (design note §Drawbacks, §Unresolved). Two concrete, directly-portable wins: the **foot live-OSC repaint loop** (the hardest surface in our stack) and the **reload-signal map** (which app reloads via what). Separately, every Omarchy theme reduces to a flat palette that maps cleanly onto base16, so the **entire Omarchy theme ecosystem is a candidate palette source** for the Nix-declared menu, via a small `colors.toml` → base16 adapter.

This note is dated; Omarchy moves fast (it recently migrated to the `colors.toml` + template model described below, superseding an older per-app-hardcoded scheme). Calls will drift.

## 2. How Omarchy defines a theme

A theme is a **directory** — shipped under `$OMARCHY_PATH/themes/<name>/`, user/third-party under `~/.config/omarchy/themes/<name>/`. The two are merged at switch time (shipped is the base, user overlays on top). Confirmed contents (tokyo-night, catppuccin, rose-pine, gruvbox):

- `colors.toml` — **the single palette source of truth** (see below).
- `backgrounds/` — wallpaper(s); `preview.png`, `unlock.png`, `preview-unlock.png` — menu/lockscreen art.
- `btop.theme`, `icons.theme` (a GNOME icon-theme name), `neovim.lua`, `vscode.json` — a few apps ship a pre-baked file rather than being templated.
- Per-theme extras seen only sometimes: `keyboard.rgb`, a hand-written `waybar.css` (catppuccin ships one to override the templated output), `chromium.theme` (an RGB triplet).
- `light.mode` — **the polarity marker**: an empty file whose mere presence flips the theme to light.

`colors.toml` is flat — six named UI roles plus the 16 ANSI slots:

```toml
accent = "#7aa2f7"
cursor = "#c0caf5"
foreground = "#a9b1d6"
background = "#1a1b26"
selection_foreground = "#c0caf5"
selection_background = "#7aa2f7"
color0 = "#32344a"   # … color1 … through … color15
```

**The template engine.** `default/themed/` holds one `.tpl` per app (`alacritty.toml.tpl`, `btop.theme.tpl`, `foot.ini.tpl`, `ghostty.conf.tpl`, `helix.toml.tpl`, `hyprland.*.tpl`, `hyprlock.conf.tpl`, `kitty.conf.tpl`, `mako.ini.tpl`, `waybar.css.tpl`, `walker.css.tpl`, `swayosd.css.tpl`, `chromium.theme.tpl`, `obsidian.css.tpl`, `keyboard.rgb.tpl`, `quickshell.json.tpl`, …) using **Mustache-style `{{ key }}`** placeholders — e.g. `@define-color background {{ background }};` (waybar), `background = "{{ background }}"` (alacritty), `$color = rgba({{ background_rgb }}, 1.0)` (hyprlock). Rendering (`omarchy-theme-set-templates`) is a **dependency-free `sed` pass**, not a templating binary: it parses `colors.toml` into key/value pairs and emits three substitutions per key — `{{ key }}` → hex, `{{ key_strip }}` → hex without `#`, `{{ key_rgb }}` → decimal `R,G,B` (hex values only). It loops user templates *then* shipped templates and **never overwrites a file already present** in the staging dir — that is the override seam (a theme or user can hand-ship `waybar.css` to suppress the templated one).

**Legacy bridge.** When a theme ships no `colors.toml` but has an `alacritty.toml` (older/third-party themes), `omarchy-theme-colors-from-alacritty` awk-parses the alacritty `[colors.*]` sections, normalises hex, sets `accent = color4`, and synthesises a `colors.toml`. The whole ecosystem therefore converges on `colors.toml`.

**Polarity is not an axis inside a theme.** Dark and light are *separate theme directories* (catppuccin vs catppuccin-latte, flexoki-light, white …). The only signal is the empty `light.mode` marker, consumed in exactly one place (see §6). `omarchy-theme-list` just enumerates depth-1 subdirectories with no light/dark logic.

## 3. How Omarchy switches a theme

`omarchy-theme-set <name>` (reachable from `omarchy-menu` → a walker/elephant theme menu with previews; there is no `omarchy-theme-next` script):

1. Normalise the name (`tr` to lowercase, spaces → hyphens); validate it exists.
2. Build a staging dir `~/.config/omarchy/current/next-theme/`: copy the shipped theme in, then overlay the user theme (user wins).
3. If no `colors.toml`, run the legacy alacritty bridge (§2).
4. Render every `.tpl` into the staging dir via `omarchy-theme-set-templates` (§2).
5. **Atomic swap — a directory move, not a symlink flip:** `rm -rf current/theme; mv current/next-theme current/theme`. `current/theme` is a *real directory*. Record the name in `current/theme.name`.
6. Change wallpaper (`omarchy-theme-bg-next`, unless `OMARCHY_THEME_SKIP_BACKGROUND=1`).
7. Fan out reloads to running apps (§4), then app-specific setters (`-foot`, `-gnome`, `-browser`, `-vscode`, `-obsidian`, `-keyboard`).
8. Fire `omarchy-hook theme-set <name>` — runs `~/.config/omarchy/hooks/theme-set` plus every file in `theme-set.d/` (skips `*.sample`, continues on failure, passes args through).

**The indirection that makes most apps "just work":** each app's static config permanently points *into* `current/theme/` — `general.import = [ "~/.config/omarchy/current/theme/alacritty.toml" ]` (alacritty), `@import "../omarchy/current/theme/waybar.css";` (waybar), `source = ~/.config/omarchy/current/theme/hyprland.conf` (hyprland), and real symlinks for btop (`~/.config/btop/themes/current.theme`) and mako (`~/.config/mako/config`), created once at install. So step 5's `mv` instantly changes what every config resolves to; step 7's reload just makes the running process re-read.

**Persistence is purely on-disk state — no daemon, no login hook.** The theme is "whatever `current/theme/` contains" at next boot; apps read it on startup. `current/theme.name` (plain text) and `current/background` (a symlink) round it out. *This is the structural contrast with the conductor's open question:* the conductor needs a login re-activate hook because each menu entry is a separate home-manager generation; Omarchy needs none because every config resolves through one fixed path whose contents are swapped in place. (In our world home-manager already gives that fixed-path indirection via the `~/.config` generation symlink, so the lesson transfers: point configs at a stable path and you only owe the *reload signal*, not the re-activation.)

## 4. The reload-signal map (the mineable core)

Omarchy has empirically derived the exact "make this running app re-read its theme" mechanism per surface. This *is* the conductor's unresolved reload-signal set, ground-truthed. Mapping to our stack:

| Our surface | Omarchy mechanism | Transfers? |
|---|---|---|
| **foot** (terminal) | OSC `10/11/12/17/19` + OSC `4;N` written per pty (see §5) | ✅ directly — refines the design's hedged "SIGUSR1/OSC" to **pure OSC** |
| **helix** | `pkill -USR1 helix` | ✅ confirms the design's USR1 guess |
| **niri** | `hyprctl reload` (Omarchy's WM) | ✅ analog `niri msg action load-config-file` (already named) |
| **fnott** (notifications) | `makoctl reload` (Omarchy uses mako) | ✅ pattern → `fnottctl reload` / SIGHUP |
| **waybar** | `pkill -9 -x waybar; setsid uwsm-app -- waybar &` | ⚠️ **waybar has no live reload — must hard-restart;** the `setsid`-detach matters so the relaunched bar outlives the activate script |
| btop (if themed) | `pkill -SIGUSR2 btop` | ✅ |
| (also seen) | alacritty `touch` mtime; kitty `SIGUSR1`; ghostty/opencode `SIGUSR2`; swayosd systemd restart | — not in our stack |

The taxonomy Omarchy encodes: **live-repaint** (foot OSC, mako/fnott, niri/hyprctl, helix, btop) vs **hard-restart** (waybar, swayosd). Our specialisation `activate` script is structurally the same fan-out, each entry gated on `pgrep`.

## 5. foot live-OSC repaint (the crown jewel)

`omarchy-theme-set-foot` repaints an *already-running* foot without a restart — the hardest surface in our stack — via OSC escapes written to each live pty:

1. **Discover ptys:** `pgrep -x foot` → for each, `pgrep -P $pid` (children) → `readlink /proc/$child/fd/1` → keep those matching `/dev/pts/*`.
2. **Write to each pts:** `\033]10;<fg>\007`, `\033]11;<bg>\007`, `\033]12;<cursor>\007`, `\033]17;<sel-bg>\007`, `\033]19;<sel-fg>\007`, and `\033]4;<N>;<hex>\007` for each palette slot 0–15. Colors are awk-parsed from the rendered `foot.ini`.

This closes the design's foot open question and *refines* it: OSC repaints existing panes' palette instantly and per-pty without a config re-read, so it is the better primitive than SIGUSR1. **The non-obvious corollary:** `\033]4;N;hex` live-rewrites the terminal's palette *slots*, so anything inside foot that references ANSI slot indices (rather than absolute hex) repaints for free on its next redraw. That is precisely why the design wants the four statuslines on ANSI-slot references — the foot OSC repaint is the delivery vehicle. The terminal half of the "per-tool ANSI-slot feasibility" open question is therefore solved by OSC 4; the only thing left per TUI is whether it emits slot refs or absolute hex.

## 6. GUI chrome — the live-vs-restart boundary (GTK / Firefox / Chromium)

The general principle Omarchy demonstrates: **a GUI app's chrome can be recoloured live iff it exposes a runtime "re-read your config/policy" trigger.** Apps without one force a relaunch — exactly the design's Force 1.

- **GTK (`omarchy-theme-set-gnome`):** sets only `gsettings org.gnome.desktop.interface` `color-scheme`, `gtk-theme` (**stock Adwaita / Adwaita-dark**), and `icon-theme`. Omarchy ships *no custom per-theme GTK colors* — it gets "live GTK" by *not having our problem*, flipping between two built-in themes (which `gsettings` does apply live to running apps). So there is no mechanism here for live *custom* GTK colors. The one real lever it points at: a `gtk-theme` **name** change is itself a live GTK3 reload trigger — so a *distinct GTK theme name per specialisation* + a `gsettings` flip would reload custom GTK3 colors live. Catch: our colors arrive via an `@import` in *user* `gtk.css`, where a content change fires no notify; using the lever means restructuring Stylix's GTK delivery to a named theme per scheme. GTK4/libadwaita stays restart-bound (it ignores custom themes; only `color-scheme` + named accents go live).
- **Firefox:** Omarchy does **nothing** for Firefox chrome — `default/firefox/` is only `policies.json` (enterprise policy, not theming). The only live path for Firefox chrome is a theme add-on (`.xpi`) swapped via the theme API; `userChrome.css` needs a restart. Not mined from Omarchy.
- **Chromium (`omarchy-theme-set-browser`):** the **one true live chrome recolour** — writes `{"BrowserThemeColor": "<hex>", "BrowserColorScheme": "device"}` to the managed-policy dir, then `chromium --refresh-platform-policy --no-startup-window` to make a running instance re-read it. But: it is *coarse* (a single frame tint + follow-OS polarity, not a palette); it is **chromium-family only** (our browser is Firefox); and its delivery is a **system-level `/etc/<browser>/policies/managed/` file needing root**, which clashes with the conductor's user-level, non-root, home-manager specialisation switch. So: a clean existence-proof that GUI chrome *can* go live, but not directly mineable for a Firefox, home-level switch. If Chromium were ever adopted it would have to be themed at the *system* layer.

**Net for the design's Force 1:** correct for GTK4/libadwaita and Firefox chrome (relaunch-bound); slightly pessimistic for GTK3 (a named-theme + `gsettings`-flip spike could move it to live). Polarity already reaches GTK + Firefox web content live via the portal — Omarchy confirms `gsettings color-scheme` is that channel.

## 7. Compatibility with existing Omarchy themes

The useful payoff: an Omarchy theme is portable to our stack **as a palette, not as machinery**.

- **High compat — the palette.** An Omarchy `colors.toml` (16 ANSI + 6 named roles) maps cleanly onto base16 (`color0..15` → the ANSI↔base16 slots, `background` → base00, `foreground` → base05, `accent` → an accent slot). A small Nix `fromTOML` adapter could ingest any `omarchy-<name>-theme` and emit a base16 scheme / `host-palettes.nix` menu entry, making the **whole Omarchy ecosystem a palette source** for the Nix-declared menu. The legacy alacritty bridge means even pre-`colors.toml` themes reduce the same way, so coverage is ~total.
- **Caveat — slot discipline.** base16 wants a disciplined 16-slot semantic spread; some Omarchy palettes define fewer distinct roles, so an import would hit the same slot-collision corrections already recorded in `lib/host-palettes.nix` (e.g. the rose-pine 09≡0E relocation, the tokyo-night port fixes).
- **Caveat — hand-shipped app configs.** A handful of themes ship a bespoke `waybar.css`/`btop.theme` that the "first-file-wins" renderer prefers over the templated output; a palette-only import silently drops these. Acceptable for us — Stylix re-themes those surfaces from the imported palette anyway.
- **Low compat — the machinery.** The `.tpl`/`sed` engine, the `current/theme` `mv`-swap, and the `omarchy-restart-*` fleet are an *alternative* to Stylix, not a complement; adopting them would re-introduce the mutable-runtime-state and shell-coupling the conductor exists to eliminate. The per-app pre-baked files (`neovim.lua`, `vscode.json`, `icons.theme`) are Omarchy-app-specific.
- **`light.mode` ≠ our polarity model.** Omarchy treats light as a *separate theme*; we treat polarity as an *axis* with paired dark/light schemes. An Omarchy light theme imports as its own menu entry, not as the "light variant" of a dark one — unless paired by hand (which `host-palettes.nix` `schemes.{dark,light}` already does).

## 8. What to mine vs what diverges

**Mine:**

- The **foot pty-discovery + OSC repaint loop** (§5), near-verbatim — the answer to our hardest live surface.
- The **reload-signal map** (§4) as our reload set, with the **waybar "no-reload, must hard-restart + `setsid`-detach"** caveat baked in.
- The **OSC-4 → ANSI-slot** linkage (§5) as the de-risk for the statusline conversion.
- The **`colors.toml` → base16 adapter** idea (§7) to open the Omarchy theme ecosystem as a palette source.
- The **"runtime re-read trigger" principle** (§6) as the predictor of which GUI surfaces can go live (and the GTK3 named-theme + `gsettings`-flip spike as the one lever with upside left).

**Diverges (do not adopt):** the `sed` rendering (replaced by Stylix build-time render), the `mv`-swap and `current/` indirection (replaced by the home-manager generation symlink), the per-app pre-baked theme files, and the `/etc` Chromium policy delivery.

## Sources

- `basecamp/omarchy` (`master`): `themes/{tokyo-night,catppuccin,rose-pine,gruvbox}/`, `default/themed/*.tpl`, `bin/omarchy-theme-set`, `-set-templates`, `-set-foot`, `-set-gnome`, `-set-browser`, `-install`, `-list`, `-colors-from-alacritty`, `-restart-{terminal,helix,waybar,mako}`, `-hook`, `default/firefox/` — fetched 2026-06-27 via `raw.githubusercontent.com`.
- [Making your own theme — The Omarchy Manual](https://learn.omacom.io/2/the-omarchy-manual/92/making-your-own-theme); [Themes — The Omarchy Manual](https://learn.omacom.io/2/the-omarchy-manual/52/themes).
