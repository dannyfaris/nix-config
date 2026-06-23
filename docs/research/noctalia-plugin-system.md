# Noctalia plugin systems (v4 + v5) — research findings

Status: **research note, not a decision.** Findings verified from primary sources on 2026-06-23 — the upstream plugin repos ([`legacy-v4-plugins`](https://github.com/noctalia-dev/legacy-v4-plugins), [`official-plugins`](https://github.com/noctalia-dev/official-plugins), [`community-plugins`](https://github.com/noctalia-dev/community-plugins)), the [v5 plugin development doc](https://docs.noctalia.dev/v5/plugins/development/), and the shipped reference plugins (`example`, `translator`). Records *what Noctalia's plugin systems can do* and their maturity; it proposes no design. Relevant to the pillar-2 question in [`launcher-strategy.md`](./launcher-strategy.md) and the settings-posture question (#406). The operator pins `legacy-v4` (ADR-036/#385).

## 1. Key findings

- **v4 and v5 have different, incompatible plugin systems.** v4 plugins are **QML**; v5 plugins are **Luau + `plugin.toml`**. A v4 plugin does not run on v5 and vice-versa.
- **v4 has a large mature ecosystem (~150 plugins); v5's is a near-empty hard reset.** v5 is explicitly experimental and currently ships only 5 official plugins. The plugins most relevant to a launcher/action menu (`custom-commands`, `dmenu`, `keybind-cheatsheet`) **exist in v4 but are not yet ported to v5** — so on this axis **v5 currently regresses**.
- **The v5 API is capable where it matters:** a `[[launcher_provider]]` entry type with a real query→results→activate lifecycle, plus a host **filesystem API** (`readFile`/`writeFile`/`fileExists`/`pluginDir`) and `json.decode`. That combination means a v5 plugin *can* read its configuration/data from a file on disk — i.e. a file a flake could generate. (Capability only; no design implied here.)
- **Plugin config in both lines is GUI-managed by default** (`settings.json` written through the in-shell settings UI), not the flake — the #406 tension. v5's filesystem API is what makes a non-GUI source *possible*; v4's plugins do not offer that escape.

## 2. v4 plugin ecosystem (the operator's current line)

[`legacy-v4-plugins`](https://github.com/noctalia-dev/legacy-v4-plugins) is a single repo of ~150 official plugins (QML), discovered/installed through Noctalia's in-shell plugin-manager (a `registry.json`). Verified plugin types in v4: bar widgets, desktop widgets, control-center widgets, **launcher providers**, panels, a headless main component, and a settings UI. Config is per-plugin `manifest.json` + a GUI-managed `settings.json` (not committed).

Directly relevant plugins present in v4:

- **`custom-commands`** — a launcher-provider command palette. Each entry is name + Tabler icon + shell command, run via `sh -lc`. Invoked by the `>run` prefix, normal search, or the IPC call `qs -c noctalia-shell ipc call plugin:custom-commands toggle`. Flat list (no nesting). Command list saved automatically to the plugin's `settings.json` (GUI-managed).
- **`dmenu`** — a dmenu *provider* (Noctalia can act as a dmenu backend).
- **`keybind-cheatsheet`** — a shell-native keybind cheatsheet.
- Plus niri-specific plugins (`niri-overview-launcher`, `niri-workspaces`, …), `noctalia-calculator`, `plugin-manager`, and ~140 others.

## 3. v5 plugin model (verified from source)

A v5 plugin is a directory with a static `plugin.toml` manifest and one or more [Luau](https://luau.org) entry scripts ([dev doc](https://docs.noctalia.dev/v5/plugins/development/)).

- **Manifest** (`plugin.toml`): `id` (`author/name`), `name`, `version`, `min_noctalia` (e.g. `"5.0.0"`), `author`, `license`, `tags`, `icon`, `description`. Entries are declared as TOML array-of-tables blocks.
- **Entry types** (verified in the `example`/`translator` manifests): `[[widget]]` (bar widget), `[[service]]` (headless, publishes state), `[[shortcut]]` (control-center tile), `[[launcher_provider]]` (launcher result source). A `[[panel]]` type also exists (full-screen overlay).
- **Settings** are declared per-entry as `[[…setting]]` blocks (`key`, `type` ∈ string/glyph/bool/…, `label_key`, `default`); they render as typed controls in the settings GUI and are read in Luau via `noctalia.getConfig(key)`. So the *schema* is static in the manifest, but the *values* are GUI-managed.
- **Launcher-provider lifecycle** (the action-menu-relevant entry): manifest sets `prefix` (e.g. `/tr`), `glyph`, `include_in_global_search`, `debounce_ms`. The script implements `onQuery(text)` and replies with `launcher.setResults(query, results)` where each result is `{ id, title, subtitle, glyph, score }`; **`onActivate(id)`** runs when a result is selected. Results sort by `score` desc. Async is supported — call `setResults` again from an HTTP/subprocess callback when a slow answer lands.
- **Host capabilities (`noctalia.*`):** Filesystem — `readFile(path)`, `writeFile(path, content)`, `fileExists(path)`, `listDir(path)`, `pluginDir()` (relative paths resolve against the plugin's own dir). Plus `json.decode/encode`, `http`, `state.get/set/watch`, `getConfig`. A **subprocess** capability is referenced (used to run external commands) — exact API name not captured here.
- **Declarative UI:** a `ui.*` builder (e.g. `ui.button` with `variant` ∈ default/primary/secondary/destructive/outline/ghost; callbacks name a global Luau function).
- **Isolation & DX:** each entry runs in its **own isolated Luau VM, off the UI thread, with per-call time budgets** (a slow/crashing script can't wedge the shell). `.luau` files **hot-reload** on save; manifest changes apply on reload. Local install = drop the directory in the plugins path and enable once.

## 4. v5 ecosystem maturity

- [`official-plugins`](https://github.com/noctalia-dev/official-plugins) is **core-team only** ("We do not accept PRs for new third-party plugins in the official repo") and currently contains 5 plugins: `example`, `screen_recorder`, `timer`, `translator`, `bongocat`.
- [`community-plugins`](https://github.com/noctalia-dev/community-plugins) is the third-party channel and is effectively empty (README only; "coming soon").
- The dev docs state the plugin system is **"under heavy development and subject to breaking changes at any time"** and should be treated as experimental.

## 5. Relevance to this repo

- **Pillar-2 (action menu) capability** exists shell-native on **v4 today** (`custom-commands`, flat) but its config is GUI-managed — see [`launcher-strategy.md`](./launcher-strategy.md) §4 Option A and #406.
- **v5 is the only line whose API could source plugin data from a flake-written file** (`readFile` + `json.decode`), which is the technical hook relevant to resolving the #406 declarative-config tension for this surface — *as a capability*, not a committed plan.
- **Migration caveat:** moving the desktop v4→v5 today would lose the ~150-plugin v4 ecosystem (incl. `custom-commands`/`dmenu`/`keybind-cheatsheet`), since those aren't ported. This reinforces the deliberate `legacy-v4` pin (ADR-036/#385).

## 6. To confirm (not yet verified)

- The exact v5 **subprocess/exec** API (name, sync vs async, return shape).
- Whether v5 `readFile` accepts **absolute / XDG paths** or is constrained to `pluginDir()` (the latter still permits a flake to write into a Nix-managed plugin directory).
- How a v5 launcher provider is **opened directly via IPC/keybind** to a specific prefix (v4 uses `ipc call plugin:<id> toggle`; the v5 equivalent via `noctalia msg plugin …` / launcher query pre-fill was not pinned down).
- Whether `keybind-cheatsheet` / `custom-commands` / `dmenu` have v5 ports in progress upstream.

---

This is a living research note (Refs, never Closes, its tracking issue per [our living-doc convention](../workflow.md)). Update as the v5 plugin system stabilises and plugins are ported.
