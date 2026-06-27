# Colour conductor — live, reproducible, durable desktop theming

**Status:** Proposed — design note (`docs/design/`). Not yet built. Selects Route 1 (below); reverses ADR-036's *"Noctalia as sole theming authority"* while keeping Noctalia as the shell (#411 / Epic E #427) → ADR-worthy (see §ADR relationship under Rationale).

## Summary

Make Stylix (via Nix) the single theming authority on the desktop, and let the user live-switch across a **Nix-declared menu of named themes and polarity** — applied to every surface immediately, save that GUI application *chrome* keeps its start-up colours until that app is relaunched on a full scheme change. Noctalia drops from colour authority to a themed-by-Nix shell.

## Motivation

There is no easy way to live (or nearly-live) switch theme and polarity. Three things make it hard today, and rule out the naive fixes:

1. **Split-brain live switching (#411).** Noctalia flips its own surfaces (bar, niri borders, foot's palette) live, but the Stylix-pinned surfaces — the four TUI statuslines (zjstatus, gh-dash, the Claude statusline, macchina), and the rest — only re-theme on a full rebuild.
2. **Not reproducible (#406 / Epic E #427).** The live colour/scheme state lives in Noctalia's GUI-managed `settings.json`, deliberately *not* in git — so the desktop's look cannot be rebuilt from the flake.
3. **Not durable.** Runtime theming is owned by Noctalia v4, frozen into upstream maintenance (v5 is a fresh-install rewrite) — so theming coupled to it breaks at the migration, or if Noctalia is replaced.

**Forces — any solution must satisfy these:**

1. **GUI-app relaunch is acceptable.** It is fine for *some* GUI apps to require a relaunch for a theme *colour* switch to take effect. (Polarity dark↔light still reaches GUI chrome live via the portal; and this boundary is universal — no theming route re-themes a running GTK/Firefox chrome on a full scheme change.)
2. **Declaratively reproducible.** The build is reproducible from the flake; nothing about the look escapes git.
3. **Selection persists across restart.** The theme + polarity the user selected at runtime survives a reboot / re-login — it is *not* reset to the build default on every restart.
4. **The theme catalogue is declared in Nix.** The set of selectable themes is the Nix-declared menu; adding a new theme is a Nix edit + rebuild — no adding themes at runtime.

The **strategic driver** behind the route choice is **durability** — the theming should survive Noctalia v4 and even Noctalia's removal. It is served by making the authority Nix/Stylix, not a shell.

## Design

Stylix (via Nix) is the **single theming authority** on the desktop. The user live-switches across a **Nix-declared menu of named themes (each with its polarity variants)** via home-manager specialisations; the selection persists across restart. Noctalia is demoted from theming authority to a **themed-by-Nix shell** — it still owns the bar, launcher, notifications, lock, and the rest of the shell surface, but no longer owns colour.

1. **Stylix as single authority.** Re-establish Stylix as the desktop's colour writer: re-add the foot and niri Stylix targets and re-import the shared TUI targets — all removed for the Noctalia adoption (#385) — and revert the GTK colour override (today Noctalia's `@import` wins the cascade) back to Stylix. The GTK *settings* and Firefox targets stayed throughout. Stylix then renders every surface's colours at build time.
2. **A Nix-declared theme menu → one specialisation per entry.** Generalise `lib/host-palettes.nix` from one scheme-pair per host to a **named menu** (rose-pine, tokyo-night, gruvbox, …, each with dark/light). Pre-build one home-manager specialisation per menu entry (named scheme × polarity), each overriding `stylix.{polarity, base16Scheme, override}` to that entry's values. A switch runs the chosen specialisation's `activate` script — non-root, sub-second, no rebuild. *(De-risked: Stylix's system→home push is `mkDefault`, so a plain specialisation assignment overrides it — no `mkForce`, no `followSystem = false`; see §De-risk evidence.)*
3. **Selection + persistence (force 3).** The active selection is a small runtime pointer (the chosen menu entry) in user state — the *only* live state, a bounded, recoverable delta over the Nix-declared default. A user-session hook re-activates the pointed-to specialisation at login, so the selection survives restart; absent the pointer (fresh machine), the host's Nix-declared default applies (force 2). *(Mines louis-thevenet/darkman's "persist last selection, re-apply at login" pattern.)*
4. **Invocation — hotkey and/or action menu.** The switch is user-invocable via a **hotkey** (keybind registry, #384) and an **action-menu entry** presenting the named-theme menu (the launcher / action-menu surface, #437 / #442). All resolve to "activate the selected menu entry and persist the pointer."
5. **Statuslines → ANSI-slot references.** Convert the four statuslines (zjstatus, gh-dash, the Claude statusline, macchina) from absolute colour to indexed / ANSI-slot references, so they follow the terminal palette and repaint live. *(Per-tool feasibility to verify: gh-dash and zjstatus; the Claude statusline and macchina are expected to convert cleanly.)*
6. **Noctalia as a themed-by-Nix shell.** Pin Noctalia's `colors.json` per specialisation *(de-risked: a separate, module-pinnable file)*; leave its runtime templating/recolour off. Noctalia re-reads `colors.json` on the atomic swap, so its chrome follows the active specialisation.
7. **Live-repaint plumbing.** The specialisation `activate` fires the reload signals so already-open instances repaint: foot `SIGUSR1`/OSC, niri `load-config-file`, helix `USR1`, the Noctalia `colors.json` swap, fish universals (the per-surface signal map verified in #143).

**What "immediately" means.** On a theme/polarity switch: the terminal palette + the slot-referenced statuslines, shells, niri, and Noctalia's chrome **repaint live**; a **polarity** flip additionally reaches GTK/libadwaita and Firefox web content live via the portal `color-scheme` key; only GUI application *chrome* on a *named-scheme* change keeps its start-up colours until that app is **relaunched** (force 1 — universal to any route).

**How the forces are met.** A single Nix/Stylix authority with every menu entry Nix-built (forces 2, 4); the only live state is the selection pointer, and the login re-activate gives persistence (force 3) while staying reproducible — a fresh build lands on the host's declared default. The arrangement survives Noctalia v4 (the durability driver): Noctalia is now just a themed shell, so a v4 → v5 migration only re-points the `colors.json` pin; were Noctalia dropped entirely, the per-tool Stylix targets still theme every surface.

## De-risk evidence

- **Home-manager-specialisation switch — green (verified).** Stylix's home-manager integration copies the system palette into home-manager via its `copyModules` path as `lib.mkDefault` (read at the flake-pinned Stylix rev, `home-manager-integration.nix`), so a plain specialisation assignment overrides `polarity` + `base16Scheme` with no `mkForce` and no `followSystem = false`, contained to the desktop host's home config. Eval-confirmed against metis's actual config. `base16-schemes` is a single package holding every scheme, so each menu entry adds only its re-themed generated configs, not a doubled system.
- **Noctalia `colors.json` pinning — green (verified).** A separate file from the runtime-mutable `settings.json` (per `docs/desktop/noctalia.md`); the "does Noctalia rewrite it on a flip" concern disappears because Noctalia no longer performs the flip.
- **Still unverified** (carried to Unresolved questions): per-tool ANSI-slot feasibility for gh-dash and zjstatus; the exact persistence-hook shape; the full reload-signal set; on-`metis` switch latency and repaint.

## Drawbacks

Reasons one might not do this at all:

- It **reverses the colour-authority half of the Noctalia adoption (#385)** — re-adding the foot/niri/TUI Stylix target-writers and reverting the GTK colour override, undoing work landed only recently.
- It **rebuilds the live-repaint plumbing Noctalia currently provides for free** — the reload-signal fan-out becomes ours to maintain.
- It **gives up Noctalia's in-shell GUI scheme picker** — the switch is driven by hotkey / action-menu instead of a point-and-click panel. (That the live menu is the *declared* set is constraint 4, the desired behaviour — not a drawback.)

## Cost

The accepted standing price, once Route 1 is chosen: **build-time scales with the menu size** — one specialisation per scheme × polarity — though each entry is cheap (only its re-themed generated configs, per the de-risk note).

## Rationale & alternatives

Two routes present themselves for *where theming authority lives*:

- **Route 2 — Noctalia stays the conductor; pin a reproducible base via a `settings.json` merge.** Keeps Noctalia's in-shell GUI picker and instant per-surface recolour, and could switch to *any* scheme at runtime without pre-declaring it. **Rejected:** its mechanism *is* Noctalia v4 (the merge targets v4's `settings.json`; v5's model differs), so it fails the durability driver; and it only partially satisfies the reproducibility force.
- **Route 1 — Stylix as single theming authority; live switching across a Nix-declared menu of specialisations.** Durable (authority is Nix/Stylix, shell-independent) and reproducible by construction. **Selected** — it is the only route that satisfies forces 2–4 and the durability driver.

**Impact of doing nothing:** the desktop stays split-brain on a switch (#411), non-reproducible (#406), and the theming breaks at the Noctalia v4 → v5 migration.

**ADR relationship.** This reverses ADR-036's "Noctalia as sole theming authority" decision (while keeping Noctalia as the shell), so it warrants an ADR change — an amendment to ADR-036 or a new ADR — landed alongside implementation. This design note owns the mechanism; the ADR owns the authority direction-change.

## Prior art

The live-switching survey in [`../research/prior-art.md`](../research/prior-art.md) §3 surfaced three *mechanism* routes: darkman + home-manager-specialisation `activate` (the most Nix-native — adopted here for Route 1's switch), Quickshell-native IPC (Noctalia's own runtime recolour — the mechanism behind Route 2), and a matugen/pywal cache (ruled out as least suited to the declarative model). The persistence design mines louis-thevenet/darkman's "persist last selection, re-apply at login" pattern and its `darkman` + specialisation-`activate` shape.

**To do — review, extend, and mine [`../research/omarchy-theme-switching.md`](../research/omarchy-theme-switching.md).** That report dissects Omarchy's theme definition and switching and lines it up against this design; before implementation, work through it and pull its concrete techniques and patterns into the relevant sections here. The high-value veins it already surfaces: the **foot pty-discovery + OSC-repaint loop** (the answer to our hardest live surface, and a refinement of the §7 "foot SIGUSR1/OSC" hedge to *pure OSC*); the **per-app reload-signal map** (the empirically-derived reload set the §Unresolved bullet leaves open — with the **waybar "no live reload, must hard-restart + `setsid`-detach"** caveat to bake in); the **OSC-`4;N` → ANSI-slot** linkage that de-risks the statusline conversion; the **`colors.toml` → base16 adapter** that would open the whole Omarchy theme ecosystem as a palette source for the Nix-declared menu (force 4); and the **"runtime re-read trigger" principle** that predicts which GUI surfaces (GTK3 via a named-theme + `gsettings` flip; Chromium via policy refresh) can go live versus stay relaunch-bound. Treat the report as a living note — extend it as the landscape moves and as each technique is verified on `metis`.

## Unresolved questions

To close during implementation:

- Per-tool ANSI-slot-reference feasibility: gh-dash and zjstatus (the Claude statusline and macchina expected fine).
- The persistence mechanism's exact shape: the selection-pointer location and the login re-activate hook (systemd user service vs session hook), mining louis-thevenet/darkman.
- The reload-signal set and the `activate`-script shape (louis-thevenet's `darkman` + specialisation-`activate`, per `../research/prior-art.md` §3).
- On-`metis` console verification: switch latency, statusline + Noctalia repaint, persistence across reboot, and that no two-writer incoherence appears during the transition.

## Future possibilities

The design enables but does not commit to these:

- **Automatic polarity by sunset/sunrise** via `darkman` driving the polarity flip on a schedule, reusing the same activate/persist path.
- **Per-app theme overrides** beyond the single host default — a surface electing a different menu entry.
