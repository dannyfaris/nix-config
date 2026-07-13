# ADR-044: Nix-owned runtime theme menu on Linux

**Date**: 2026-07-14
**Status**: Accepted, Built; on-metis runtime verification pending (#609)

> Nix (via Stylix's `base16.mkSchemeAttrs` engine) is the **single theming authority** on the Linux desktop. A Nix-declared catalogue of named families is rendered per entry into stable data derivations; a `~/.local/state/theme-menu/current` symlink + per-target resolved symlinks (`foot.ini`, `niri.kdl`, `gtk3.css`, `gtk4.css`, `colors.json`) are the runtime state, plus an atomic copy of `colors.json` delivered into `~/.config/noctalia/` (Noctalia's watchers can't see symlink swaps — see §Explicit triggers); the `theme` CLI switches them atomically with explicit reload fan-out. Noctalia is demoted from colour authority to a **themed-by-Nix shell** — the colour-authority half of ADR-036 is reversed (see §Amendment to ADR-036 below); Noctalia as the cohesive shell (bar, launcher, notifications, lock, OSD, wallpaper, idle) is **unchanged**. Host-identity theming is retired (operator call, landed with the shared core slice #610 — every desktop host offers the full catalogue at runtime, and a host's `defaults` entry is a boot default only). The two-axis persistence model (family = symlink, polarity = dconf `org/gnome/desktop/interface/color-scheme`) and the explicit-trigger rule (no passive file-watch assumed for any surface) are the load-bearing conventions.

## Context

ADR-036 adopted Noctalia as the Linux desktop's cohesive shell **and** its sole theming authority. Three problems followed, each acknowledged as a migration trigger in that ADR's own Consequences list:

1. **Not reproducible.** The live colour/scheme state lives in Noctalia's GUI-managed `settings.json`, deliberately not in git — a fresh reprovision starts at Noctalia's defaults and must be re-set via the GUI.
2. **Not durable.** Theming coupled to Noctalia v4 breaks at the v4→v5 migration (a fresh install, not an upgrade). Making Noctalia the sole authority means theming is entangled with a known-temporary shell waypoint.
3. **Split-brain on switch.** ADR-036 §Consequences noted that a runtime polarity flip reached Noctalia's own surfaces but left the four TUI statuslines (zjstatus, gh-dash, the Claude statusline, macchina) at the built polarity until a rebuild. #411/ADR-041 resolved the statusline half (all four now follow the terminal's ANSI palette), and the design note [`docs/design/colour-conductor.md`](../design/colour-conductor.md) (Route 1) proved that the remaining surfaces — foot, niri borders, GTK, Noctalia's `colors.json` — are pure file/dconf renders with no eval-time coupling. The specialisation path was verified workable but superseded 2026-07-07 by a lighter mechanism (per-target derivations + a symlink swap); the route was adjudicated adversarially and confirmed 2026-07-14.

The design note's forces — GUI-app relaunch acceptable (force 1), declaratively reproducible (force 2), selection persists across restart (force 3), catalogue declared in Nix (force 4) — are all met by this mechanism.

## Decision

**1. Nix is the single theming authority on the Linux desktop (Route 1).** `lib/scheme-pair.nix`'s `menu` (familyName → `{ dark; light }` base16 attrset pairs) drives one `runCommand` per family that renders all per-target artefacts at build time via pure Nix string interpolation. No runtime templating engine; no shelling out.

**2. Entry-dir contract per family (10 rendered artefacts).** Each derivation at `$XDG_DATA_HOME/theme-menu/<family>` contains: `foot-{dark,light}.ini` (base16→ANSI mapping per Stylix's canonical foot module, `[colors-dark]` header for both polarities — the conductor swaps content, foot's active mode never flips; initial-color-theme is never emitted); `niri-{dark,light}.kdl` (13 colour values across focus-ring/border/shadow/tab-indicator/insert-hint + recent-windows/highlight, slot-commented); `gtk3-{dark,light}.css` (34 `@define-color` keys); `gtk4-{dark,light}.css` (same 34 keys + the libadwaita `:root { --*-color }` custom-property block); `colors-{dark,light}.json` (16 M3-role keys for Noctalia's `colors.json`).

**3. Two-axis persistence model.** Family axis: `$XDG_STATE_HOME/theme-menu/current` → `$XDG_DATA_HOME/theme-menu/<family>` (atomic `mktemp -u` + `ln -s` + `mv -fT`). Polarity axis: `dconf /org/gnome/desktop/interface/color-scheme` (`'prefer-dark'` ↔ dark, `'default'` ↔ light). Per-target resolved symlinks `$stateDir/{foot.ini,niri.kdl,gtk3.css,gtk4.css,colors.json}` → `current/<target>-<polarity>.<ext>` are the stable paths consumers reference. Both axes persist across reboot independently; dconf's user GVDB survives power cycles.

**4. The `theme` CLI** (`pkgs.writeShellApplication`, runtimeInputs coreutils + dconf + procps): `theme` lists families with `*` on current; `theme <family>`, `theme dark|light`, `theme <family> <dark|light>`. Validates against baked entry dirs; detects and repairs dangling pointers before proceeding; repoints atomically; fans out: (a) dconf write (polarity change), (b) foot OSC repaint per-pty (OSC 4 × 16 slots + OSC 10/11 — foot ptys discovered via `pgrep -x foot` → `ps --ppid` child tty; zero ptys is fine; writing to /dev/pts/N is display-side, not a zellij input channel), (c) `niri msg action load-config-file` (niri's inotify misses symlink swaps, niri#2658 — explicit trigger required), (d) Noctalia palette delivered by atomic copy-into-place: `$stateDir/colors.json` copied to a tmp file inside `~/.config/noctalia/` then `mv -fT` onto `colors.json` — the in-directory replace is what fires Noctalia's watcher (see §Explicit triggers; runtime-verified on metis, #609).

**5. Seed-if-absent activation** (`home.activation.themeMenuSeed`, after writeBoundary): if `$stateDir/current` is absent, dangling, or resolves outside the baked set → seed to the boot-default family and write dconf color-scheme from the boot-default polarity (this branch only — so a rebuild never resets a live selection). If the pointer is valid: only (re)create missing per-target symlinks. Seeds consumer-side wiring: `~/.config/noctalia/colors.json` as an atomic copy of `$stateDir/colors.json` (copy-into-place, not a symlink — §Explicit triggers; a pre-existing foreign regular file is backed up to `colors.json.pre-609` once, guarded so our own copies never clobber that backup); `~/.config/gtk-{3,4}.0/theme-menu.css` → `$stateDir/gtk{3,4}.css` symlinks.

**6. Consumer re-points.** `home/nixos/foot.nix`: `settings.main.include` → `~/.local/state/theme-menu/foot.ini`. `home/nixos/niri.nix`: appended include → `~/.local/state/theme-menu/niri.kdl`. `home/nixos/stylix-targets-desktop.nix`: `gtk.extraCss` → `@import url("theme-menu.css")` (seed creates `~/.config/gtk-{3,4}.0/theme-menu.css` symlinks; no `file://` experiment; no collision with any Noctalia gtk writer). `home/nixos/portal-color-scheme.nix`: dconf write moved into the gated seed; file retained as an import-graph marker. `home/nixos/bundles/desktop-env.nix`: imports the new `theme-menu.nix`.

**7. Noctalia demotion recipe (operator step at rollout, not Nix-owned).** `settings.json` is GUI-managed per ADR-036 — this is a documented one-time operator step: disable all six `activeTemplates` (foot, gtk, helix, starship, yazi, niri); set `useWallpaperColors: false` (its wallpaper→colors.json writer is otherwise still live). Leave `enableUserTheming: false` — it gates template generation, not the colors.json read path; the shell follows colors.json unconditionally via its FileView watchers. Noctalia's own darkMode toggle and scheme picker become inert-by-convention (the conductor owns the selection). Stale Noctalia-written files (the old foot theme, old noctalia.css, helix/starship/yazi templates) are cleanup artefacts. Rollout verification includes: change wallpaper → colors.json NOT rewritten.

**8. Host-identity theming retired.** The catalogue (`lib/theme-families.nix`) is fleet-global; every desktop host offers all families at runtime. A host's `defaults` entry is a boot-default only — what a fresh build or reprovision renders before the user's first runtime selection. Runtime selection is the reproducible-from-flake initial state (force 2) not a fixed per-host assignment.

## Rationale

**Reverses the colour-authority half of ADR-036; keeps Noctalia as the shell.** ADR-036's "sole theming authority" call was the right call given the problem it solved (two-writer seam, config coupling). This decision removes the problem differently: the two-writer seam is gone because Noctalia's activeTemplates are disabled entirely — Nix writes the artefacts; Noctalia reads `colors.json` passively. The authority change is a direction reversal, not a contradiction.

**Durability is the strategic driver.** Noctalia v4 is frozen into maintenance; v5 is a fresh install. With Nix as the authority, the v4→v5 migration only re-points Noctalia's `colors.json` consumption — no per-surface render rebuild, no template re-port. Were Noctalia dropped entirely, the per-tool rendered targets still theme every surface.

**Mechanism choice: per-entry derivations + symlink swap (not home-manager specialisations).** Specialisations would require a whole-tree re-evaluation per entry, need specialisation-aware HM activation, and add derivation-count overhead proportional to menu size × all HM modules. The adopted mechanism is: one small `runCommand` per family × 10 text artefacts + a single symlink swap. Sub-second at runtime, no rebuild. Specialisations verified workable and retained as a fallback (see design note §De-risk evidence).

**Explicit triggers, no passive watch.** niri's inotify misses symlink swaps (niri#2658, NixOS-specific — the inotify watch is on the file, not the target; a swap changes the link's target in-place but doesn't CREATE a new file event). Noctalia's FileView watchers resolve **inodes at watch-establishment time** — the earlier source-read conclusion (that a parent-directory `watchChanges` event would fire on the `ln -sf` re-point) was falsified by on-metis runtime verification (#609): our swap happens two levels deep (`$stateDir/colors.json` → a different immutable store artefact), so neither the watched inode nor `~/.config/noctalia/` ever changes and no reload fires. Delivery is therefore an **atomic copy-into-place** (tmp file + `mv -fT` inside the watched directory) — the exact pattern the upstream source comment anticipates. No passive file-watch is assumed for any surface without runtime verification.

**Two-axis persistence for free.** The symlink survives reboots on its own — no login hook or re-activation needed. dconf's user GVDB is already a persistent on-disk store. Both axes are recoverable: a broken symlink → seed repairs; a missing dconf key → defaults to light.

## Consequences

- ✓ Reproducible: the full theme catalogue is in the flake; a fresh reprovision lands on the host's declared boot default with no GUI step.
- ✓ Durable: Noctalia is now just a themed shell — a v4→v5 migration doesn't break theming; removing Noctalia is no longer a theming event.
- ✓ Live switching across the full catalogue with no rebuild; foot, niri, GTK, Noctalia chrome, and portal-following apps (Firefox, libadwaita) are designed to repaint in one `theme` invocation.
- ✓ Polarity persists across reboot (dconf GVDB) and rebuild (pointer-gated seed never stomps a live selection).
- ⚠ The runtime behaviours above are the declared/designed state, not yet the verified one — on-metis runtime verification (switch latency, per-surface repaint, reboot persistence, two-writer absence) is pending and will be recorded on #609 (the set-≠-enforced rung).
- ✗ The live-repaint plumbing (foot OSC loop, niri msg, colors.json copy-into-place) is ours to maintain, not Noctalia's.
- ✗ Adding a future colour-consuming surface requires adding it to the per-entry render list; it won't be covered automatically (same discipline `stylix.targets.<x>.enable` already required, but named here rather than assumed).
- ✗ Noctalia's demotion is a documented operator step, not a Nix gate — the control centre and settings.json are out of Nix's reach by design; an accidentally re-enabled `activeTemplates` would create a two-writer situation until the operator fixes it.
- ⚠ Migration trigger: if `niri msg action load-config-file` is ever replaced by a different niri reload API, update the `theme` CLI.
- ⚠ Migration trigger: if Noctalia v5 changes how it reads `colors.json` (path, trigger, format), update the seed + CLI accordingly.

## Amendment to ADR-036

**ADR-036's §Decision item 3** ("Noctalia is the sole theming authority over every rendered desktop surface") is **amended by this ADR**: Nix/Stylix is now the theming authority; Noctalia's role is reduced to a themed-by-Nix shell. Every other item of ADR-036 stands: Noctalia as the cohesive shell (item 1), flake input (item 2), Stylix demoted/retained as palette engine (item 4 — now permanent, not E1 interim), ADR-035 superseded (item 5). ADR-036's §Consequences ✗ "Noctalia's config is runtime/GUI state, not in git" now applies only to the shell surface config (bar layout, panel positions) — colour is in git.

## Implementation

`home/nixos/theme-menu.nix` — entry-dir renders, seed activation, `theme` CLI. Consumer re-points: `home/nixos/foot.nix`, `home/nixos/niri.nix`, `home/nixos/stylix-targets-desktop.nix`, `home/nixos/portal-color-scheme.nix`. Bundle import: `home/nixos/bundles/desktop-env.nix`.

Rollout sequence: (1) activate the new generation (`nh os switch`), (2) operator disables Noctalia's activeTemplates + sets `useWallpaperColors: false` in the control centre, (3) run `theme rose-pine dark` (the boot default) to confirm all fan-out signals fire, (4) verify: foot OSC repaint in an open window; niri border follows; Firefox/libadwaita follow portal flip; colors.json not rewritten on wallpaper change.

## References

- `docs/design/colour-conductor.md` — the design note this implements; Route 1 mechanism, forces, prior art.
- [ADR-036](./ADR-036-noctalia-shell-linux-desktop.md) — amended by this ADR (colour-authority half reversed; shell role unchanged).
- [ADR-041](./ADR-041-terminal-authority-tui-theming.md) — the statusline precondition: all four TUI statuslines follow the terminal ANSI palette; #411 landed 2026-07-13.
- [ADR-028](./ADR-028-stylix-foundation-and-desktop-env.md) §item 1 — Stylix re-asserted as the Linux-desktop theming authority (first asserted in ADR-028, demoted by ADR-036, re-asserted here).
- #609 (this issue), #610 (shared core slice — catalogue + boot defaults), #611 (Darwin sibling).
- `docs/research/omarchy-theme-switching.md` + `docs/research/omarchy-theme-switching-validation.md` — per-app reload evidence, foot OSC pty-discovery, symlink-watch blind spot findings that shaped the trigger design.
