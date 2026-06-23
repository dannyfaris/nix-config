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

- **Linux (niri + keyd):** base Hyper = **`Ctrl+Alt`**, leaving Shift and Super free as escalators. Optionally pad the chord with **`ISO_Level3_Shift` (AltGr)** for extra collision insulation (see §7) — niri binds it, keyd can synthesize it, and on a `us` layout it is otherwise unused, so it costs no escalator. Padding is *optional hardening*: bare `Ctrl+Alt` is already clean because niri captures compositor binds before any app — the only real conflict is `Ctrl+Alt+F1–F12` (VT switch), avoided by not binding the F-row.
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

## 11. Open / to verify

- **keyd → niri Level3 delivery on metis:** bind `ISO_Level3_Shift+<key>` to something and confirm the keyd-Hyper chord triggers it. If fussy, plain `Ctrl+Alt` is fine.
- **Escalator ergonomics:** confirm `Caps+Super` (Linux) / `Caps+Cmd` (macOS) is comfortable; reserve the extended tier for infrequent ops. Fallback escalator if not: Shift only.
- **The redesign is a #384 change.** It ripples across keyd, Karabiner, Hammerspoon, `niri.nix`, and `keybinds.md`; redefining the base chord by hand across five surfaces is the anti-pattern. Land it through the single-source registry so it is one edit — and resolve it *before* #384 generates, or the emitters reproduce the superseded all-four shape.

## 12. The shape (summary)

| Tier | Linux chord | macOS chord | Use |
|---|---|---|---|
| `Mod` alone | Super | (n/a — macOS owns WM) | niri manipulation |
| Hyper | `Ctrl+Alt` (+ opt. AltGr) | `Ctrl+Opt` | cross-platform base |
| Hyper+Shift | + Shift | + Shift | in-layer reverse / move |
| Hyper+Mod | + Super | + Cmd | extended (window geometry) |

---

This is a living research note (Refs, never Closes, its tracking issue per [our living-doc convention](../workflow.md)). Update as the redesign is verified and #384 progresses.
