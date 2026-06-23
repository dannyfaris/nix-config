# Cross-platform action menu (NixOS + macOS) — architecture exploration

Status: **thought exercise / option analysis, not a decision.** A conceptual sketch from a 2026-06-23 design discussion of how an Omarchy-style action/command menu could run on both the NixOS desktop (niri + Noctalia) and macOS (nix-darwin) with a *functionally equivalent* user experience — not identical tooling. Builds on [`launcher-strategy.md`](./launcher-strategy.md) (the pillar-2 gap, the Option A/B renderer split) and [`noctalia-plugin-system.md`](./noctalia-plugin-system.md). Ties to the cross-platform Hyper layer / semantic keybind registry (#384), runtime theme-switch (#411), and the Noctalia settings posture (#406). No design is committed here; decisions land in a doc/ADR per the repo's process.

## 1. Governing principle

The principle from the single-platform discussion — *share the data contract, specialize the renderer* — extends across the platform line as: **share the semantic registry; specialize the renderer AND the dispatch verbs.** The action *tree* is platform-agnostic Nix data; each platform supplies its own picker UI and its own concrete commands.

## 2. The key realization — this is the same source as the keybinds

A menu action and a keybind are the same kind of thing: a named capability with a per-platform command. #384 already proposes a semantic keybind registry that emits niri / Karabiner / Hammerspoon configs from one source. **The action menu is just another emitter over that same registry** — so this is not a new cross-platform system, it is a second renderer family over a source already planned.

A capability entry carries:

- `id`, `label`, `icon`, `category` / `children` — platform-agnostic (shared).
- `command.linux` / `command.darwin` — platform-specific (the verbs differ).
- optionally `keybind.{linux,darwin}` — consumed by #384's existing emitters.

At build, each host resolves its own verbs and writes its own `actions.json`: same tree, different leaves.

## 3. Architecture

```
              lib/capabilities.nix   ·   the semantic registry (shared, #384)
              id · label · icon · children · command.{linux,darwin} · keybind.{…}
                                   │
                ┌──────────────────┴───────────────────┐
          build: metis (NixOS)                   build: mac-mini (darwin)
                ▼                                        ▼
        actions.json  (Linux verbs)              actions.json  (macOS verbs)
                │                                        │
     ┌──────────┴───────────┐                 ┌──────────┴───────────┐
     │ RENDERER (Linux)      │                │ RENDERER (macOS)      │
     │ bash+jq → fuzzel      │                │ Lua → hs.chooser      │
     │   --dmenu  (popup)    │                │   (native popup)      │
     └──────────┬───────────┘                 └──────────┬───────────┘
   invoke: niri  Hyper+Space                 invoke: Hammerspoon Hyper+Space
                │                                        │
                ▼                                        ▼
   dispatch: noctalia ipc · niri msg ·        dispatch: hammerspoon · pmset ·
             systemctl · grim                           screencapture · open · osascript
                │                                        │
                └──────  same keystroke · same menu feel · base16-themed  ──────┘
```

## 4. Renderer per platform

**Linux (metis):** bash+jq → `fuzzel --dmenu` (Option B), or the Noctalia v5 Luau plugin (Option A). Native popup, invoked by a niri bind. See `launcher-strategy.md`.

**macOS (mac-mini):** the renderer must differ (no fuzzel/niri). Candidates weighed for equivalent UX while staying on-stack and declarative:

- **Hammerspoon `hs.chooser`** — *preferred.* A native, centered, fuzzy-search floating popup driven by Lua. Already in-stack (Hammerspoon runs on the Mac; #384 already generates Hammerspoon config), config-as-code (Nix-managed), and visually/functionally the twin of a fuzzel popup. Reads the same `actions.json`; drill-down is the same pattern as the bash loop (on a branch, repopulate `:choices()` and reshow).
- **fzf in a floating Ghostty window** — maximal *code* reuse (run the literal bash+jq dispatcher, swap `fuzzel --dmenu` → `fzf`), but terminal chrome instead of a native popup — slightly worse parity.
- **Raycast / Alfred** — rejected: more polished, but GUI/cloud-configured, against the declarative posture.

Note the symmetry: Option A's Linux renderer is Luau (Noctalia) and the macOS renderer is Lua (Hammerspoon) — both native popups reading the same JSON.

## 5. Parity on the two axes that matter

- **Invocation — identical.** The unified Hyper layer (keyd on Linux, Karabiner on macOS, both from #384) makes `Hyper+Space` open the action menu on both with the same physical keystroke. That single fact is most of "functionally equivalent."
- **Theming — shared palette.** The base16 palette is a Nix value (`config.lib.stylix.colors`), so it feeds `fuzzel.ini` on Linux and `hs.chooser`'s colour attributes (`bgDark` / `fgColor` / `subTextColor`) on macOS. (To confirm: Stylix's darwin coverage actually exposing the palette to the Hammerspoon config — partial on darwin.)

## 6. Honest wrinkles

- **"Equivalent" ≠ "identical content."** Some capabilities exist on one side only (e.g. "cycle niri column preset" has no macOS analogue; lock / Night Shift dispatch through entirely different verbs). The registry should allow **platform-scoped entries** present only where they mean something. The menu mechanism and the shared actions are parallel; the leaf set legitimately diverges — that is correct, not a gap.
- **Dispatch is where the platforms genuinely differ** — which is the whole reason the registry separates `command.linux` / `command.darwin`. Renderer and invocation converge; the verbs do not, and should not be forced to.
- **The "share contract vs share code" choice reappears across the platform line.** fzf-in-Ghostty maximizes shared *code* (one dispatcher) at a small UX cost; `hs.chooser` maximizes *UX parity* at the cost of a second (Lua) renderer. For an equivalent-UX objective, `hs.chooser` is the better trade — and it leans entirely on tooling already in the stack.

## 7. Through-line

Not two action menus: **one semantic capability registry** (shared with #384) and **two thin renderers** — bash+jq→fuzzel on Linux, Lua→`hs.chooser` on macOS — each fed the same generated `actions.json`, invoked by the same Hyper keystroke, painted from the same base16 palette. The platforms diverge exactly where they must (the dispatch verbs) and nowhere else.

## 8. Open questions

- Should the action registry and the #384 keybind registry be literally one `lib/capabilities.nix`, or two registries sharing a schema? (They model the same thing; unifying avoids drift, but couples two features.)
- Does Stylix on darwin expose the base16 palette cleanly enough to theme `hs.chooser`, or does the Mac side need a separate palette source?
- Hierarchy ergonomics in `hs.chooser` (repopulate-on-branch) vs the bash drill-down loop — equivalent in practice, or a parity gap?

---

This is a living research note (Refs, never Closes, its tracking issue per [our living-doc convention](../workflow.md)). Update as the action-menu and #384 directions firm up.
