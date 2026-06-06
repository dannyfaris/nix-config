# Keybindings

Keybindings for the niri desktop on metis. The **modifier-namespace philosophy** is now realized on both platforms — macOS via Karabiner-Elements ([karabiner.md](./karabiner.md)) and metis via keyd ([keyd.md](./keyd.md)) — and both carry Hyper binds on top, enumerated below. Living document — updated with every new binding.

## Philosophy

Keybindings separate into three modifier namespaces, each with a distinct
purpose:

- **`Super`** (written as `Mod` in niri's KDL syntax) — window
  management. Focus, movement, workspaces, spawning the terminal. The
  compositor's domain; niri owns all bindings in this namespace.

- **`Super+letter`** — reserved namespace for application commands
  (copy/paste/save/find/close-tab and similar). Under the philosophy, a
  system-wide remap (e.g. via `keyd`) would translate `Super+letter` →
  `Ctrl+letter` so application commands behave like macOS `Cmd+letter`.
  **Not currently implemented.** Standard app-command combos are left
  unbound at the niri level so the philosophy could land cleanly if
  ever pursued.

- **`Hyper`** — reserved namespace for personal system commands
  (launcher, clipboard, notifications, screenshots, lock screen).
  `Hyper` is the combined `Super+Ctrl+Alt+Shift` modifier;
  conventionally bound to Caps Lock via `keyd` or equivalent.
  **Realized on macOS via Karabiner-Elements (see
  [karabiner.md](./karabiner.md)) and on metis via keyd (see
  [keyd.md](./keyd.md))** — both sides produce the
  `Super+Ctrl+Alt+Shift` chord from Caps Lock. metis-side Hyper
  commands beyond the first (`Hyper+Return`→foot) land as their
  underlying tools arrive.

- **`Super+Hyper`** — reserved for extended window management
  (fullscreen, maximize-column, similar). Same dependency as Hyper.

The framework is a way of thinking, not a roadmap. The remaining
metis-side unrealised layer (the local `Super+Hyper`) may never be
implemented. The shape of the bind composition below is
nonetheless informed by the philosophy — reserved namespaces are
deliberately left unbound — so that if any of the layers eventually
land, migration is mechanical rather than disruptive.

Cross-platform portability is now realized: Karabiner on macOS and
keyd on metis (see [keyd.md](./keyd.md)) produce the same
`Super+Ctrl+Alt+Shift` Hyper modifier shape on both sides. The
`Super+letter` app-command translation has no macOS parallel (macOS
uses ⌘+letter natively, no remap needed); the `Hyper` namespace is
the cross-platform layer the philosophy enables. Bindings on top of
Hyper land per-platform as they materialize — `Hyper+Return`→foot on
metis, the Mission Control family on macOS.

## Implementation status

| Namespace | metis (niri) | macOS clients | Notes |
|---|---|---|---|
| `Super` (window management) | Active | n/a (macOS owns WM) | This document enumerates the metis bindings. |
| `Super+letter` (app commands) | Reserved | n/a (native ⌘+letter) | Standard combos deliberately unbound on metis. |
| `Hyper` (personal system) | **Active** (modifier via keyd; 1 bind) | **Active** (modifier + binds) | metis Hyper realized via keyd ([keyd.md](./keyd.md)): caps_lock → Super+Ctrl+Alt+Shift, first bind `Hyper+Return`→foot. macOS via Karabiner ([karabiner.md](./karabiner.md)) + Hammerspoon ([hammerspoon.md](./hammerspoon.md)). |
| `Super+Hyper` (extended WM) | Reserved | n/a | Hyper modifier now realized on metis (keyd); no extended-WM binds made yet. |

**Interim deviations** — knowingly accepted; would migrate if the
philosophy lands:

- `Mod+W` → `close-window`. Conflicts with the hypothetical
  `Super+W` → `Ctrl+W` (close tab) translation. Pragmatic choice for
  daily use; philosophical target is `Super+Hyper+W`.
- `Mod+Space` → fuzzel application launcher (landed per #73).
  Conflicts with the hypothetical `Hyper+Space` Spotlight-equivalent.
  Migration target is `Hyper+Space`.

## Active bindings

### Navigation

| Key | Action |
|---|---|
| `Mod+Left` | focus-column-left |
| `Mod+Down` | focus-window-down |
| `Mod+Up` | focus-window-up |
| `Mod+Right` | focus-column-right |
| `Mod+H` | focus-column-left (vim-style) |
| `Mod+J` | focus-window-down (vim-style) |
| `Mod+K` | focus-window-up (vim-style) |
| `Mod+L` | focus-column-right (vim-style) |
| `Mod+Ctrl+Left` | move-column-left |
| `Mod+Ctrl+Down` | move-window-down |
| `Mod+Ctrl+Up` | move-window-up |
| `Mod+Ctrl+Right` | move-column-right |
| `Mod+Ctrl+H` | move-column-left (vim-style) |
| `Mod+Ctrl+J` | move-window-down (vim-style) |
| `Mod+Ctrl+K` | move-window-up (vim-style) |
| `Mod+Ctrl+L` | move-column-right (vim-style) |

Niri's scrolling-tiling model distinguishes *columns* (laid out across
the workspace strip) from *windows within a column*. `H`/`L` traverse
columns horizontally; `J`/`K` traverse windows vertically within the
focused column.

### Window management

| Key | Action | Notes |
|---|---|---|
| `Mod+W` | close-window | Interim binding — see Implementation status |

### Workspaces

| Key | Action |
|---|---|
| `Mod+1` … `Mod+9` | focus-workspace 1..9 |
| `Mod+Shift+1` … `Mod+Shift+9` | move-window-to-workspace 1..9 |

### Spawn

| Key | Action |
|---|---|
| `Mod+Return` | spawn `foot` (terminal) |
| `Mod+Space` | spawn `fuzzel` (application launcher) |

### Session

| Key | Action | Notes |
|---|---|---|
| `Mod+Shift+E` | quit niri | Confirmation dialog shown; not an instant kill |

### Discovery

| Key | Action | Notes |
|---|---|---|
| `Mod+O` | toggle-overview | Birds-eye workspace view |
| `Mod+Shift+/` (i.e. `Mod+?`) | show-hotkey-overlay | Live cheat sheet for currently-bound keys |

### Screenshots

Capture uses niri's **built-in** screenshot actions — screen, window, and region are all native, and niri already backs the `org.freedesktop.portal.Screenshot` portal interface for apps, so no external capture tool (grim/slurp) is installed and annotation is deliberately out of scope (#100). The `Print` family reproduces niri's own defaults: save to disk (niri's default `screenshot-path`, `~/Pictures/Screenshots/`, which niri creates on first use) **and** copy to the clipboard. The `Mod+Ctrl+Shift+N` family echoes macOS's `Cmd+Ctrl+Shift+N` chord shape — where `+Ctrl` means *to clipboard* — so `write-to-disk=false` makes them clipboard-only; note `+5` is repurposed to window capture here (macOS uses it for the capture-options bar, which has no niri analogue). Region capture is niri's interactive overlay, which always does both disk + clipboard with no per-bind split, so its two chords (`Print`, `Mod+Ctrl+Shift+4`) are equivalent. macOS's *file*-variant chords (`Cmd+Shift+3/4/5`) would map to `Mod+Shift+3/4/5`, which are taken by `move-window-to-workspace` here — remap candidate tracked in #323.

| Key | Action | Notes |
|---|---|---|
| `Print` | screenshot | Interactive overlay — pick region / window / output; → disk + clipboard |
| `Ctrl+Print` | screenshot-screen | Whole focused output → disk + clipboard |
| `Alt+Print` | screenshot-window | Focused window → disk + clipboard |
| `Mod+Ctrl+Shift+4` | screenshot | Interactive overlay (macOS-style chord); also saves to disk — region can't be clipboard-only |
| `Mod+Ctrl+Shift+3` | screenshot-screen (`write-to-disk=false`) | Whole focused output → clipboard only |
| `Mod+Ctrl+Shift+5` | screenshot-window (`write-to-disk=false`) | Focused window → clipboard only |

### Hyper

The `Hyper` namespace is realized on metis via keyd (Caps Lock → `Super+Ctrl+Alt+Shift`; see [keyd.md](./keyd.md)). niri catches Hyper binds as `Mod+Ctrl+Alt+Shift+<key>` — niri's exact-modifier matching means a four-modifier chord never collides with the `Mod` / `Mod+Ctrl` / `Mod+Shift` binds above.

| Key | Action | Notes |
|---|---|---|
| `Hyper+Return` | spawn `foot` (terminal) | First metis Hyper bind. Mirrors the mac's `Hyper+Return` → Ghostty. `Mod+Return` (Spawn, above) retained for now. |

## Active bindings — macOS clients

Hyper (`⌘⌃⌥⇧`) is produced by Karabiner-Elements from `caps_lock`
(see [karabiner.md](./karabiner.md)). Two implementation layers
bind actions to Hyper chords on this side, picked per bind:

- **Karabiner remap** — same DriverKit layer as the modifier
  production. Best when the chord should translate to a native
  macOS shortcut transparently (the OS sees its own shortcut
  and runs its native handling). Used for the Spaces nav binds
  below: `Hyper+Arrow` is remapped to `Ctrl+Arrow`, which macOS
  routes to Mission Control's "Move to space left/right." The
  `mandatory` modifiers in Karabiner's `from` are consumed by
  the rule, so the emitted event is cleanly `Ctrl+Arrow` —
  macOS never sees the Hyper modifiers in this case.
- **Hammerspoon binding** — userspace event-tap layer via
  `~/.hammerspoon/init.lua`, managed declaratively by
  `home/darwin/hammerspoon.nix` (see [hammerspoon.md](./hammerspoon.md)).
  Best when the action requires Lua logic that has no native
  macOS equivalent (window-management decisions, conditional
  spawn-or-focus, app-aware actions). Used for the Spawn / focus
  binds below.

Apps in the Hammerspoon source carry both a bundle ID and a macOS
display name — the two layers are used asymmetrically by
Hammerspoon's APIs:

- **Bundle ID** for `hs.application.get` and
  `hs.application.launchOrFocusByBundleID` (robust against
  display-name drift / multi-variant installs).
- **Display name** for `hs.window.filter:setAppFilter`, which
  keys per-app filters off `hs.application:name()` (passing a
  bundle ID there silently registers a filter that never matches).

The bind-relevant pairings:

| App | Bundle ID | Display name |
|---|---|---|
| Ghostty | `com.mitchellh.ghostty` | `Ghostty` |
| Chrome | `com.google.Chrome` | `Google Chrome` |

### Spawn / focus

| Key | Action | Implementation | Notes |
|---|---|---|---|
| `Hyper+Return` | new fullscreen Ghostty window | Hammerspoon | always spawns a new window (`Cmd+N` to Ghostty), native-fullscreens it (new macOS Space), and focuses it |
| `Hyper+B` | focus existing Chrome window, else new fullscreen Chrome window | Hammerspoon | prefers the most-recently-focused Chrome window; unminimizes if needed; switches Spaces if the window lives on another Space. If no Chrome window exists, spawns a new one and fullscreens it. |

### Mission Control

| Key | Action | Implementation | Notes |
|---|---|---|---|
| `Hyper+Left`  | Move to space to the left  | Karabiner remap to `Ctrl+Left`  | macOS Mission Control's native "Move left a space" — `enabled = 1` by macOS default (symbolichotkey ID `79`); requires the binding to remain enabled at System Settings → Keyboard → Keyboard Shortcuts → Mission Control. |
| `Hyper+Right` | Move to space to the right | Karabiner remap to `Ctrl+Right` | as above, "Move right a space" (ID `81`). |
| `Hyper+Up`    | Mission Control overview (all windows + Spaces strip) | Karabiner remap to `Ctrl+Up` | macOS native "Mission Control" (symbolichotkey ID `32`); enabled by macOS default. Same toggle binding as a four-finger swipe up / F3 on the function row. |
| `Hyper+Down`  | Application windows (current-app exposé) | Karabiner remap to `Ctrl+Down` | macOS native "Application windows" (symbolichotkey ID `33`); enabled by macOS default. Shows all windows belonging to the currently-focused app — useful for "give me every Chrome / Ghostty / IDE window I have open." |
| `Hyper+1` … `Hyper+9` | Switch to Mission Control Desktop 1..9 | Karabiner remap to `Ctrl+1` … `Ctrl+9` | macOS Mission Control's "Switch to Desktop N" (symbolichotkey IDs `118`–`121` for Desktops 1–4, `190`–`194` for 5–9 — the full `190`–`197` block extends up through Desktop 12 but this bind targets 1–9). **Disabled by macOS default** — one-time operator setup required at System Settings → Keyboard → Keyboard Shortcuts → Mission Control → tick each "Switch to Desktop N" you want navigable. Per-Mac, manual. **Until enabled, the chord falls through to the focused app**: macOS's symbolichotkey intercept only fires when the entry is enabled, so an unset `Ctrl+N` is received by whatever app is foreground — VS Code / Cursor bind `Ctrl+1`–`9` to "Focus N-th editor group", JetBrains IDEs bind them to tool windows. Mirrors the niri-side `Mod+1` … `Mod+9` focus-workspace binds. |

## Reserved keys

### `Super+letter` (application-command namespace)

Standard app-command shortcuts. Left unbound at the niri level so a
future keyd remap can pass them through to applications as
`Ctrl+letter`: `Mod+C`, `Mod+V`, `Mod+X`, `Mod+Z`, `Mod+A`, `Mod+S`,
`Mod+F`, `Mod+Q`, `Mod+T`, `Mod+N`, `Mod+R`.

`Mod+W` is currently bound to `close-window` as an interim deviation
(see Implementation status).

### `Hyper` namespace (personal system commands)

`Hyper` (Caps Lock as modifier) is the philosophical home for
launcher, clipboard manager, notification panel, screenshot, lock
screen, and similar personal system commands.

**Status by platform:**

- **macOS clients** — modifier realized via Karabiner-Elements
  (`caps_lock` → `⌘ + ⌃ + ⌥ + ⇧`); see
  [karabiner.md](./karabiner.md). Binds layered via Hammerspoon
  (see [hammerspoon.md](./hammerspoon.md)). Active bindings
  enumerated above under §"Active bindings — macOS clients".
- **metis (niri)** — modifier **realized via keyd** (Caps Lock →
  `Super+Ctrl+Alt+Shift`; see [keyd.md](./keyd.md)). First bind:
  `Hyper+Return` → foot (see §Hyper under Active bindings).
  `Mod+Space` → fuzzel remains an interim Super-side deviation,
  migration target `Hyper+Space`.

Any future bindings here are added to this document when
implemented, and tagged by the platform(s) on which they apply.

### `Super+Hyper` (extended WM)

Less-common window-management actions (fullscreen, maximize-column,
and `close-window` if `Mod+W` ever migrates). Currently unrealised.

### Hardware media keys

`Print`, `Ctrl+Print`, `Alt+Print` are now bound to niri's built-in screenshot actions — see §"Screenshots" under Active bindings (#100). `XF86Audio*` (volume) and `XF86MonBrightness*` (brightness) remain unbound until the corresponding tooling lands (via niri spawn binds to `wpctl`, `brightnessctl`, etc.).

## Cadence

This is a living document. Conventions for evolution:

- **One bind per learning ceremony.** New bindings land one at a time
  via deliberate addition (issue + PR + doc update) rather than bulk
  refresh. Muscle memory gets space to absorb each.
- **Doc precedes implementation.** Each new bind lands first as a
  table row here; the implementing commit follows in the same PR.
- **No silent additions.** If a binding appears in
  `home/nixos/niri.nix` that is not in this document, that is a
  bug in cadence — fix the doc.

## See also

- `home/nixos/niri.nix` — the implementation surface.
- `docs/desktop/niri.md` — niri compositor selection rationale.
- #69 — the foundational close-out under which this document was
  created.
