# macOS live theme switching — polarity sync, themed wallpaper pools, native-first fan-out

**Status:** Proposed — design note (`docs/design/`). Not built. #499 · sibling to [colour-conductor.md](./colour-conductor.md) (the Linux half of the same ambition); no ADR relationship yet — expected to graduate alongside implementation if accepted.

## Summary

Make theme polarity (dark/light) on neptune switchable at runtime with no rebuild, driven by and synced with macOS's own appearance toggle, and give each theme a Nix-declared pool of wallpapers that follows the switch. The mechanism is native-first: surfaces that can follow the macOS appearance signal themselves (Ghostty, fish, bat) are configured to do so at build time; the few that cannot (JankyBorders, wallpaper) are reached by a small launchd watcher fanning out to module-contributed hooks. A second stage extends the same shape from the host's single theme couplet to a Nix-declared menu of named themes.

## Motivation

Theming on neptune is build-time only. Flipping polarity is a Nix edit (`lib/host-palettes.nix` `polarity = "dark"`) plus a `nh darwin switch`; the macOS appearance toggle — the gesture the platform itself offers, including its scheduled/automatic mode — changes native app chrome but leaves every Nix-themed surface (Ghostty, JankyBorders, TUI statuslines) stranded on the built polarity. Wallpapers are unmanaged entirely: no declaration, no association with the active theme. And the theme itself is a single couplet per host — there is no menu, and no path to one that doesn't pass through a rebuild per switch.

The Linux half of this ambition is designed in [colour-conductor.md](./colour-conductor.md). macOS is a smaller problem — the themed surface on neptune is three targets (Ghostty, JankyBorders, wallpaper) plus self-managing TUIs — but it has a platform channel Linux lacks: a native, system-wide polarity signal that many applications already follow. The design should exploit that channel, not rebuild it.

**Forces — any solution must satisfy these:**

1. **No rebuild on switch.** Every selectable variant is pre-baked into the store at build time; a switch is a runtime selection among them.
2. **Colour source of truth stays `lib/host-palettes.nix` / Stylix.** No second palette definition anywhere; every artefact derives from the declared schemes.
3. **Bidirectional polarity sync.** The macOS appearance toggle and any Nix-provided switcher (CLI, action menu) converge on the same state — no split-brain between native chrome and the themed surfaces, whichever side initiated.
4. **Reproducible, bounded runtime state.** Wallpapers live in the store; the only runtime state is small pointers (the macOS appearance preference; later, the active-theme pointer). A fresh build lands on the host's declared default.
5. **Minimal runtime machinery.** The Darwin config is build-time-pure today; every runtime moving part added is one that can silently rot (the set-≠-enforced class). A solution should add as few as the surfaces genuinely require.

## Design

**Polarity authority is the macOS appearance state.** `AppleInterfaceStyle` *is* the runtime polarity pointer — not a file we invent. Every entry point (the System Settings toggle, Control Centre, a CLI switcher, the future action-menu entry per ADR-039's capability registry) converges by writing that one preference; macOS then fires `AppleInterfaceThemeChangedNotification`, and a single watcher path fans out from there. Because the switcher *only* writes the preference and the watcher is the only fan-out driver, there is one code path and no notification loop to guard — the loop-guard #499 flagged dissolves structurally. Not every write path fires the notification — a bare `defaults write -g AppleInterfaceStyle` neither notifies nor applies live. The switcher's write mechanism is a tiny Nix-built helper (~10 lines of C) calling SkyLight's `SLSSetAppearanceThemeLegacy` — the same private API sindresorhus's `dark-mode` CLI has used since Mojave. It applies live, maintains the preference with correct semantics (key deleted for light), fires the notification, and needs no TCC grant from any calling context — CLI, Hammerspoon, launchd, or SSH *(end-to-end de-risked on neptune — see §De-risk evidence)*. The AppleScript System Events route is the documented fallback if the private API ever breaks; it works but needs a TCC Automation grant per calling app (a bootstrap-runbook item) and fails over SSH.

Surfaces divide into two classes:

**Class 1 — native followers (build-time config, zero runtime plumbing):**

- **Ghostty** — native dual-theme: `settings.theme = "light:stylix-light,dark:stylix-dark"` (via `lib.mkForce`, overriding the Stylix target's single-polarity selector) with `window-theme = "system"`. Both palette variants are generated at build time into `programs.ghostty.themes` from the host's declared scheme pair, using Stylix's own scheme-parsing machinery; the Stylix target stays enabled for its font contribution *(shape and interplay de-risked against the pinned sources — see §De-risk evidence)*. Ghostty repaints open windows itself when the appearance flips (community-config-survey.md §5.1).
- **fish** (3.7+) and **bat** (0.24+) — self-manage via OSC background-change notifications / queries given dual-variant config (survey §§5.5–5.6): they follow the terminal, which follows the system. The version floors are met on neptune (verified); the end-to-end chain — Ghostty emitting the signal a running fish hears, bat's OSC 11 query under Ghostty — is not yet (see §De-risk evidence).
- **TUI statuslines** — today baked to the built polarity as absolute hex; their conversion to ANSI-slot references is #411's cross-platform work, after which they follow Ghostty's palette flip for free. Not re-solved here.

**Class 2 — watched surfaces (the fan-out):**

- **Watcher** — `dark-mode-notify` (pinned nixpkgs, aarch64-darwin) as a launchd user agent, invoking a fan-out runner on each appearance change.
- **Composition** — a small module option (list of hook scripts) that each surface module appends to from its own file, pinpox-style (survey §5.2); the runner executes the list. Adding a surface later is a one-liner in that surface's module, not an edit to a central script.
- **JankyBorders** — both polarity colour pairs pre-baked from the theme tokens at build time (survey §5.4); the hook applies the pair matching the new appearance to the running instance via the `borders` CLI *(de-risked: recolours live, no agent restart — see §De-risk evidence)*.
- **Wallpaper** — a new primitive: a Nix attrset mapping theme name → polarity → list of store paths (shape and location settled at implementation; plausibly `lib/theme-wallpapers.nix`). The hook picks from the active theme+polarity pool and applies it with `desktoppr` (pinned nixpkgs); a `home.activation` step applies the declared default on rebuild so a fresh build is complete without the watcher ever firing (survey §2.8).

**Stage 2 — named-theme menu.** The same shape generalised from the host's single couplet to a Nix-declared menu (`host-palettes` grown to named entries, mirroring colour-conductor's menu): per-theme Ghostty theme pairs, border colour pairs, and wallpaper pools all pre-baked; a small active-theme pointer in user state; the theme switcher repoints it, re-fires the same fan-out, and repaints open terminal windows via the Omarchy OSC pattern (pty discovery + OSC 4/10/11 — [../research/omarchy-theme-switching.md](../research/omarchy-theme-switching.md) §5) since a named-theme change, unlike a polarity flip, is not a signal Ghostty follows natively. New Ghostty windows pick the active pair up via a config include repointed by the switcher (mechanics to de-risk). Polarity remains macOS-owned throughout — the theme pointer selects the couplet, the appearance state selects the half.

**How the forces are met.** All variants are store artefacts generated from `host-palettes.nix` (forces 1, 2). Polarity state is the platform's own, written by every entry point and read by one watcher (force 3). Runtime state is two pointers — appearance preference and (stage 2) active theme — over a reproducible default (force 4). Ghostty/fish/bat carry no plumbing at all; the watcher exists only for the two surfaces with no native ear (force 5). Native-first is the design judgement that serves force 5: where a surface already listens for the appearance signal, configuring that at build time beats adding a runtime hook for it — grounded in the survey evidence (§5.1 for Ghostty; §8's warning against re-solving it with heavier machinery).

## De-risk evidence

- **`dark-mode-notify` and `desktoppr` exist in the pinned nixpkgs for `aarch64-darwin`** — verified by eval against this flake's pin, 2026-07-02.
- **`borders` CLI recolours the running instance live — green (verified on neptune, 2026-07-02).** `borders active_color=0xffff0000` repainted the live focus border with no agent restart (restored immediately after); the launchd-bounce fallback in §Design is not needed.
- **`programs.ghostty.themes` shape + Stylix-target interplay — green (verified against the pinned sources, 2026-07-02).** The HM option (rev `d8dac1f`) is `attrsOf keyValue.type`, one file per attr under `~/.config/ghostty/themes/`; the theme payload shape (16-slot `palette` list + background/foreground/cursor/selection keys) matches what the Stylix target emits. Stylix's `mkTarget` applies config as *plain* assignments (no `mkDefault`), so the target's `settings.theme = "stylix"` needs `lib.mkForce` on the dual value — the same precedent as the existing `font-size` pin. And the inactive polarity's palette derives from Stylix's own machinery: `inputs.stylix.inputs.base16.lib.mkSchemeAttrs` over the declared scheme YAML eval-confirmed against the pin (gruvbox-light-hard → `base00 = f9f5d7`), so both variants come from the same source and slot mapping as the active one (force 2). Working shape: keep the Stylix target enabled (it carries the font-family the `font-size` pin presupposes), generate `stylix-dark`/`stylix-light` entries from the host's scheme pair with per-polarity overrides applied, and `mkForce settings.theme = "light:stylix-light,dark:stylix-dark"` + `window-theme = "system"`. Accepted residue: the target's now-unselected `themes/stylix` file remains as inert dead weight (~500 bytes) — cheaper than disabling the target and re-owning fonts.
- **fish 4.7.1 and bat 0.26.1 on neptune clear the auto-switch floors (3.7 / 0.24) — green (verified on-host, 2026-07-02).**
- **`SLSSetAppearanceThemeLegacy` write path — green (verified end-to-end on neptune, 2026-07-02).** A ~10-line C helper compiled with the nixpkgs clang wrapper against `/System/Library/PrivateFrameworks/SkyLight.framework`: the flip applied live system-wide; the global preference tracked with correct semantics (`AppleInterfaceStyle` deleted for light, `Dark` for dark); a distributed-notification listener observed `AppleInterfaceThemeChangedNotification` fire; no TCC prompt at any step. Switcher-initiated flips are therefore indistinguishable from toggle-initiated ones to the watcher — the one-code-path argument holds for both entry points.
- **JankyBorders is the border surface, not AeroSpace** — confirmed in `modules/darwin/jankyborders.nix` (AeroSpace draws no window chrome; #499's original fan-out list is corrected by this note).
- **Ghostty dual-theme syntax and `window-theme = "system"`** — pattern confirmed in two community configs (survey §5.1); *not yet verified on neptune* that open windows repaint live on the appearance flip — testable only once the dual themes are configured, so it is the first thing the stage-1 slice verifies.
- **Still unverified** (carried to Unresolved questions): Ghostty's live repaint of open windows on the appearance flip; the fish/bat end-to-end chain under Ghostty (version floors are necessary, not sufficient — the signal emission and OSC 11 query are untested); `desktoppr` behaviour on multi-display; stage-2 Ghostty config-include repointing.

## Drawbacks

- **Adds runtime machinery to a so-far build-time-pure Darwin config** — a launchd watcher and a hook list are new moving parts that can silently rot (the set-≠-enforced class; runtime verification on neptune is mandatory before calling any of it done).
- **Polarity ownership moves to macOS state.** The scheduled/automatic appearance mode will flip the TUI too, and independent TUI polarity (terminal dark while native chrome is light) is given up. This is judged the desired behaviour — one gesture, one look — but it is a real capability loss.
- **Mechanical divergence from the Linux sibling.** colour-conductor switches via home-manager specialisations; this design switches via native signals + hooks. Two mechanisms to keep conceptually aligned, justified by the platform channel Linux lacks.
- **The switcher's write path is a private API.** `SLSSetAppearanceThemeLegacy` is undocumented; a macOS major could remove it. Stable since Mojave and widely depended on, and the failure mode is loud (the flip stops working, nothing corrupts), with the AppleScript + TCC-grant route as the documented fallback — but it is a dependency Apple owes nothing to.

## Cost

The standing price once chosen: **store size scales with the declared variants** — every theme couplet pre-bakes both polarity artefacts (cheap: generated configs), and every wallpaper pool puts theme × polarity × images into the store as real bytes (not cheap; a large pool is a deliberate choice, not a free one). This is the macOS analogue of colour-conductor's build-time-scales-with-menu cost, with the wallpaper bytes on top.

## Rationale & alternatives

- **Rebuild-per-switch (status quo shape):** a polarity flip or theme change remains a Nix edit + `nh darwin switch`. Fails force 1; leaves the macOS toggle permanently desynced (force 3). Rejected.
- **Port the Linux mechanism — home-manager specialisations per theme×polarity:** maximal symmetry with colour-conductor, but heavier than the platform needs (full HM activation per flip vs. an instant native signal), and specifically an anti-pattern for Ghostty when a native dual-theme mechanism exists (survey §8). macOS's appearance channel makes the specialisation layer redundant for polarity. Rejected for macOS; remains right for Linux, which has no such channel.
- **Raycast as the switching surface:** previously evaluated and rejected for the action-menu role — GUI/cloud-configured, against the declarative posture ([../research/cross-platform-action-menu.md](../research/cross-platform-action-menu.md)). The switcher instead lands as a plain CLI, registrable in the capability registry (ADR-039) for hotkey and action-menu invocation. Rejected.
- **Native-first + thin watcher fan-out (selected):** pre-baked variants (force 1) from the single colour source (force 2), bidirectional sync via the platform's own state (force 3), bounded runtime pointers (force 4), and the smallest runtime footprint of the live options — one watcher and two hooks, versus a full activation apparatus (force 5).

**Impact of doing nothing:** polarity stays a rebuild, the macOS toggle stays cosmetic-only for the themed surfaces, wallpapers stay unmanaged, and the eventual theme menu (#499's articulated goal) has no runtime path at all on macOS.

## Prior art

- [../research/community-config-survey.md](../research/community-config-survey.md) — the load-bearing sources: Ghostty native dual-theme (§5.1, malob/kclejeune), module-contributed fan-out hook lists (§5.2, pinpox), pre-baked per-polarity border colours (§5.4, pinpox), `desktoppr` activation wallpaper (§2.8, grapefizz), and the specialisation anti-pattern warning (§8).
- [../research/omarchy-theme-switching.md](../research/omarchy-theme-switching.md) — the pty-discovery + OSC repaint loop, needed only at stage 2 (named-theme change is outside the native appearance signal).
- [colour-conductor.md](./colour-conductor.md) — the Linux sibling; this note deliberately echoes its forces (reproducibility, declared menu, bounded runtime state) while diverging on mechanism where macOS offers a native channel.
- louis-thevenet/darkman's persist-and-reapply pattern (via colour-conductor §Prior art) — subsumed here by macOS persisting its own appearance state; only the stage-2 theme pointer needs the pattern.

## Unresolved questions

To close during implementation (stage 1):

- Whether the CLI switcher is part of the stage-1 slice — the native toggle alone exercises the whole chain, and the SLS helper is small enough to land either way — is an open sequencing choice. (The write mechanism itself is resolved and de-risked — see §De-risk evidence.)
- The hook-list option's name and home.
- Wallpaper pool shape: keyed theme×polarity (assumed) and `desktoppr` multi-display semantics.
- On-neptune runtime verification of the whole path: toggle → notification → hooks → repaint, plus Ghostty's native flip with open windows.

Deferred to stage 2:

- Ghostty config-include repointing for new windows; OSC repaint loop against Ghostty ptys; the active-theme pointer's location and login re-apply.
- Menu shape in `host-palettes.nix` — to be designed together with colour-conductor's menu generalisation so Linux and macOS read one declaration.

## Future possibilities

- **Scheduled polarity for free** — macOS's built-in "Auto" appearance mode drives the whole chain with zero additional work, the macOS analogue of colour-conductor's darkman-by-sunset possibility.
- **Cross-platform theme declaration** — one Nix-declared menu (schemes + wallpaper pools) consumed by both this design and colour-conductor's specialisations.
- **Wallpaper rotation within a pool** — the pool structure admits a rotate-on-interval or rotate-on-wake hook later without redesign.
