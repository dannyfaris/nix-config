# Noctalia

Cohesive Wayland desktop shell built on [Quickshell](https://quickshell.org/). One project owns the bar, launcher, notifications, lock, OSD, control-centre, clipboard history, tray, dock, wallpaper, desktop widgets, session menu, and idle — replacing the per-tool waybar + fuzzel + fnott + swaylock stack on the Linux desktop.

> **Status: selected, implementation pending.** This doc is the selection record; the direction-shaping decision (and its consequences) live in [ADR-036](../decisions/ADR-036-noctalia-shell-linux-desktop.md). Claims tagged *(v4.7.7)* were verified by reading the upstream source at that tag; claims tagged *(on-box pending)* await first-activation confirmation on the desktop host, in the ADR-035 tradition of not asserting runtime repaint before the console proves it.

## Selection

**Noctalia Shell, the v4 (Quickshell) line**, on the Linux desktop — adopted as both the cohesive shell *and* the sole theming authority there. Consumed via Noctalia's **own flake**, not the nixpkgs package: the declarative surface (`programs.noctalia-shell.{settings,colors,user-templates}`) lives in Noctalia's `nix/home-module.nix`, and the flake pins `noctalia-qs` — Noctalia's own Quickshell fork — so shell and runtime are co-locked in one input *(v4.7.7)*. Launched from niri via `spawn-at-startup` (the binary is `noctalia-shell`, a wrapper over Quickshell's `qs`); the module's systemd unit is opt-in and left off (the v4 systemd path is deprecated upstream). The home module installs the binary only when `programs.noctalia-shell.package` is set, so the package is wired explicitly from the flake input.

On the Linux desktop, Noctalia owns colour, runtime polarity, and fonts in its default, idiomatic look (no ported palette, no forced scheme); Stylix stops theming the desktop. The other hosts (mercury, nixos-vm, mac-mini) keep pure declarative Stylix unchanged. Initial implementation is **E1**: Stylix stays *enabled* on the desktop as a static colour table for a handful of TUI statuslines while every Stylix desktop target-writer is removed — see Sharp edges.

## Rationale

**It clears the version-skew gate that retracted DMS.** ADR-029 retracted Dank Material Shell because three independently-pinned upstreams (DMS / quickshell / niri-flake) skewed apart: a QML `pragma AppId` the trailing nixpkgs quickshell couldn't parse, and `include` directives niri 25.08 silently rejected, looping until systemd's start-limit. Noctalia removes two of those limbs outright and narrows the third:

- **Runtime co-locking** — the flake pins `noctalia-qs` in the *same input* as the shell QML, so the shell and its Quickshell runtime bump together in one lock. This removes the *inter-pin* divergence that produced DMS's pragma mismatch *(v4.7.7)*. It does not make skew categorically impossible: `noctalia-qs` is a fork that tracks Quickshell upstream, so a Quickshell-vs-niri protocol change could still bite — but that is one external seam to watch on a bump, not three pins skewing apart.
- **Compositor-spawn, not systemd** — v4's systemd assets are removed upstream; it launches from niri. No start-limit crash vector.
- **No config injection** — Noctalia integrates by a spawn line plus benign `window-rule`/`layer-rule` entries; it injects nothing into niri's config, so there is no silent parse-fallback *(v4.7.7)*.

**The condition that sank DMS does not hold.** We track `nixos-unstable` (ADR-030), and the shell is one flake input whose shell and runtime are co-locked — not three projects with divergent cadences. The three-pin *combinatorial* skew is gone; the residual is ordinary single-seam maintenance.

**Sole authority avoids the two-writer seam.** A shell that owns the runtime polarity flip *and* a Stylix base writing colours at build time means two writers per surface and a reassert-on-rebuild flip-flop. Making Noctalia the single authority on the Linux desktop collapses that to one conductor. The cross-platform palette work is preserved where it still earns its keep — every other host.

**Declarative-friendly.** `settings`/`colors`/`user-templates` are Nix values rendered to read-only store symlinks; Nix stays authoritative. (Trade-off: the in-shell GUI scheme-tweaker is not a live source of truth — runtime GUI edits don't persist back; use *Settings → Copy Settings* to extract state and graduate it into Nix.) *(v4.7.7)*

**It ends the stitching.** Noctalia owns a strict superset of the waybar + fuzzel + fnott + swaylock surface in one project, plus surfaces the desktop never had (clipboard history, tray, dock, OSD, control-centre, wallpaper). The per-tool cohesion ADR-029 traded away for stability returns — at a coordination cost that is now bounded and local, not cross-project.

## Alternatives considered

**Keep the per-tool stack (waybar + fuzzel + fnott + swaylock).** The status quo; works today. Passed over because the operator chose to stop hand-composing the surface and accept a cohesive shell, now that one exists without DMS's skew profile. The per-tool docs ([waybar.md](./waybar.md), [fuzzel.md](./fuzzel.md), [fnott.md](./fnott.md), [screen-lock.md](./screen-lock.md), [power-session.md](./power-session.md)) remain valid history and the fallback for any future non-Noctalia host.

**DankMaterialShell (DMS).** The retracted shell. Pulls Quickshell from nixpkgs (a third independently-cadenced pin — the very inter-pin skew that sank it), and its documented niri path leaned on a systemd service + a niri `include` "hack." Re-introduces exactly the upstream-coordination cost ADR-029 walked away from. Passed over.

**Caelestia / end-4 (illogical-impulse).** niri support is third-party, work-in-progress, single-maintainer, build-from-source, with no maintained Nix module. Disqualifying for a low-breakage-tolerance host.

**HyprPanel.** Hyprland-only, and a bar rather than a full shell. Wrong compositor and wrong scope.

**Noctalia v5 (the C++ rewrite).** Strategically the better target — it drops Qt/Quickshell entirely, removing the skew class — but it is alpha, and a v4→v5 move is a fresh install, not an upgrade. Deferred to a migration trigger (ADR-036).

## Configuration

Planned wiring; lands in reviewable slices behind ADR-036, each validated on the desktop host before the next.

**Flake + module** — add the Noctalia flake input (`inputs.nixpkgs.follows = "nixpkgs"`, per repo convention); import `homeModules.default`; set `programs.noctalia-shell.enable = true`; spawn from niri via `spawn-at-startup`.

**Theming** — vanilla Noctalia: its **default** look (default scheme / wallpaper-derived, managed at runtime via its control centre) plus its **built-in templates** for external apps. No predefined-scheme selection, no palette porting, no terminal-palette fidelity chase. Surface coverage:

- **Native + built-in templates** — Noctalia's own chrome, plus niri borders, GTK, foot, helix, starship, yazi, btop (Noctalia ships built-in templates for these) *(v4.7.7)*. This moots the niri-chrome-colours work (#110) on the Linux desktop: Noctalia's niri template owns the border colours.
- **Gaps (no upstream template)** — zellij, bat, fzf: left at their app defaults under the vanilla call, or given small `user-templates` (Nix attrset → TOML, each with its own reload `post_hook`) if wanted *(v4.7.7)*.
- **Live refresh** — foot and helix get `user-template` `post_hook`s (`pkill -USR1 foot`; helix config-reload) because Noctalia writes the theme file but sends *no* reload signal of its own; already-open instances stay on the old colours until signalled *(v4.7.7; on-box pending)*.
- **Fonts** — Noctalia owns its own surfaces' fonts; foot's font is re-homed onto `foot.nix` directly (Noctalia's templating is colour-only and cannot set a terminal font) *(v4.7.7)*.

**Settings are runtime/GUI-managed** — `programs.noctalia-shell` stays `enable` + `package`; Noctalia's mutable `settings.json` is the source of truth, configured in its control centre (deliberately *not* Nix-pinned → not reproducible from the flake; the price of vanilla, idiomatic Noctalia). External theming is off by default: the relevant keys are `templates.enableUserTheming` (master toggle) and `templates.activeTemplates` (a list of `{ id, enabled }` per app) *(v4.7.7)*. Toggle them in Noctalia's *Color Scheme → Templates* tab, or by editing `~/.config/noctalia/settings.json` directly over SSH.

**Stylix target-writer excision on the Linux desktop (E1)** — remove `home/shared/stylix-targets.nix` from the desktop host's `extraHomeModules` and `home/nixos/stylix-targets-desktop.nix` from the desktop home bundle (import-splits); move font *installation* off `stylix.fonts` to `fonts.packages` + `fontconfig.defaultFonts`; source niri geometry/sizing from `lib/display-profiles.nix`. Keep `stylix.enable` + the host's palette entry as a static colour table for the TUI statuslines. Full literal removal (E2) is deferred — see Sharp edges.

**Keybinds** — repoint `Mod+Space` / `Hyper+Space` (launcher) and bar/notification actions to `noctalia-shell ipc call …` (arguments passed as lists, per upstream). The Hyper namespace (#376) and the screenshot chords are unaffected; screenshots stay niri-native.

**Decommission** — remove waybar, fuzzel, fnott, swaylock/swayidle from the desktop bundle one surface at a time, validating each.

## Sharp edges

**The terminal palette is whatever Noctalia's default produces (deliberately not engineered).** Noctalia's wallpaper-derived mode maps ANSI onto its M3 slots (an approximation); only its predefined-scheme mode carries a genuine `terminal.{normal,bright}` block *(v4.7.7)*. Per the operator's vanilla call we use Noctalia's default and don't chase fidelity — selecting a predefined scheme remains the lever if a faithful terminal palette is ever wanted.

**No default reload signal for foot.** The per-app applier writes theme files but only signals a subset (kitty, ghostty, GTK, btop, hyprland, sway). **foot and helix are write-only** — Noctalia does not `pkill -USR1` them, and we don't force one: a scheme/polarity change repaints *new* foot windows (they read the updated `include` on launch) but leaves already-open ones until relaunch *(on-box verified 2026-06-18)*.

**The terminal palette is hijacked by base16-fish until the Stylix `fish` target is gone.** Stylix's `fish` target installs base16-fish, whose `base16-<scheme>` call runs on every interactive shell and emits **OSC 4** sequences that repaint the terminal's 16 ANSI colours to the base16 (rose-pine) palette — *over* whatever the terminal's own config loaded. So foot can be correctly configured with Noctalia's gruvbox `include` and still render rose-pine, because the shell repaints the palette a moment after foot starts. This is invisible to `foot --check-config` (the config is valid; the override happens at runtime, post-launch). Removing the Stylix `fish` target (part of the metis TUI-target excision) stops the OSC override; only then does the terminal show Noctalia's palette. Diagnosed on-box 2026-06-18: `foot --check-config` passed and the gruvbox sub-config imported cleanly, yet `fish -i` emitted `\e]4;1;rgb:eb/6f/92…` (rose-pine) at startup.

**External configs are ours to declare, Noctalia's to fill — the read-only-symlink dance.** Noctalia themes an external app by writing a colour file *and* editing the app's main config to reference it (an `include`/`@import`). On NixOS the main config is usually a read-only home-manager symlink, and Noctalia's post-hooks only convert read-only symlinks for *some* apps (sway/niri/hyprland do; foot/yazi/btop/gtk do not) — so the reference-injection silently fails, and any Stylix colour block already in that file shadows Noctalia's anyway. The fix per surface is the same shape: *we* declare the reference in Nix so it's present before Noctalia looks, pointing at the file Noctalia writes — `foot.nix`'s `main.include` (and the Stylix foot target dropped, since a competing colour block would shadow it); for GTK, `stylix.targets.gtk.extraCss = ''@import url("noctalia.css");''`, appended after Stylix's `@define-color`s so Noctalia's gruvbox wins the cascade while the Stylix target keeps writing `settings.ini` (adw-gtk3 + font). Either way Noctalia's post-hook finds its reference already present and stops rewriting the file. One-time cutover cost: Noctalia's first-run post-hooks clobber the HM symlinks into plain files, so the next `nh os switch` backs each up to `*.hm-bak` — and a pre-existing `.hm-bak` makes activation abort, so stale ones (`~/.config/foot/foot.ini.hm-bak`, `~/.config/gtk-{3,4}.0/gtk.css.hm-bak`, …) must be removed before switching *(on-box verified 2026-06-18)*.

**Helix theming is Material-3-mapped, always.** Even in predefined mode, the helix template references M3 slot names, not the 16-colour block — so syntax theming is an M3 mapping, never a faithful base16 helix theme *(v4.7.7)*.

**zellij / bat / fzf ship no upstream template.** All three are hand-authored `user-templates` we own and maintain, reload signals included *(v4.7.7)*.

**Stylix isn't fully removed on the desktop (E1, initial implementation).** Four cross-platform TUI statuslines — zellij's zjstatus bar (`multiplexer.nix`), `gh-dash.nix`, the Claude statusline (`agent-clis.nix`), `macchina-shell-init.nix` — read `config.lib.stylix.colors` at Nix eval time and have no Noctalia equivalent (Noctalia themes by writing files; these read Nix values). So E1 keeps `stylix.enable` + the rose-pine palette entry as a static build-time colour table for those statuslines while removing every Stylix *desktop target-writer*; Noctalia themes every rendered surface, so there is no two-writer seam. Full literal removal — re-home those four `shared/` modules onto a standalone rose-pine table and drop the palette entry — is the deferred **E2** refinement. See ADR-036 §Refinement.

**Qt returns to the Linux desktop.** v4 is Quickshell is Qt — this walks back the Qt-free property #103 helped secure and ADR-029 called an "unambiguous win." The closure grows on the desktop host (mate-polkit stays — Noctalia is not a polkit agent). Conscious cost, recorded in ADR-036.

**v4 is frozen into maintenance upstream; pin the `legacy-v4` branch.** Development has moved to v5 — the repo's `main` is now `noctalia-5.0.0` (the Qt-free C++ alpha), so the flake input must pin `github:noctalia-dev/noctalia-shell/legacy-v4` (latest v4 tag: `v4.7.7`), never bare `HEAD`. We adopt a deliberately-frozen codebase — stable, but a waypoint, not a destination.

**Lock needs no manual PAM entry.** Noctalia auto-detects NixOS and reuses the system `/etc/pam.d/login` service for password unlock (`NOCTALIA_PAM_SERVICE` overrides); the NixOS module adds no PAM service of its own. So password unlock works without a `security.pam.services.noctalia` entry — but nothing Noctalia-specific is created either, so a fingerprint/bespoke stack is on us *(v4.7.7; on-box pending — confirm lock before decommissioning swaylock)*.

**Flake `follows` vs Cachix is a conscious pick.** `inputs.nixpkgs.follows = "nixpkgs"` keeps channel consistency but forgoes the `noctalia.cachix.org` substituter (which requires *omitting* `follows`), so Qt builds locally. Choose at wire-up; this doc doesn't pre-decide it.

## References

- [ADR-036](../decisions/ADR-036-noctalia-shell-linux-desktop.md) — the direction-shaping decision: Noctalia as shell + sole theming authority on the Linux desktop; supersedes ADR-035; amends ADR-029 + ADR-028 §item 1.
- [ADR-029](../decisions/ADR-029-niri-only-desktop.md) — the DMS retraction and per-tool model this amends; its version-skew rationale is the bar Noctalia had to clear.
- [ADR-035](../decisions/ADR-035-runtime-theme-polarity.md) — the tinty runtime layer Noctalia subsumes (superseded).
- [ADR-030](../decisions/ADR-030-nixpkgs-channel.md) — the `nixos-unstable` channel that makes single-flake co-pinning hold.
- [fonts.md](./fonts.md) / [keybinds.md](./keybinds.md) — the cross-cutting selections Noctalia displaces on the Linux desktop.
- [waybar.md](./waybar.md) / [fuzzel.md](./fuzzel.md) / [fnott.md](./fnott.md) / [screen-lock.md](./screen-lock.md) / [power-session.md](./power-session.md) — the per-tool stack subsumed on the Linux desktop; retained as history + non-Noctalia fallback.
- [#103](https://github.com/dannyfaris/nix-config/issues/103) — the Qt-free property this walks back. [#110](https://github.com/dannyfaris/nix-config/issues/110) — niri chrome colours, mooted on the Linux desktop. [#143](https://github.com/dannyfaris/nix-config/issues/143) — the runtime-polarity want, delivered here via the shell.
- Noctalia upstream — https://github.com/noctalia-dev/noctalia-shell (v4 line) · https://github.com/noctalia-dev/noctalia-qs (the pinned runtime fork).
