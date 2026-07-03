# Omarchy theme-switching — transfer-claim validation

Status: **research note, not a decision.** Captured 2026-06-27 from a deep-research run (5 angles, 22 sources fetched, 82 claims extracted → 25 adversarially verified by 3-vote → 23 confirmed / 2 killed → 5 surviving findings; 2 of the 7 questions returned no surviving claim and stay UNVERIFIED). It independently checks the *transfer* claims in [`omarchy-theme-switching.md`](./omarchy-theme-switching.md) — "does this Omarchy technique actually work against *our* upstream tools" — against each tool's own docs/source, **not** Omarchy's internals (those are already primary-sourced). Feeds [`../design/colour-conductor.md`](../design/colour-conductor.md) §De-risk / §Unresolved and the runtime-theming issues (#411 / Epic E #427). Calls are version- and date-bound; pin deployed versions before relying on any behaviour below.

## Verdict table

| # | Transfer claim | Verdict | One-line caveat |
|---|---|---|---|
| 1 | foot honors OSC 4/10/11/12/17/19 live on an open pane | **CONFIRMED** | RGB specs only (no named X11 colours); foot has *no* config reload — OSC *is* the path |
| 2 | OSC-4 repaints existing cells referencing slot N ("free" statusline repaint) | **PARTIALLY-CONFIRMED** | Real per foot wiki/issue, but man page is silent and the by-value-vs-by-index mechanism is unsettled — do not assert mechanism |
| 3 | fnott reload via `fnottctl reload` / SIGHUP (mako analog) | **REFUTED** | No reload command, no signal; only a *destructive* daemon restart that drops live notifications |
| 4 | niri live-reloads border/focus-ring via `niri msg action load-config-file` | **CONFIRMED** | **NixOS gotcha:** auto-watch is inotify-on-file and misses a swapped store *symlink* — must call the IPC action explicitly |
| 5 | waybar has no live reload, must hard-restart | **PARTIALLY-CONFIRMED** | "No live reload" is overstated; SIGUSR2 + `reload_style_on_change` work, but tooltip styles and `-s` custom paths don't |
| 6 | GTK3 named-theme + `gsettings` flip reloads running GTK3 apps live | **UNVERIFIED** | No surviving claim covered it — carries forward open |
| 7 | base16 16-ANSI + 6-role mapping fidelity | **UNVERIFIED** | No surviving claim covered it — carries forward open |

## Findings

### 1 — foot OSC live colour-setting — CONFIRMED (high)

`foot-ctlseqs(7)` documents all six sequences with the `xterm` compatibility marker: OSC 4 ("Change color number c to spec"), OSC 10/11/12/17/19 (fg / bg / cursor / selection-bg / selection-fg), each in `XParseColor` format, plus the OSC 104/110/111/112/117/119 reset counterparts. The foot wiki is explicit: "true dynamic switching, or switching between more than two themes … can use the OSC4/11 escape sequences, which allows changing terminal colors on-the-fly." Foot deliberately has *no* config-reload mechanism (maintainer: "There is no way to dynamically reload the configuration"), so OSC is not a workaround — it is the intended path for an N-scheme conductor. The built-in `SIGUSR1` is only a *two*-theme light/dark toggle, not the N-scheme path.

- **Caveat:** foot accepts **only** RGB specs (`rgb:r/g/b` or `#rrggbb`), not named X11 colours — the conductor must emit hex.
- **Provenance:** cite the canonical Codeberg `dnkl/foot`, not the `github.com/r-c-f/foot` mirror.
- **Sources:** [foot-ctlseqs(7)](https://man.archlinux.org/man/extra/foot/foot-ctlseqs.7.en) · [foot wiki](https://codeberg.org/dnkl/foot/wiki) · [foot#708](https://codeberg.org/dnkl/foot/issues/708)

### 2 — OSC-4 → ANSI-slot repaint corollary — PARTIALLY-CONFIRMED (medium)

The "convert statuslines to ANSI-slot references so they repaint for free" premise is *plausible and partly corroborated* but must not be stated as a foot guarantee. foot's man page says nothing about repaint timing or whether existing vs newly-written cells pick up the change. Affirmative evidence exists outside the man page — foot's wiki and issue #678 state OSC 4/104 "updates all existing (visible) cells" — **including a gotcha:** RGB-printed cells whose absolute value happens to equal a changed palette value will *also* repaint. Two source-read claims about *how* foot does this (immediate `term_damage_*` calls; OSC-4 matching cells by stored old colour value rather than slot index) were **refuted** at verification (1-2). So: treat repaint-on-redraw as derived from OSC semantics + wiki, not from the reference, and flag the by-value-vs-by-index mechanism as unsettled.

- **Sources:** [foot-ctlseqs(7)](https://man.archlinux.org/man/extra/foot/foot-ctlseqs.7.en) · [foot wiki](https://codeberg.org/dnkl/foot/wiki) (issue #678)

### 3 — fnott reload — REFUTED (high)

There is **no** `fnottctl reload` and **no** SIGHUP/SIGUSR config-reload for a running fnott. `fnottctl(1)` (fnott 1.8.0, 2025-07-16) exposes only `dismiss`, `dismiss-with-default-action`, `actions`, `list`, `pause`, `unpause`, `quit`, `--version`; the `fnott(1)` daemon page has no SIGNALS section. Maintainer dnkl on the still-open issue #38 (2022-01-13): "Currently, no. There's no include statement, no dark/light 'modes' and no way to trigger a configuration reload." The only path is `systemctl --user restart fnott`, which **drops the live notification queue**.

- **Impact:** this directly corrects [`omarchy-theme-switching.md`](./omarchy-theme-switching.md) §4, which maps Omarchy's `makoctl reload` to a "`fnottctl reload` / SIGHUP" analog. fnott is **not** analogous to mako — it is the one pipeline tool whose theme flip loses live state. The conductor must either accept that loss or sequence the restart to a quiescent moment.
- **Sources:** [fnottctl(1)](https://man.archlinux.org/man/extra/fnott/fnottctl.1.en) · [fnott#38](https://codeberg.org/dnkl/fnott/issues/38)

### 4 — niri live config reload — CONFIRMED (high)

`niri msg action load-config-file` (IPC `Action::LoadConfigFile`, optional `--path`) reloads config on demand and re-applies visual config to a running session with no restart. niri also auto-watches the config file, and the live-reload surface is the *whole* config — "key bindings, output settings like mode, window rules, and everything else" — which covers the `layout{}` border / focus-ring `active-color` / `inactive-color` keys. Invalid config doesn't crash; the last-working state is preserved.

- **Critical NixOS caveat:** niri's auto-watch is inotify on the config **file** and does **not** detect a swapped **symlink** target — exactly the Stylix/home-manager pattern where `config.kdl` is a `/nix/store` symlink (open issue niri #2658, NixOS-specific, 2025-10-22). On this stack the conductor must **explicitly** call `niri msg action load-config-file` after a switch; passive save-detection won't fire.
- **Version caveat:** the `--path` option is gated to niri v26.04+ — pin/verify the deployed version.
- **Provenance:** the live-reload quote is from the **Configuration:Introduction** wiki page, *not* IPC.html — cite correctly.
- **Sources:** [niri IPC](https://niri-wm.github.io/niri/IPC.html) · [niri-ipc rustdoc](https://docs.rs/niri-ipc/latest/niri_ipc/enum.Action.html) · [Configuration:Introduction](https://github.com/niri-wm/niri/wiki/Configuration:-Introduction) · [Configuration:Layout](https://github.com/niri-wm/niri/wiki/Configuration:-Layout)

### 5 — waybar live reload — PARTIALLY-CONFIRMED / corrected (high)

The blanket "waybar cannot live-reload CSS, must hard-restart" is an **overstatement**. Two live paths exist: `SIGUSR2` reloads config + the main stylesheet, and `reload_style_on_change: true` auto-reloads `style.css` and its `@import`s on modification. But both have holes:

- `SIGUSR2` does **not** refresh **tooltip** styles — they stay cached from the previous theme until a full kill+relaunch (issues #3986, #3383, #3126).
- `reload_style_on_change` is **off by default**, and its inotify watch does **not** fire for a stylesheet passed via `-s` custom path (issue #3728) — only the default `style.css` + `@import`s.

**Caveats for the conductor:** enable `reload_style_on_change`; funnel base16/Stylix colours through the **default** `style.css` or its `@import`s, never a `-s` file; if tooltip theming changes, hard-restart waybar; and the same NixOS inotify-on-symlink nuance as niri may bite if `style.css` is an atomically-swapped store symlink (open verification point).

- **Sources:** [Waybar#3986](https://github.com/Alexays/Waybar/issues/3986) · [Waybar#3728](https://github.com/Alexays/Waybar/issues/3728) · [waybar(5)](https://man.archlinux.org/man/extra/waybar.5.en)

## Cross-cutting NixOS caveat — prefer explicit triggers over file-watch

The strongest finding spans tools: **inotify-on-symlink limitations affect both niri (#2658) and potentially waybar** under Stylix/home-manager store-symlink delivery, where the config is a `/nix/store` symlink swapped atomically on activation. Passive file-watch auto-detection cannot be relied on. The conductor's `activate` script should drive **explicit IPC/signal triggers** for every surface (foot OSC writes, `niri msg action load-config-file`, waybar SIGUSR2 / restart) rather than trusting any tool's own watcher.

## Open / unverified

- **Q6 — GTK3 named-theme lever (still the most speculative):** does flipping `gsettings set org.gnome.desktop.interface gtk-theme <name>` to a *distinct named theme per scheme* trigger a `GtkSettings` notify → re-read that repaints running GTK3 apps live (vs editing the content of a single `~/.config/gtk-3.0/gtk.css`, which fires no reload)? And does GTK4/libadwaita honour only `color-scheme` + named accents live while ignoring custom themes? **No surviving claim covered this** — carries forward.
- **Q7 — base16 mapping fidelity:** does a flat 16-ANSI + 6-named-role palette map onto base00–base0F without ambiguity, and where are the lossy points (base08–base0F accent semantics vs a single "accent"; rose-pine base09/base0E collision; tokyo-night port corrections)? **No surviving claim covered this** — carries forward. **Partially answered empirically by ADR-041 (2026-07-03):** the anticipated lossy point is real — base09 has no ANSI-16 position — and is handled by single-sourcing the nearest-on-bus approximation in `lib/theme-tokens.nix` (`role.ansi`; `attention → bright-yellow`). The mapping was field-tested on gruvbox (neptune, both polarities) and tokyo-night-with-slot-corrections (mercury) in the fleet-wide TUI conversion — legible everywhere. Rose-pine remains untested (metis runs Noctalia's palette, not a rose-pine ANSI mapping).
- **foot repaint mechanism:** by stored slot-index or by matching stored old colour value (the by-value gotcha, foot #678)? Determines whether ANSI-slot statusline references truly repaint "for free" — needs a direct source / on-`metis` check. **Now load-bearing for #411:** since ADR-041 converted the TUI surface to ANSI slots, whether metis statuslines repaint live under a Noctalia flip rides on exactly this — the on-`metis` check is a mandatory step of the statusline conversion. (The macOS parallel is settled: Ghostty's flip is native dual-theme re-rendering, not OSC-4 mutation, and was runtime-verified fleet-wide in the ADR-041 pass — open windows repaint, including over SSH.)
- **waybar symlink auto-reload:** does `reload_style_on_change` fire when a `/nix/store` `style.css` symlink target is atomically swapped on rebuild (parallel to niri #2658)? Needs empirical confirmation on the metis deployment.

## Sources

Primary, per tool: foot — [foot-ctlseqs(7)](https://man.archlinux.org/man/extra/foot/foot-ctlseqs.7.en), [foot wiki](https://codeberg.org/dnkl/foot/wiki), [foot#708](https://codeberg.org/dnkl/foot/issues/708). fnott — [fnottctl(1)](https://man.archlinux.org/man/extra/fnott/fnottctl.1.en), [fnott#38](https://codeberg.org/dnkl/fnott/issues/38). niri — [IPC](https://niri-wm.github.io/niri/IPC.html), [niri-ipc rustdoc](https://docs.rs/niri-ipc/latest/niri_ipc/enum.Action.html), [Configuration:Introduction](https://github.com/niri-wm/niri/wiki/Configuration:-Introduction), [Configuration:Layout](https://github.com/niri-wm/niri/wiki/Configuration:-Layout). waybar — [waybar(5)](https://man.archlinux.org/man/extra/waybar.5.en), [Waybar#3986](https://github.com/Alexays/Waybar/issues/3986), [Waybar#3728](https://github.com/Alexays/Waybar/issues/3728). base16 (gathered, not yet synthesised into a Q7 verdict) — [tinted-theming styling.md](https://github.com/tinted-theming/home/blob/main/styling.md), [chriskempson/base16 styling.md](https://github.com/chriskempson/base16/blob/main/styling.md).
