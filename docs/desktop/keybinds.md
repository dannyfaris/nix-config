# Keybindings

Keybindings for the niri desktop on metis. The **modifier-namespace philosophy** is now realized on both platforms — macOS via Karabiner-Elements ([karabiner.md](./karabiner.md)) and metis via keyd ([keyd.md](./keyd.md)) — and both carry Hyper binds on top (the full set on macOS; on metis the nav family + launcher + browser + terminal, with only `Hyper+Down` lacking a niri analogue). Living document — updated with every new binding.

## Philosophy

Keybindings separate into three modifier namespaces, each with a distinct
purpose:

- **`Super`** (written as `Mod` in niri's KDL syntax) — niri-specific
  window **manipulation**: moving windows and columns, resizing,
  consuming/expelling from a column, closing. The scrollable-tiling
  operations with no macOS analogue — niri's domain. *Navigation*
  (focus, workspace-switch, overview) is **not** here; it migrates to
  `Hyper` (see the cross-platform analogy below).

- **`Super+letter`** — reserved namespace for application commands
  (copy/paste/save/find/close-tab and similar). Under the philosophy, a
  system-wide remap (e.g. via `keyd`) would translate `Super+letter` →
  `Ctrl+letter` so application commands behave like macOS `Cmd+letter`.
  **Not currently implemented.** Standard app-command combos are left
  unbound at the niri level so the philosophy could land cleanly if
  ever pursued.

- **`Hyper`** — the **cross-platform layer**: navigation (focus,
  workspace-switch, overview), application spawn (terminal, browser),
  and personal-system commands (launcher, clipboard, notifications,
  lock). `Hyper` is the combined `Super+Ctrl+Alt+Shift` modifier from
  Caps Lock, realized on macOS via Karabiner-Elements
  ([karabiner.md](./karabiner.md)) and on metis via keyd
  ([keyd.md](./keyd.md)). Its defining rule is the cross-platform
  analogy below; the paired mapping is the source of truth.

- **`Super+Hyper`** — reserved for extended window management
  (fullscreen, maximize-column, similar). Same dependency as Hyper.

**Cross-platform analogy — the defining rule for `Hyper`.** Each `Hyper` chord performs the *analogous* action on both platforms, so the muscle memory built on the Mac transfers to niri intact. The Mac's `Hyper+Left/Right` moves between Spaces → on niri it focuses the column left/right; `Hyper+1`–`9` switches Space → focuses workspace N; `Hyper+Up` is Mission Control → niri's overview; `Hyper+Return` opens a terminal on both. The paired table under [§Cross-platform Hyper mapping](#cross-platform-hyper-mapping) is the source of truth.

**Decision — navigation migrates `Super` → `Hyper`.** Because the analogy puts navigation on `Hyper`, niri's navigation binds move off `Super`: focus-column, workspace-switch, and overview migrate to their `Hyper` homes, leaving `Super` for niri-specific *manipulation* (move, resize, consume/expel, close — actions with no Mac counterpart). Per the cadence below this is incremental — one bind per ceremony — so the Active-bindings tables keep each bind's current `Super` home shown with its `Hyper` target until it moves.

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

## Cross-platform Hyper mapping

The canonical mapping: each `Hyper` chord and its analogous action per platform. niri binds land per the one-bind-per-ceremony cadence — ✓ marks those implemented on niri; `Hyper+Down` is the only chord with no niri analogue.

| `Hyper` chord | macOS | niri analogue | niri status |
|---|---|---|---|
| `Hyper+Left` / `Right` | move between Spaces | focus-column-left / right | ✓ |
| `Hyper+1`–`9` | switch to Space N | focus-workspace N | ✓ |
| `Hyper+Up` | Mission Control overview | toggle-overview | ✓ |
| `Hyper+Down` | application-windows exposé | *(no analogue — niri has no per-app window group)* | n/a |
| `Hyper+Space` | launcher (`⌘Space` natively — not a Hyper bind) | Noctalia launcher (IPC) | ✓ — migrates `Mod+Space` |
| `Hyper+Return` | new terminal window | spawn foot | ✓ |
| `Hyper+B` | Chrome window | spawn default browser | ✓ — spawn-only |

**niri-specific `Hyper` binds** (no Mac mirror) live in the same namespace and land as their tools arrive — e.g. `Hyper+Escape` → power/session menu (#98), a lock-now bind, clipboard / notification / screenshot actions. niri's own extra navigation (e.g. vertical window-focus within a column) either stays on `Super` or gets a niri-only `Hyper` bind, decided per bind.

## Implementation status

| Namespace | metis (niri) | macOS clients | Notes |
|---|---|---|---|
| `Super` (niri manipulation) | Active | n/a (macOS owns WM) | Move/resize/consume/close — niri-specific. Navigation is migrating out to `Hyper`. |
| `Super+letter` (app commands) | Reserved | n/a (native ⌘+letter) | Standard combos deliberately unbound on metis. |
| `Hyper` (cross-platform: nav + spawn + system) | **Active** (modifier via keyd; nav + launcher + browser + terminal bound) | **Active** (modifier + binds) | Realized via keyd on metis ([keyd.md](./keyd.md)) + Karabiner/Hammerspoon on macOS. The paired mapping above is the source of truth. |
| `Super+Hyper` (extended WM) | Reserved | n/a | Hyper modifier now realized on metis (keyd); no extended-WM binds made yet. |

**Transitional bindings** — the `Hyper` target is now bound; the `Super` home is retained alongside until the migration settles, then retired (the `Mod+Return`/`Hyper+Return` pattern, applied across the nav family):

- Navigation: `Hyper+Left`/`Right` (focus-column), `Hyper+1`–`9` (focus-workspace), `Hyper+Up` (overview) added; `Mod+Left`/`Right` + vim `Mod+H`/`L`, `Mod+1`–`9`, and `Mod+O` retained.
- `Hyper+Space` → the Noctalia launcher (the Spotlight-equivalent); `Mod+Space` retained.
- `Hyper+Return` → foot and `Mod+Return` coexist as before.

**Letter-space deviation** (separate from the migration): `Mod+W` → `close-window` sits in the reserved `Super+letter` space (it would clash with a hypothetical `Super+W` → `Ctrl+W`). close is manipulation, so it stays on `Super`; the philosophical target is `Super+Hyper+W`.

## Active bindings

*Navigation rows (focus-column, focus-workspace, overview) are **transitional** — migrating to their `Hyper` homes per [§Cross-platform Hyper mapping](#cross-platform-hyper-mapping); the tables below show what is bound today. Manipulation rows (move-column/window, move-to-workspace, close) stay on `Super`.*

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
| `Mod+W` | close-window | Letter-space deviation — see Implementation status |

### Workspaces

| Key | Action |
|---|---|
| `Mod+1` … `Mod+9` | focus-workspace 1..9 |
| `Mod+Ctrl+1` … `Mod+Ctrl+9` | move-window-to-workspace 1..9 |

### Spawn

| Key | Action |
|---|---|
| `Mod+Return` | spawn `foot` (terminal) |
| `Mod+Space` | Noctalia launcher — `noctalia-shell ipc call launcher toggle` (ADR-036, #385) |

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

Capture uses niri's **built-in** screenshot actions — screen, window, and region are all native, and niri already backs the `org.freedesktop.portal.Screenshot` portal interface for apps, so no external capture tool (grim/slurp) is installed and annotation is deliberately out of scope (#100). Screenshots save to `~/Pictures/Screenshots/` — set explicitly via `screenshot-path` and created by a `home.activation` hook in `home/nixos/niri.nix`, because niri creates only the *last* path component and **silently drops the capture when the parent is missing** ([niri #807](https://github.com/YaLTeR/niri/issues/807)). `~/Pictures/Screenshots` is the fleet-wide save location, matching the Mac's `screencapture.location`.

The chord layout mirrors macOS's screenshot shortcuts **after the file/clipboard swap** (see [§Active bindings — macOS clients → Screenshots](#screenshots-1)): the bare `Mod+Shift+N` family copies **to clipboard** (the accessible default), and `Mod+Ctrl+Shift+N` saves **to disk** (+ clipboard). `+5` is repurposed to window capture (macOS uses it for the capture-options bar, which has no niri analogue). Region capture is niri's interactive overlay, which always does both disk + clipboard with no per-bind split, so `Mod+Shift+4` and `Mod+Ctrl+Shift+4` are equivalent. The bare `Mod+Shift+N` chords are free because `move-window-to-workspace` relocated to `Mod+Ctrl+N` (resolving the #323 clash). The hardware `Print` family stays bound to niri's defaults (disk + clipboard).

| Key | Action | Notes |
|---|---|---|
| `Mod+Shift+3` | screenshot-screen (`write-to-disk=false`) | Whole focused output → clipboard only |
| `Mod+Shift+4` | screenshot | Interactive overlay — pick region / window / output; → disk + clipboard |
| `Mod+Shift+5` | screenshot-window (`write-to-disk=false`) | Focused window → clipboard only |
| `Mod+Ctrl+Shift+3` | screenshot-screen | Whole focused output → disk + clipboard |
| `Mod+Ctrl+Shift+4` | screenshot | Interactive overlay; equivalent to `Mod+Shift+4` (region can't be clipboard-only) |
| `Mod+Ctrl+Shift+5` | screenshot-window | Focused window → disk + clipboard |
| `Print` | screenshot | Hardware key — interactive overlay → disk + clipboard |
| `Ctrl+Print` | screenshot-screen | Hardware key — whole output → disk + clipboard |
| `Alt+Print` | screenshot-window | Hardware key — focused window → disk + clipboard |

### Hyper

The `Hyper` namespace is realized on metis via keyd (Caps Lock → `Super+Ctrl+Alt+Shift`; see [keyd.md](./keyd.md)). niri catches Hyper binds as `Mod+Ctrl+Alt+Shift+<key>` — niri's exact-modifier matching means a four-modifier chord never collides with the `Mod` / `Mod+Ctrl` / `Mod+Shift` binds above.

| Key | Action | Notes |
|---|---|---|
| `Hyper+Left` / `Hyper+Right` | focus-column-left / -right | Mirrors the mac's `Hyper+Left`/`Right` (move between Spaces). `Mod+Left`/`Right` (Navigation, above) retained. |
| `Hyper+1` … `Hyper+9` | focus-workspace 1–9 | Mirrors the mac's Switch-to-Desktop N. `Mod+1`–`9` (Workspaces, above) retained. |
| `Hyper+Up` | toggle-overview | Mirrors the mac's Mission Control. `Mod+O` (Discovery, above) retained. |
| `Hyper+Space` | Noctalia launcher (IPC) | The Spotlight-equivalent. `Mod+Space` (Spawn, above) retained. |
| `Hyper+Return` | spawn `foot` (terminal) | Mirrors the mac's `Hyper+Return` → Ghostty. `Mod+Return` (Spawn, above) retained. |
| `Hyper+B` | spawn default browser (`xdg-open https://`) | Opens the system default browser — currently Firefox per `xdg.mimeApps` (`home/nixos/firefox.nix`); follows the #127 audit outcome automatically. Spawn-only; focus-or-spawn out of scope. No `Super` original. |

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
| `Hyper+1` … `Hyper+9` | Switch to Mission Control Desktop 1..9 | Karabiner remap to `Ctrl+1` … `Ctrl+9` | macOS Mission Control's "Switch to Desktop N" (symbolichotkey IDs `118`–`121` for Desktops 1–4, `190`–`194` for 5–9 — the full `190`–`197` block extends up through Desktop 12 but this bind targets 1–9). **Declared enabled** via `modules/darwin/keyboard-shortcuts.nix`, folding in what macOS leaves disabled-by-default and would otherwise need a one-time manual System-Settings step (the repo's no-manual-state stance). Mirrors the niri-side `Mod+1` … `Mod+9` focus-workspace binds. |

### Screenshots

macOS's screenshot shortcuts are **swapped** from their factory defaults so *copy to clipboard* is the accessible bare-`⌘⇧` chord and *save to file* takes the `⌃⌘⇧` chord — the inverse of the macOS default (where `⌘⇧` saves a file and adding `Ctrl` copies to the clipboard). This matches the niri side, where the bare `Mod+Shift+N` chords are the clipboard captures. Realized declaratively via symbolic hotkeys in `modules/darwin/keyboard-shortcuts.nix` (IDs 28–31). Files save to `~/Pictures/Screenshots` (`screencapture.location` in `modules/darwin/system-prefs.nix`) — the fleet-wide location matching the niri side.

| Key | Action | Notes |
|---|---|---|
| `⌘⇧3` | Copy screen to clipboard | ID 29; swapped from its default (save-to-file) |
| `⌘⇧4` | Copy selected area to clipboard | ID 31; swapped from default |
| `⌃⌘⇧3` | Save screen to file | ID 28; swapped from default (clipboard) |
| `⌃⌘⇧4` | Save selected area to file | ID 30; swapped from default |
| `⌘⇧5` | Screenshot & recording options bar | ID 184; unchanged (no file/clipboard variant to swap) |

## Reserved keys

### `Super+letter` (application-command namespace)

Standard app-command shortcuts. Left unbound at the niri level so a
future keyd remap can pass them through to applications as
`Ctrl+letter`: `Mod+C`, `Mod+V`, `Mod+X`, `Mod+Z`, `Mod+A`, `Mod+S`,
`Mod+F`, `Mod+Q`, `Mod+T`, `Mod+N`, `Mod+R`.

`Mod+W` is currently bound to `close-window` as an interim deviation
(see Implementation status).

### `Hyper` namespace — now active (not reserved)

`Hyper` is no longer a reserved namespace: it is realized on both platforms and is the cross-platform layer (navigation + spawn + system). Its canonical binds live in [§Cross-platform Hyper mapping](#cross-platform-hyper-mapping); per-platform realization is in the Implementation-status table. Kept here only as a pointer so the reserved-keys list stays complete.

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
