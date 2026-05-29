# Keybindings

Keybindings for the niri-only desktop on metis. Living document — updated
with every new binding.

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
  conventionally bound to Caps Lock via `keyd` or equivalent. **Not
  currently implemented.** Hyper-targeted commands either don't exist
  yet (their underlying tools aren't installed) or live on interim
  Super-side bindings until Hyper materialises.

- **`Super+Hyper`** — reserved for extended window management
  (fullscreen, maximize-column, similar). Same dependency as Hyper.

The framework is a way of thinking, not a roadmap. The unrealised layers
(`keyd` translation, `Hyper`) may never be implemented. The shape of
the bind composition below is nonetheless informed by the philosophy —
reserved namespaces are deliberately left unbound — so that if any of
the layers eventually land, migration is mechanical rather than
disruptive.

Cross-platform portability is an aspiration the philosophy enables but
does not require: the same bindings could in principle work on macOS
(via Karabiner-Elements for Hyper, native Cmd for app commands) but no
such macOS implementation is planned.

## Implementation status

| Namespace | State | Notes |
|---|---|---|
| `Super` (window management) | Active | This document enumerates the bindings. |
| `Super+letter` (app commands) | Reserved | Standard combos deliberately unbound. |
| `Hyper` (personal system) | Reserved | Awaits keyd-equivalent if ever pursued. |
| `Super+Hyper` (extended WM) | Reserved | Same dependency as Hyper. |

**Interim deviations** — knowingly accepted; would migrate if the
philosophy lands:

- `Mod+W` → `close-window`. Conflicts with the hypothetical
  `Super+W` → `Ctrl+W` (close tab) translation. Pragmatic choice for
  daily use; philosophical target is `Super+Hyper+W`.
- `Mod+Space` → application launcher (when fuzzel lands per #73).
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

### Session

| Key | Action | Notes |
|---|---|---|
| `Mod+Shift+E` | quit niri | Confirmation dialog shown; not an instant kill |

### Discovery

| Key | Action | Notes |
|---|---|---|
| `Mod+O` | toggle-overview | Birds-eye workspace view |
| `Mod+Shift+/` (i.e. `Mod+?`) | show-hotkey-overlay | Live cheat sheet for currently-bound keys |

## Reserved keys

### `Super+letter` (application-command namespace)

Standard app-command shortcuts. Left unbound at the niri level so a
future keyd remap can pass them through to applications as
`Ctrl+letter`: `Mod+C`, `Mod+V`, `Mod+X`, `Mod+Z`, `Mod+A`, `Mod+S`,
`Mod+F`, `Mod+Q`, `Mod+T`, `Mod+N`, `Mod+R`.

`Mod+W` is currently bound to `close-window` as an interim deviation
(see Implementation status).

### `Hyper` namespace (personal system commands)

`Hyper` (Caps Lock as modifier, hypothetical) is the philosophical
home for launcher, clipboard manager, notification panel, screenshot,
lock screen, and similar personal system commands. Currently
unrealised. Any future bindings here are added to this document when
implemented.

`Mod+Space` is reserved as the interim home for an application
launcher (#73). Philosophical target is `Hyper+Space`.

### `Super+Hyper` (extended WM)

Less-common window-management actions (fullscreen, maximize-column,
and `close-window` if `Mod+W` ever migrates). Currently unrealised.

### Hardware media keys

`Print`, `Ctrl+Print`, `Alt+Print` (screenshot), `XF86Audio*` (volume),
`XF86MonBrightness*` (brightness): left unbound until the corresponding
tooling is installed. These will likely land in the `Hyper` namespace
(via niri spawn binds to `wpctl`, `brightnessctl`, `grim`+`slurp`,
etc.) when those tools arrive.

## Cadence

This is a living document. Conventions for evolution:

- **One bind per learning ceremony.** New bindings land one at a time
  via deliberate addition (issue + PR + doc update) rather than bulk
  refresh. Muscle memory gets space to absorb each.
- **Doc precedes implementation.** Each new bind lands first as a
  table row here; the implementing commit follows in the same PR.
- **No silent additions.** If a binding appears in
  `home/core/nixos/niri.nix` that is not in this document, that is a
  bug in cadence — fix the doc.

## See also

- `home/core/nixos/niri.nix` — the implementation surface.
- `docs/desktop/niri.md` (to be established under #71) — niri compositor
  selection rationale.
- #69 — the foundational close-out under which this document was
  created.
