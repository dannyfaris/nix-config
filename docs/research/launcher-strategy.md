# Launcher strategy — Omarchy's three pillars on niri + Noctalia + Nix

Status: **research note, not a decision.** Captured from a deep-research run (6 angles, 23 fetched sources, 104 claims → 25 adversarially verified, 23 confirmed) on 2026-06-23, benchmarked against Omarchy (`basecamp/omarchy`) as the gold standard. The run's automatic synthesis step hit a session limit, so the synthesis below was done by hand from the verified claim set; two claims (DMS spotlight launcher; the exact Noctalia→niri keybind wiring) failed to *verify this run* due to the same limit — they are not refuted, just carried as unverified-this-run and flagged inline. Feeds [`../desktop/keybinds.md`](../desktop/keybinds.md), the semantic keybind registry (#384), and any launcher/menu selection doc.

## 1. The headline

Omarchy's desktop UX rests on three pillars: a **launcher** (Walker), a **hierarchical action/command menu** (`omarchy-menu`), and a **hotkey cheatsheet** (`omarchy menu keybindings`). Mapped onto this operator's stack, **two of the three already exist**:

- **Pillar 1 — launcher:** [`home/nixos/niri.nix`](../../home/nixos/niri.nix) already binds `Mod+Space` (and `Hyper+Space`) to `noctalia-shell ipc call launcher toggle`. Noctalia's shell-native launcher is the operator's launcher, themed by Noctalia's runtime scheme.
- **Pillar 3 — hotkey cheatsheet:** the same module binds `Mod+Shift+Slash` to niri's **built-in `show-hotkey-overlay`**, which reads the live keybind set. Omarchy hand-rolls this (`omarchy menu keybindings --print`); niri ships it.
- **Pillar 2 — action/command menu:** *missing.* There is no `omarchy-menu` equivalent — a hierarchical, single-sourced menu of system/theme/session actions. **This is the real gap and the highest-value steal from Omarchy.**

So the strategy is not "replace the launcher" — it's "build pillar 2 well, and decide whether pillar 1 stays shell-native or gains a standalone."

## 2. The Omarchy benchmark, dissected

Omarchy installs to a read-only tree at `~/.local/share/omarchy/` (`bin/` scripts symlinked to PATH, `config/` templates, `themes/`, `default/`, `migrations/`, `install/`) ([SKILL.md](https://github.com/basecamp/omarchy/blob/dev/default/omarchy-skill/SKILL.md)).

- **Launcher — Walker** ([abenz1267/walker](https://github.com/abenz1267/walker)): a GTK4/Rust launcher whose logic lives in an external **Elephant** daemon managing pluggable *providers* (desktop apps, calculator `=`, files `/`, runner, websearch, clipboard `:`, symbols, dmenu, and notably **first-class Niri Actions & Sessions**). Powerful, but the daemon is a hard dependency ("Walker cannot function without Elephant running").
- **Action menu — `omarchy-menu`** ([bin/omarchy-menu](https://github.com/basecamp/omarchy/blob/master/bin/omarchy-menu)): a script that composes hierarchical entries and pipes them through Walker's **dmenu provider** ("seamless menus"), dispatching the selected action. Exposed via the unified `omarchy menu …` CLI; invoked ~`Super+Alt+Space`.
- **Hotkey cheatsheet:** `omarchy menu keybindings --print` renders the current bindings.
- **Theming:** `omarchy theme set <name>` plus a post-change hook at `~/.config/omarchy/hooks/theme-set` re-themes Walker and the rest in lockstep — the same conductor idea as our Stylix/Noctalia handoff, done imperatively.

## 3. Launcher candidates (pillar 1)

| Tool | Model | dmenu mode | Stylix/base16 theming | Nix consumability | Verdict for this stack |
|---|---|---|---|---|---|
| **Noctalia launcher** (current) | Shell-native (Quickshell), IPC-toggled (`ipc call launcher toggle`) | n/a (shell-native) | Themed by Noctalia's **runtime scheme** — already follows the live palette | Already wired via the Noctalia HM module | **Keep as primary.** Zero extra moving parts; already consistent with the live theme. |
| **fuzzel** | Lightweight native Wayland launcher | Yes (`--dmenu`) | **First-class Stylix target** (`stylix.targets.fuzzel.enable`, defaults to `autoEnable`; pulls base16 via `config.lib.stylix.colors` — *no hand CSS*) | Stylix module + home-manager `programs.fuzzel` | **Best standalone for Stylix-cleanliness.** The right tool for pillar 2's dmenu backend. |
| **Walker** | GTK4/Rust + **Elephant daemon** + providers (incl. first-class **Niri Actions & Sessions**) | Yes (dmenu provider, "seamless menus") | GTK4 theme files — **no base16 Stylix target**; manual theming to match | **First-class**: flake with both `homeManagerModules.walker` and `nixosModules.walker`, follows `elephant`, two cachix caches | **Most featureful, weakest theming fit.** Adopt only if the provider ecosystem (esp. Niri Actions) is specifically wanted; the Elephant daemon is a standing cost. |
| **anyrun** | Plugin-based krunner-like (Applications, Shell, Symbols, Rink, Websearch, Nix-run, **niri-focus**, Actions); Stdin = dmenu | Yes (Stdin plugin) | **Hand-maintained GTK4 CSS** (RON config); no base16 auto | Upstream HM module in nixpkgs; dev flake + `anyrun.cachix.org` (overriding nixpkgs input → cache misses) | Capable but **hand-CSS theming** makes it a worse Stylix fit than fuzzel. |

`rofi-wayland` / `wofi` / `tofi` weren't deeply verified this run; fuzzel is the niri-community standard and the only one with a *confirmed* first-class Stylix target, so it's the recommended standalone where one is wanted.

## 4. The action/command menu (pillar 2 — the gap)

Two viable builds; the choice is **visual cohesion vs declarative purity**, and is coupled to the Noctalia settings-posture question (#406).

### Option A — Noctalia-native (`custom-commands` plugin, v4 only)

Noctalia v4's plugin ecosystem ([`noctalia-dev/legacy-v4-plugins`](https://github.com/noctalia-dev/legacy-v4-plugins), ~150 plugins) ships **`custom-commands`**: a launcher-provider command palette — each entry is name + Tabler icon + shell command, run via `sh -lc`. Invoked by the `>run` prefix, normal search, or a direct keybind: `qs -c noctalia-shell ipc call plugin:custom-commands toggle`. The repo also ships a **`dmenu`** provider (Noctalia as the dmenu backend) and **`keybind-cheatsheet`**.

- **Pro:** maximal visual consistency — drawn by the shell already running, on the live scheme; no second binary.
- **Con (load-bearing for this repo):** the command list saves to the plugin's GUI-managed `settings.json`, and the plugin installs via Noctalia's in-shell plugin-manager (a `registry.json`), **not the flake** — so neither the install nor the action list is Nix-declarative by default. This is exactly the #406 tension. Also **flat, not hierarchical** (Omarchy's menu nests; `custom-commands` is a single list — use the `dmenu` provider + a script for nesting).
- **Version:** v4 only. **v5 currently regresses** — its plugin ecosystem is a hard reset ([`official-plugins`](https://github.com/noctalia-dev/official-plugins), "v5 onward", experimental) with only 5 plugins; `custom-commands`/`dmenu`/`keybind-cheatsheet` are not yet ported. Validates the deliberate `legacy-v4` pin.

### Option B — `fuzzel --dmenu` + Nix-single-sourced action tree

Replicate `omarchy-menu` the Nix-idiomatic way: a hierarchical action menu driven by `fuzzel --dmenu`, with the action list single-sourced in Nix.

- **Picker:** `fuzzel --dmenu` — already Stylix-themed (first-class target), so consistent for free.
- **Single-sourcing:** define the action tree once in Nix (label → command, nested), generate the menu script from it — no drift between the menu and what it runs ([fuzzel-scripts pattern](https://dnsc.io/writing/fuzzel-scripts/)).
- **Pro:** fully declarative, in the flake; supports nesting in-script. **Con:** adds fuzzel as a second UI surface alongside Noctalia (a minor theming-source seam: Stylix for fuzzel vs Noctalia's runtime scheme).

**Why pillar 2 matters either way:** scrollable-tiling niri has no "start menu"; a single keybind to a searchable action palette (theme switch, session, power, screenshot modes, toggles) is the Omarchy ergonomic the operator is missing — and it composes with the runtime theme-switch work (#411) as one of its entries.

## 5. The hotkey cheatsheet (pillar 3 — already covered, upgrade path open)

niri's **`show-hotkey-overlay`** (already bound) reads the live binding set, so the baseline is done with zero extra tooling. Two upgrades exist if richer output is wanted:

- **Noctalia keybind-cheatsheet plugin** ([noctalia.dev/plugins/keybind-cheatsheet](https://noctalia.dev/plugins/keybind-cheatsheet)) — a shell-native cheatsheet, consistent with the Noctalia surface.
- **Single-source registry (#384)** — the standing idea to generate niri + Karabiner + Hammerspoon configs *and* a `keybinds.md` table from one semantic registry, with a collision lint. That registry is the natural source for a generated cheatsheet too, making the overlay, the doc table, and the configs all one source of truth.

## 6. Recommendation

1. **Keep Noctalia's launcher** as the primary app launcher (pillar 1) — it's already wired and already tracks the live palette. Do **not** adopt Walker for app-launching alone; the Elephant daemon and non-base16 theming aren't worth it absent a specific need for its Niri-Actions provider.
2. **Build the missing action menu (pillar 2)** — the highest-value steal from Omarchy. Choose per §4: **Option A** (Noctalia `custom-commands`, max cohesion, but GUI-managed state — viable only while on v4) or **Option B** (`fuzzel --dmenu` + Nix action tree, fully declarative, slight theming seam). The pick hinges on how #406 resolves the Noctalia GUI-vs-Nix settings posture: if GUI-managed plugin state is accepted, Option A is the most cohesive; if declarative-in-flake is required, Option B. Defaulting to **Option B** absent a #406 resolution, since it doesn't add GUI-managed state.
3. **Leave pillar 3 on niri's native overlay**; fold a generated cheatsheet into #384 if/when that registry lands.

## 7. Open questions / unverified

- **DMS spotlight launcher** — its built-in Spotlight (apps/files/emoji/windows/calc/commands) failed to verify *this run* (session limit, abstention not refutation); the prior prior-art run documented it. Not load-bearing here since the recommendation keeps Noctalia.
- **Exact Noctalia→niri keybind wiring** — one claim about `spawn-sh` in `config.kdl` was refuted on the mechanism detail; the substance (Noctalia launcher toggled via IPC spawn from niri) is confirmed and matches the operator's actual `programs.niri.settings` binding. No action.
- ~~Whether a Quickshell-native (Noctalia) action menu could host pillar 2 instead of fuzzel~~ — **resolved 2026-06-23** (§4 Option A): yes, on **v4**, via the `custom-commands` plugin (`legacy-v4-plugins`), with a `dmenu` provider for nesting; **v5 does not yet ship these** (plugin ecosystem reset). The remaining question is whether its GUI-managed `settings.json` posture is acceptable vs the declarative fuzzel route — i.e. a #406 decision, not a capability gap.

---

This is a living research note (Refs, never Closes, its tracking issue per [our living-doc convention](../workflow.md)).
