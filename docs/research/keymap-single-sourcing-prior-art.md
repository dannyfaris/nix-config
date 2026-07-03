# Keymap single-sourcing prior art — is a cross-platform semantic-keymap emitter novel?

Status: **research note, not a decision.** Captured from a deep-research run (5 angles, 19 fetched sources, 80 claims → 25 adversarially verified via 3-vote, 0 killed) on 2026-06-23. Asks one question for the capability-registry work: does any existing tool single-source keybindings from one declarative source to *multiple* consumers across **both** Linux and macOS, with collision/availability linting — i.e. is Epic F's "semantic keymap → multi-target emitter + lint" genuinely novel, or already served? Feeds #384 (the registry) and #428 (Epic F, where the verdict is also summarised). Survey-bounded — see §7.

## 1. Verdict

**Partially served at the *component* level; genuinely open as the *integrated whole*.** No surveyed tool combines all three of: (a) one semantic source, (b) emission to a Linux target *and* a macOS target, and (c) collision + availability linting. The two halves of the idea each have mature prior art, but they live in entirely separate tools and have never been fused — and never across a Linux compositor/remapper *and* macOS Karabiner/Hammerspoon from one source.

## 2. The landscape

| Tool | What it is | Single-source → *many* targets? | Collision / availability lint? | Linux **and** macOS? | Licence |
|---|---|---|---|---|---|
| [HotkeyClash](https://github.com/Wunderlandmedia/HotkeyClash) | macOS conflict scanner (Karabiner + skhd + system + running apps) | No — emits nothing | **Yes** (collision *and* availability) | macOS only | GPL-2.0 |
| [PowerToys 0.94](https://devblogs.microsoft.com/commandline/powertoys-0-94-is-here-settings-search-shortcut-conflict-detection-and-more/) | Windows settings-UI conflict detection + OS-reserved labelling | No | **Yes** | Windows only | MIT |
| [home-manager `sxhkd`](https://github.com/nix-community/home-manager/blob/master/modules/services/sxhkd.nix) | Nix attrs → `sxhkdrc` | No — single target | No | Linux (X11) | MIT |
| [home-manager `i3-sway`](https://github.com/nix-community/home-manager/blob/master/modules/services/window-managers/i3-sway/lib/options.nix) | shared schema → i3 *or* sway config | No — sibling emitters, each single-target | No | Linux | MIT |
| [home-manager darwin keybindings](https://github.com/nix-community/home-manager/blob/master/modules/targets/darwin/keybindings.nix) | Nix → `DefaultKeyBinding.dict` (Cocoa) | No — single target | No | macOS only | MIT |
| [xremap](https://github.com/xremap/xremap) | JSON-compatible config → evdev/uinput remap | No — applies to itself | No | Linux only | MIT |
| [kanata](https://github.com/jtroo/kanata) | runtime cross-platform remapper | No — runtime interceptor, one keymap | No | Linux/macOS/Win | LGPL-3.0 |
| [Kinto](https://github.com/rbreaves/kinto) | Mac-style keymap for non-Apple OSes | No — separate per-platform engines | No | Linux/Win (not macOS) | OSS |

## 3. The two halves, never fused

- **Linting exists — but detection-only and single-platform.** [HotkeyClash](https://hotkeyclash.com/) scans three sources at once (running apps via the Accessibility API, automation configs `Karabiner-Elements` + `skhd`, and macOS system shortcuts like Spotlight/Mission Control/Screenshots) and reports chord conflicts. It is *deliberately* detection-only — "each app owns its own settings"; it edits and emits nothing. [PowerToys 0.94](https://github.com/microsoft/PowerToys/issues/44416) (Windows) marks chords "already in use (either by another module or by Windows itself)", with explicit OS-reserved labelling. Both prove real OS- *and* app-level availability linting — neither emits a config.
- **Codegen exists — but single-source → *single*-target, with zero linting.** home-manager's `sxhkd`, `i3-sway`, and darwin-keybindings modules each render keybinds-as-Nix-data to exactly one tool's config. The `i3-sway/lib/options.nix` shared schema is the closest structural cousin, but it is *schema-sharing between two sibling emitters* (i3 → i3 config, sway → sway config), not one semantic keymap fanned to many. [xremap](https://github.com/xremap/xremap) is "JSON-compatible … generate it from any language", but emits only its own YAML and applies it via uinput. None do duplicate/shadow/availability checking.
- **Cross-platform tools exist — but they are *runtime interceptors*, not generators.** [kanata](https://github.com/jtroo/kanata) (the strongest cross-platform candidate) runs as a live process intercepting input at the OS layer and applies *one* `.kbd` keymap; on macOS it *consumes* the Karabiner VirtualHIDDevice driver rather than *emitting* Karabiner configs. Kinto brings a Mac-style keymap to Linux/Windows (not macOS) via separate per-platform engines. Neither generates multiple tool configs, and neither lints.

## 4. Closest prior art — worth mining as we build

- **HotkeyClash — the availability-check blueprint.** It already reads Karabiner/skhd/macOS-system reserved chords to detect conflicts; that is exactly the *availability* lint (#428 scope note 2), proven on macOS. We would add the half it lacks — emission. (GPL-2.0 — relevant if any code is reused rather than re-implemented.)
- **home-manager `i3-sway/lib/options.nix` — the shared-schema analogue.** The nearest architectural precedent for a multi-target keybind layer in Nix; study it before designing `lib/capabilities.nix`, while noting its limit (sibling single-target emitters, not one-source-to-many).
- **xremap — codegen-friendliness.** Its JSON-compatible config shows the value of a structured, machine-generated keymap format.
- **PowerToys — the availability-vs-collision distinction**, validated in a shipping product: a chord can be conflict-free yet *unavailable* because the OS reserves it.

## 5. The gap none fill

One semantic source → a Linux compositor/remapper config **and** macOS Karabiner/Hammerspoon config, paired with collision + availability linting. The closest emitters are strictly single-target with no lint; the closest linters are detection-only, single-platform, and emit nothing; the closest cross-platform tool is a runtime interceptor applying one keymap. The capabilities are individually mature and have simply never been integrated.

## 6. Open design questions

- **kanata as a cross-platform layering engine — already evaluated, with a revisit-trigger now plausibly hit.** Our own [`keyd.md`](../desktop/keyd.md) §Alternatives weighed kanata when keyd/Karabiner were selected and rejected it for the *substrate* role: on macOS kanata runs *on* Karabiner's DriverKit driver, so it does **not** remove the Karabiner dependency, and nixpkgs ships no nix-darwin module — trading two short single-purpose configs for one tool plus a hand-rolled root daemon. But that rejection set an explicit trigger — *"revisit only if the remap needs grow into real layering … the one case where kanata's shared layered/leader DSL across both platforms would justify that macOS cost."* The [`hyper-layer-redesign.md`](./hyper-layer-redesign.md) work (Hyper sub-tiers, escalators, a leader-key DSL) is plausibly that case. So the live question is **not** "kanata as substrate" (settled — it rides Karabiner on macOS regardless) but whether the layering ambition justifies its shared DSL, the standing Karabiner cost included. Either way kanata is a *runtime* engine, not an emitter — it cannot bind semantic actions to niri/Hammerspoon commands or generate per-tool configs, so it would sit *underneath* the capability registry, complementing it rather than replacing it.
- **TUI cross-app unification (Tier 3)** — zellij/helix/lazygit/yazi: **no prior art surfaced**, but the corner was under-surveyed (see §7), so this is "not found", not "confirmed absent".
- **A tool-agnostic dotfile DSL** emitting keybinds to many tools from one source was not evidenced — only single-target Nix emitters survived verification.

## 7. Caveats

Source quality is strong: nearly all 25 claims rest on primary sources (project READMEs, home-manager module code on `master`, the Microsoft DevBlog) with unanimous 3-0 verifier votes (one 2-1, independently re-verified). But: two negative claims (no lint in xremap / kanata-switcher) rest on documentation absence, not exhaustive code audit. The **TUI-cross-app** angle and the **macOS tiling-WM** emit targets (skhd/yabai/AeroSpace, Hammerspoon/Spoons) were under-covered — they appear only as *scan targets* of HotkeyClash, not as emit targets of any generator. The lint landscape is **recent and evolving** (PowerToys 0.94 and HotkeyClash both shipped late 2025), so a tool fusing emission + lint could emerge. The verdict is bounded by what was surveyed; a niche dotfile-codegen project on these axes could exist outside the searched sources.

## 8. Implication

The integrated concept is genuinely unserved — which **confirms the registry (Epic F) fills a real gap** and supports building it as an **extraction-ready `lib/`** with eventual packaging in mind (#428 scope note 1), proving the pattern in our own use first. The availability-lint half has a usable blueprint (HotkeyClash) and the codegen half has the closest Nix precedent (i3-sway shared schema) to learn from.

---

This is a living research note (Refs, never Closes, its tracking issue per [our living-doc convention](../workflow.md)). Update as the keybind-management landscape moves — especially if a tool fuses multi-target emission with availability linting.
