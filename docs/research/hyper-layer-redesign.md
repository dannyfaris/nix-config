# Hyper layer redesign — modifier strategy for the cross-platform keybind layer

Status: **research note / option analysis, not a decision.** Captures a 2026-06-23 design discussion on redefining the Hyper modifier layer so it can carry the sub-tiers the keybind and action-menu work need, with UX parity (not identical chords) across NixOS (niri + keyd) and macOS (Karabiner). Pending verification (keyd→niri level-shift delivery; escalator ergonomics), so it is exploration, not a committed design — [`../desktop/keybinds.md`](../desktop/keybinds.md) documents what is bound *today* and is rewritten when #384 lands the new shape. Feeds #384 (the single-source registry that would emit this) and [`cross-platform-action-menu.md`](./cross-platform-action-menu.md) (the leader-key home for the chooser family). Modifier facts verified against niri's `niri-config/src/binds.rs`.

## 1. The defect in today's Hyper

Hyper is currently `Super+Ctrl+Alt+Shift` (all four modifiers), produced from Caps Lock by keyd (metis) and Karabiner (macOS). Because it already holds every modifier, it is a **terminal leaf**: nothing can stack on it. `Hyper+Shift`, `Hyper+Mod`, and `Super+Hyper` all *collapse* to plain Hyper, because the added modifier is already in the chord. `keybinds.md` documents exactly this collapse for the window-geometry tier.

## 2. The goal

Free two modifiers from the base so they can act as *escalators* on top of Hyper:

- **Shift** — the natural in-layer "reverse / move" modifier (focus vs move, forward vs back), the highest-value escalator to protect.
- **The platform-meta key** (Super on Linux / Cmd on macOS) — an extended tier (e.g. window management).

Target sub-tiers: `Hyper`, `Hyper+Shift`, `Hyper+Mod`/`Hyper+Cmd`, `Hyper+Mod+Shift`.

## 3. The constraint — a modifier budget

There are four stackable modifiers: Ctrl, Alt, Shift, Super/Cmd. Every one placed in the *base* is unavailable as an escalator. A robust 3-modifier base frees only **one** escalator; freeing **both** Shift and the platform-meta key forces a **2-modifier base** (`Ctrl+Alt`). Fn is not a fifth option (see §6).

## 4. The decision — parity, not identity

The Hyper chord **need not be the same combination on both platforms.** The objective is UX parity (one physical keystroke, the same layer, the same escalators), not an identical modifier set. This frees each platform to use its best-fit modifiers, and is what makes the asymmetric padding in §5 possible.

## 5. The landing — per platform

- **Linux (niri + keyd):** base Hyper = **`Ctrl+Alt`**, leaving Shift and Super free as escalators. (An optional **`ISO_Level3_Shift` (AltGr)** pad for extra collision insulation was investigated — §7 — but the on-box verify found it doesn't deliver Level3 on a `us` layout; **not adopted**, see §12.) Bare `Ctrl+Alt` is already clean because niri captures compositor binds before any app — the only real conflict is `Ctrl+Alt+F1–F12` (VT switch), avoided by not binding the F-row.
- **macOS (Karabiner):** base Hyper = **`Ctrl+Opt`**, leaving Shift and Cmd free. No level-shifts exist on macOS, but none are needed — Karabiner's *exact-modifier* matching already insulates `Ctrl+Opt+<key>` (it fires only on exactly that set).

Same UX on both (Caps → a layer + Shift / platform-meta escalators); different underlying chords — exactly the parity-not-identity model of §4.

## 6. Why not Fn

Fn is the one "modifier" that usually isn't one: on most keyboards it is handled in firmware below the OS and never emits a keycode keyd can see (likely invisible on metis), and on macOS it is semantically loaded (changes arrows→Home/End, Delete→forward-delete, the F-row). It would be fragile on Linux and messy on macOS — the opposite of a clean, symmetric base. Rejected.

## 7. Why ISO_Level3 (AltGr), not ISO_Level5

Both are real, niri-bindable modifiers absent from a bare `us` keymap, so **neither is "free"** — both need niri's xkb config to map a key to the level-shift. They differ on *support*, not neutrality: Level3/AltGr is first-class (one standard xkb option, ubiquitous, battle-tested); Level5 is rarer and fussier. Level5's extra "neutrality" buys almost nothing — an enabled-but-synthesized Level3 collides with nothing on a `us` base, and niri's exact-modifier matching separates chords regardless. So Level3 wins on robustness. The one case for Level5: if AltGr is actively used for accented-character typing on Linux, Level5 sidesteps the overlap — then its fussiness is justified.

## 8. The bonus — this restores the four-tier philosophy

The original keybind design wanted four namespaces, but `Super+Hyper` (extended WM) was *forced to collapse* into Hyper purely because of the all-four definition. Dropping the platform-meta key from the base **un-collapses** it: the "collapses to Hyper" caveat disappears, and the window-geometry cluster (currently shoehorned onto `Hyper+R/C/F/M`) can move to its proper extended-tier home. This is debt repayment, not added complexity.

## 9. Verified facts (the ceiling)

- **niri** binds (from `binds.rs`): Ctrl, Shift, Alt, Super (`Mod`), **ISO_Level3_Shift**, **ISO_Level5_Shift** — six.
- **macOS** binds: Cmd, Ctrl, Opt, Shift, Fn — five (Fn special).
- **Cross-platform intersection:** Ctrl, Alt, Shift, Super/Cmd — four. **There is no genuine fifth *cross-platform* modifier.** The level-shifts are Linux-only (usable for niri-only binds); Fn is unusable.

## 10. Spare keys and leader keys

A spare physical key gives more *triggers*, not more *modifiers* — any trigger must still resolve to a combination of the bindable modifiers (or to a key/sequence). So the best use of a never-pressed key is a **leader** (keyd `overload`/`oneshot`, Karabiner simlayer): press it, release, then a key — modal, not chordal, which escapes modifier exhaustion entirely and gives unbounded namespace.

Because the operator uses **Mac-layout keyboards on both machines**, the spare keys are symmetric in availability (Right Cmd, Right Opt exist on both). The natural application: **Right Cmd as a leader for the `hs.chooser` / launcher provider family** (emoji / settings / actions / keybinds) — see [`cross-platform-action-menu.md`](./cross-platform-action-menu.md). That family wants a leader, not more Hyper chords, so it costs zero Hyper budget.

## 11. Why not kanata — a programmable input-layer engine

[kanata](https://github.com/jtroo/kanata) is the QMK-like cross-platform remapper [`keyd.md`](../desktop/keyd.md) §Alternatives flagged as the one tool to revisit *"if the remap needs grow into real layering."* This redesign is that growth — so the trigger is checked here, and the answer is **not yet, not for this shape.**

**It lives on a different layer.** kanata is an *input-layer* engine (physical keys → logical keys/mods/chords); the single-source registry (#384) is a *binding-layer* tool (chord → semantic action). kanata cannot bind an action — it cannot "focus Chrome" or "open the chooser" (its `cmd` action is limited and not the compositor-action model). So at most it owns the input layer *beneath* the registry; it never replaces it. "Complement" is therefore architecturally true but not the test — the test is whether *this* input layer needs an engine, and it does not:

- **Sub-tiers are plain modifier stacking, not layering.** Once the base is `Ctrl+Alt` (§5), `Hyper+Shift` / `Hyper+Mod` are ordinary modifier chords niri and Karabiner already distinguish — no state machine, just the redefined base, a one-liner keyd *and* Karabiner already support.
- **Tap-hold is already native** — keyd `overload`, Karabiner `to_if_alone` (the §10 leader rides exactly these).
- **The leader is a chooser-opener, not an input sequence.** Right Cmd → open `hs.chooser` / `fuzzel`; the *GUI* dispatches emoji/settings/actions (§10, [`cross-platform-action-menu.md`](./cross-platform-action-menu.md)). That needs no input-layer state machine. kanata's real strength — input-layer leader *sequences* and chords — is the branch this design does **not** take.

**And the cross-platform pitch is weaker than the headline.** On macOS kanata runs *on* Karabiner's DriverKit driver, so it does **not** remove the Karabiner dependency (keyd.md), and nixpkgs ships no nix-darwin module — a hand-rolled root daemon, a regression from the clean `services.keyd` / declarative-Karabiner setup. Its `.kbd` is its own DSL: hand-authored (losing single-sourcing) or yet another emit target, and still binding-layer-blind.

**The gate.** Adopt kanata only if a concrete *input-layer* residue emerges beyond "plain modifier stacking + tap-hold + chord-opens-chooser" — genuine multi-key chords, tap-dance, or input-layer leader *sequences* wanted identically across both platforms. On the current design that residue is empty, so substrate stays keyd/Karabiner and dispatch stays registry + chooser; kanata, if ever adopted, slots *under* the registry as the input layer. (A 2026-06-23 prior-art scan — the keymap-single-sourcing research note, #432 — independently confirmed kanata is a *runtime* engine, not a single-source → multi-target emitter, consistent with this placement.)

## 12. Open / to verify

- **keyd → niri Level3 delivery on metis — resolved (2026-06-26): not adopted.** Verified at the physical metis keyboard (a temp `[hyper:C-A-G]` keyd layer + `wev`): keyd's `G` (altgr) emits `Alt_R`, which the `us` xkb layout folds into `Mod1` (plain Alt), **not** `Mod5`/`ISO_Level3_Shift` — so the pad delivers a redundant Alt, no Level3 insulation. Bare `Ctrl+Alt` stands. Making it work would need niri's xkb `lv3:ralt_switch` or keyd emitting the real `iso-level3-shift` keycode — not worth it for optional hardening. See #384.
- **Escalator ergonomics:** confirm `Caps+Super` (Linux) / `Caps+Cmd` (macOS) is comfortable; reserve the extended tier for infrequent ops. Fallback escalator if not: Shift only.
- **The redesign is a #384 change.** It ripples across keyd, Karabiner, Hammerspoon, `niri.nix`, and `keybinds.md`; redefining the base chord by hand across five surfaces is the anti-pattern. Land it through the single-source registry so it is one edit — and resolve it *before* #384 generates, or the emitters reproduce the superseded all-four shape.

## 13. The shape (summary)

| Tier | Linux chord | macOS chord | Use |
|---|---|---|---|
| `Mod` alone | Super | (n/a — macOS owns WM) | niri manipulation |
| Hyper | `Ctrl+Alt` | `Ctrl+Opt` | cross-platform base |
| Hyper+Shift | + Shift | + Shift | in-layer reverse / move |
| Hyper+Mod | + Super | + Cmd | extended (window geometry) |

---

This is a living research note (Refs, never Closes, its tracking issue per [our living-doc convention](../workflow.md)). Update as the redesign is verified and #384 progresses.
