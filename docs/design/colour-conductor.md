# Colour conductor — Stylix authority + home-manager-specialisation live switching

**Status:** Proposed — design note, doc-before-code (#411 / Epic E #427). Reverses ADR-036's *"Noctalia as sole theming authority"* while keeping Noctalia as the shell → ADR-worthy (see §ADR relationship).

## Decision

Stylix (via Nix) is the **single theming authority** on the desktop. Live **polarity** switching runs through home-manager specialisations. Noctalia is demoted from theming authority to a **themed-by-Nix shell** — it still owns the bar, launcher, notifications, lock, and the rest of the shell surface, but no longer owns colour.

**Why:** durability — the theming survives Noctalia v4 (frozen into upstream maintenance; v5 is a fresh-install rewrite, not an upgrade); and reproducibility — the rice rebuilds from the flake, with no GUI-managed colour state.

## Architecture

1. **Stylix as single authority.** Re-establish Stylix as the desktop's colour writer: re-add the foot and niri Stylix targets and re-import the shared TUI targets — all removed from the desktop host for the Noctalia adoption (#385) — and revert the GTK colour override (today Noctalia's `@import` wins the cascade) back to Stylix. The GTK *settings* and Firefox targets stayed throughout. Stylix then renders every surface's colours at build time again.
2. **Live polarity via home-manager specialisations.** Pre-build `light` and `dark` home-manager specialisations, each overriding `stylix.{polarity, base16Scheme, override}` to values derived from the host's `lib/host-palettes.nix` entry. A switch runs the specialisation's `activate` script — non-root, sub-second, no rebuild. (Why a plain specialisation assignment suffices — no `mkForce`, no `followSystem = false` — is the load-bearing de-risk; see §De-risk evidence.)
3. **Invocation — hotkey and/or action menu.** The switch must be user-invocable two ways: a **hotkey** (declared in the cross-platform keybind registry, #384) and an **action-menu entry** (the launcher / action-menu surface, #437 / #442). `darkman` may additionally drive an automatic polarity flip by sunset/sunrise. All three resolve to the same underlying "activate the target specialisation" action.
4. **Statuslines → ANSI-slot references.** Convert the four statuslines (zjstatus, gh-dash, the Claude statusline, macchina) from absolute colour to indexed / ANSI-slot references, so they follow the terminal palette and repaint live. *(Per-tool feasibility to verify: gh-dash and zjstatus; the Claude statusline and macchina are expected to convert cleanly.)*
5. **Noctalia as a themed-by-Nix shell.** Pin Noctalia's `colors.json` per specialisation *(de-risked: it is a separate, module-pinnable file)*; leave its runtime templating/recolour off. Noctalia re-reads `colors.json` on the atomic swap, so its own chrome follows the active specialisation.
6. **Live-repaint plumbing.** The specialisation `activate` fires the reload signals so already-open instances repaint rather than waiting for relaunch: foot `SIGUSR1`/OSC, niri `load-config-file`, helix `USR1`, the Noctalia `colors.json` swap, fish universals (the per-surface signal map verified in #143).

## Accepted constraints (locked)

- **Polarity flip** (dark ↔ light): live across every surface.
- **Arbitrary-scheme flip** (e.g. rose-pine → gruvbox): live across the terminal / shell / compositor world — terminal palette, slot-referenced statuslines, shells, niri, and Noctalia's chrome.
- **GUI application chrome on an arbitrary-scheme change**: the running app keeps its start-up colours until **that application is relaunched** (closed and reopened — *not* a rebuild, reboot, or re-login). Accepted.
- **Arbitrary schemes are not pre-built as specialisations** (only the two polarity variants are), so a change of scheme *family* is a rebuild, not a live switch. Accepted — scheme-family changes are rare, and they are split-brain on GUI chrome under any route.

## Reproducibility & durability (the win)

A single Nix/Stylix authority; both palettes are Nix-built; the only live state is *which specialisation is active* (a pointer that resets to the declared default on rebuild). Nothing escapes git. The arrangement survives Noctalia v4: Noctalia is now just a themed shell, so a v4 → v5 migration only re-points the `colors.json` pin; were Noctalia dropped entirely, the per-tool Stylix targets still theme every surface.

## Cost (accepted)

- Re-Stylix-ifies the desktop — re-adds the foot/niri/TUI Stylix target-writers and reverts the GTK colour override, undoing the colour-authority half of the Noctalia adoption (#385).
- Rebuilds the live-repaint plumbing that Noctalia currently provides for free.
- Gives up Noctalia's in-shell GUI scheme picker — the switch is driven by hotkey / action-menu / `darkman` instead (Architecture §3).

## De-risk evidence

- **Home-manager-specialisation polarity flip — green (verified).** Stylix's home-manager integration copies the system palette into home-manager via its `copyModules` path as `lib.mkDefault` (read at the flake-pinned Stylix rev, `home-manager-integration.nix`), so a plain specialisation assignment overrides `polarity` + `base16Scheme` with no `mkForce` and no `followSystem = false`, contained to the desktop host's home config. Eval-confirmed against metis's actual config: a specialisation forcing `polarity` + `base16Scheme` flips the resolved palette. `base16-schemes` is a single package holding every scheme, so a second polarity adds only the re-themed generated configs, not a doubled system.
- **Noctalia `colors.json` pinning — green.** It is a separate file from the runtime-mutable `settings.json` (per `docs/desktop/noctalia.md`); the "does Noctalia rewrite it on a flip" concern disappears because Noctalia no longer performs the flip.

## Open items (close during implementation)

- Per-tool ANSI-slot-reference feasibility: gh-dash and zjstatus (the Claude statusline and macchina expected fine).
- The exact reload-signal set and the `activate`-script shape (mine louis-thevenet/nixos-config's `darkman` + specialisation-`activate` pattern, per `docs/research/prior-art.md` §3).
- On-`metis` console verification: switch latency, statusline + Noctalia repaint, and that no two-writer incoherence appears during the transition.

## ADR relationship

This reverses ADR-036's "Noctalia as sole theming authority" decision (while keeping Noctalia as the shell), so it warrants an ADR change — an amendment to ADR-036 or a new ADR — landed alongside implementation. This design note owns the mechanism; the ADR owns the authority direction-change.
