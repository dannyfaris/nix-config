# Hammerspoon

> **Decommissioned 2026-07-02** ([ADR-040](../decisions/ADR-040-macos-window-manager-aerospace.md), #494). Retired from the macOS interaction stack — **AeroSpace** now owns window management and every Hyper bind (via the `aerospace-action` registry emitter), and the terminal/browser spawns moved to `exec-and-forget open`. The Homebrew cask, `~/.hammerspoon/init.lua` (`home/darwin/hammerspoon.nix`), and the `hammerspoon-handler` realization were all removed; the stack is now Karabiner (Hyper substrate) + AeroSpace only. This document is retained as the selection record for the Hammerspoon era. See [macos-window-management.md](./macos-window-management.md) and the design note [macos-deterministic-tiling.md](../design/macos-deterministic-tiling.md).

Desktop automation app for macOS — Lua runtime with bindings into
macOS's Accessibility, window-management, and event-tap APIs. Picked
as the **macOS hotkey-binding layer** that lives on top of the Hyper
modifier produced by Karabiner-Elements (see
[karabiner.md](./karabiner.md) and
[keybinds.md](./keybinds.md)). Karabiner produces the chord;
Hammerspoon binds Lua actions to it.

## Selection

Darwin: Homebrew cask `hammerspoon`, declared in
`modules/darwin/homebrew.nix` per
[ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
**clause 1** (no `pkgs.hammerspoon` on `aarch64-darwin` —
verified by `nix eval nixpkgs#hammerspoon.version` returning
`does not provide attribute`). Same shape as Ghostty: clause 1,
no-nixpkgs-Darwin, one-line carve-out.

Declarative config at `~/.hammerspoon/init.lua` managed by
`home/darwin/hammerspoon.nix`.

Update stance: **Sparkle silent**. Hammerspoon's appcast ships
`.zip`-enclosure updates (no `sparkle:installationType="package"`
attribute) — the silent path applies, same shape as Ghostty.
`SUEnableAutomaticChecks` + `SUAutomaticallyUpdate` keys wired in
`modules/darwin/homebrew.nix` under bundle ID
`org.hammerspoon.Hammerspoon`.

## Rationale

**Not on MAS.** Hammerspoon's MAS distribution would be sandboxed,
which structurally cannot drive the Accessibility-API window
manipulation and global event taps it exists to do. Upstream
distributes only via direct `.zip` download from GitHub releases.
Rejected at ADR-031 Step 0; clause 3 cannot apply.

**Not in nixpkgs Darwin.** `nix eval nixpkgs#hammerspoon` returns
no attribute on `aarch64-darwin` (and on `x86_64-darwin`).
nixpkgs has no Darwin packaging for Hammerspoon at write-time.
**Clause 1 fires** — no degradation analysis needed (clause 2 is
moot; clause 3 is rejected). The cask is the only declarative
path.

**Why Hammerspoon over the alternatives.** The selection question
is not "cask vs nixpkgs" (clause 1 settles it) but "which macOS
hotkey-binding tool?" Hammerspoon was chosen for:

- **Lua scripting surface.** Bindings are declarative Lua functions
  with full access to macOS APIs (windows, apps, fullscreen,
  Spaces, eventtaps). Karabiner's complex_modifications can
  remap keys but can't run Lua logic like "focus existing Chrome
  window or spawn new one" — that needs a scripting layer.
- **Stays out of the modifier-production layer.** Karabiner owns
  caps_lock → Hyper at the DriverKit layer; Hammerspoon listens
  for the resulting modifier chord at the userspace event-tap
  layer. Clean separation per the
  [keybinds.md](./keybinds.md) philosophy.
- **Auto-reload of config file.** `hs.pathwatcher` re-evaluates
  `init.lua` on file change — including when `nh darwin switch`
  swaps the read-only symlink target. Free hot-reload across
  activations.

## Alternatives considered

**MAS** — sandboxed; structurally cannot do the work. Rejected at
ADR-031 Step 0.

**`pkgs.hammerspoon`** — does not exist on Darwin in nixpkgs.
Clause 1 fires.

**Karabiner's complex_modifications alone** — can't execute Lua
logic like "find an existing Chrome window or spawn a new one,
fullscreen it." Karabiner is the modifier-production layer, not
the action layer.

**`skhd` (CLI hotkey daemon)** — a popular alternative; binds
hotkeys to shell commands rather than Lua. Less expressive for
window-management actions (would have to shell out to
`yabai`/`osascript` for window manipulation), and `skhd` plus
`yabai` together is a bigger surface than Hammerspoon alone.
Acceptable; not chosen because Hammerspoon's single-process Lua
runtime is simpler.

**`yabai` (tiling window manager)** — a different problem domain
(tiling WM with hotkeys as a side effect, not a hotkey daemon).
Out of scope; macOS native fullscreen + Hammerspoon binds is the
chosen stack.

**Raycast / Alfred extensions** — these are launchers with hotkey
support, not general hotkey daemons. Different ergonomics; not
chosen.

## Configuration

**Cask declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.casks = [ "hammerspoon" ];

system.defaults.CustomUserPreferences = {
  "org.hammerspoon.Hammerspoon" = {
    SUEnableAutomaticChecks = true;
    SUAutomaticallyUpdate = true;
  };
};
```

Bundle ID `org.hammerspoon.Hammerspoon` confirmed against the
upstream cask's `uninstall quit:` clause and `zap` trash list.

**Declarative `init.lua`** — `home/darwin/hammerspoon.nix` writes
`~/.hammerspoon/init.lua` via `home.file.<path>.text` with the Lua
source as a Nix multi-line string. Symlinked into the nix store
(read-only) — edit the Nix file to change, not the .lua file
directly. Hammerspoon's `hs.pathwatcher` auto-reload fires on
direct edits inside `~/.hammerspoon/`; for `nh darwin switch`
symlink-target swaps the watcher *usually* fires, but FSEvents
on home-manager's atomic-replace activation is not robust enough
to promise. See §Sharp edges "Auto-reload may not catch
activations" for the manual `hs -c 'hs.reload()'` fallback.

The `init.lua` calls `hs.menuIcon(false)` to hide the menu-bar status item — the config is driven entirely by Hyper hotkeys, not the menu icon. `hs.menuIcon` also persists the choice to Hammerspoon's prefs; re-running it on every load (each `hs.reload`) keeps the icon hidden even if that pref is flipped out-of-band.

The shipped binds today live in
[`keybinds.md`](./keybinds.md) §"Active bindings — macOS clients";
this doc owns the *selection* of Hammerspoon; the bind manifest
owns the *enumeration of binds*. See that doc for `Hyper+Return`
and `Hyper+B` semantics.

## Update behaviour

**Default (this config):** Sparkle runs on its vendor cadence,
silently replaces `/Applications/Hammerspoon.app`. No operator
action required. Same shape as Ghostty.

Verify the keys took effect after first activation:

```bash
defaults read org.hammerspoon.Hammerspoon SUEnableAutomaticChecks   # → 1
defaults read org.hammerspoon.Hammerspoon SUAutomaticallyUpdate     # → 1
```

(Run as `system.primaryUser`, or prefix with
`sudo --user=<primary-user>` from a different account.)

**Fallback if Mosyle prompts on every Sparkle install:** flip both
keys to `false`, then update manually via
`brew update && brew upgrade --cask --greedy hammerspoon`.
`--greedy` required because the cask declares `auto_updates true`
— with Sparkle disabled, brew is the only path. Same shape as
the Tailscale/Ghostty fallbacks.

## Sharp edges

**Accessibility TCC prompt on first launch.** Hammerspoon needs
the macOS Accessibility permission to capture global hotkeys and
manipulate windows. First launch surfaces a TCC prompt at System
Settings → Privacy & Security → Accessibility → enable
`Hammerspoon`. One-time per Mac; the cask doesn't auto-grant, and
there's no nix-darwin-declarative path. Without this, hotkey
binds fire but window manipulation silently fails.

**Auto-reload requires the cask installed first.** `hs.pathwatcher`
is part of the running Hammerspoon process — until Hammerspoon
is launched once and granted Accessibility, the symlinked
`init.lua` has no effect. First-time activation: install the
cask via `nh darwin switch`, launch Hammerspoon from
Spotlight/Launchpad, grant Accessibility, then the auto-reload is
in effect for future direct edits.

**Auto-reload may not catch activations.** `hs.pathwatcher` is
FSEvents-backed. `nh darwin switch` activates home-manager files
by atomic-replacing symlinks, which may not surface to FSEvents
in every case (depends on whether the file or its parent
directory is the target of the rename). Empirically the
watcher usually fires; when it doesn't, the `init.lua` symlink
has been updated but the running Hammerspoon Lua state is
stale. The fallback is `hs -c 'hs.reload()'` (the cask's `hs`
CLI shim is on PATH and the config loads `hs.ipc` to open the
port it talks to — see §"hs CLI" below; quitting from the menu
bar is not an option because this config hides the menu-bar icon
— see §Configuration). A more robust path would be a
post-activation hook that always invokes `hs -c 'hs.reload()'`;
not in scope today.

**UI edits do not survive activation.** Same posture as Karabiner
and Ghostty: `home.file` symlinks `init.lua` from the nix store
(read-only). Hammerspoon's Preferences pane writes to
`~/Library/Preferences/org.hammerspoon.Hammerspoon.plist`, not to
`init.lua`, so the symlink is safer than Karabiner's — but if a
contributor edits `init.lua` directly through the Hammerspoon
console (Cmd+Shift+`), the write will fail. **Edit
`home/darwin/hammerspoon.nix` to change Lua source; the console
is for ephemeral experimentation, not persistent config.**

**`hs` CLI shim is wired by the cask; the port is opened by the
config.** Hammerspoon ships a tiny CLI at
`/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs` that
the cask's `binary` stanza puts on PATH (`/opt/homebrew/bin/hs`).
The shim is only half of it: it talks to a Mach message port that
exists only when the running instance has loaded `hs.ipc`. The
`init.lua` therefore calls `require("hs.ipc")` (a bare `require`
opens the port; the cask already provides the binary, so no
`hs.ipc.cliInstall()`). With both halves present, `hs -c
"hs.reload()"` (the reload fallback above) and on-box Lua spikes
(`hs -c "hs.inspect(hs.spaces.allSpaces())"`, e.g. the #453
`hs.spaces` reliability check) work.

**Posture.** The IPC port lets any *same-user, local* process
eval arbitrary Lua inside Hammerspoon, which holds Accessibility
(full input/window control) — a deliberately-accepted local
attack-surface widening for this single-operator box. It is
local-only (no network surface). Revisit if neptune ever becomes
multi-user.

**macOS Ventura floor.** Cask `depends_on macos: :ventura`. Not a
constraint for neptune.

**Multi-monitor + native fullscreen.** macOS native fullscreen on
multi-monitor setups depends on System Settings → Desktop &
Stage Manager → "Displays have separate Spaces":

- **On (default since Mavericks):** `Hyper+Return` /
  `Hyper+B`'s fullscreened window lives on a new Space on the
  *window's current display*; other displays remain usable
  with their own Spaces.
- **Off:** the fullscreened window creates a Space spanning
  all displays; other displays show the linen-pattern
  wallpaper while the fullscreen lasts.

neptune today is single-display so this is theoretical; the
doc records it because the binds are evergreen and will travel
to multi-monitor Macs.

**Display-name app identification is locale-sensitive.**
`hs.window.filter:setAppFilter` keys per-app filters off
`hs.application:name()`, which returns the *localized* display
name on non-English macOS locales. Today's binds
(`GHOSTTY.name = "Ghostty"`, `CHROME.name = "Google Chrome"`)
work because (a) neptune's locale is English and (b) neither
vendor localizes its app name. Adding a localizing app
(Microsoft Word, Outlook, Pages) on a non-English Mac would
silently break its filter — the filter registers but never
matches, and the bind appears dead. If/when this becomes
relevant, switch the affected app's filter to bundle-ID
matching via `hs.window.filter.new(function(win) return
win:application():bundleID() == BUNDLE_ID end)` instead of
`setAppFilter`. Theoretical on neptune today; flagged because
the binds are evergreen.

**Hammerspoon must be running for binds to fire.** Stating the
obvious: if Hammerspoon is quit (Cmd+Q from the menubar), no
binds fire. The cask doesn't configure launch-at-login; this is
left as a one-time operator step (Hammerspoon's Preferences →
General → "Launch Hammerspoon at login"). Declarative
configuration of launch-at-login is *not* via `init.lua` — it's
a plist key Hammerspoon writes to its own preferences. Not in
scope; flagged as a one-time operator step.

**No declarative Spoon management.** Hammerspoon's plugin system
("Spoons") loads from `~/.hammerspoon/Spoons/<Name>.spoon/`.
Today's `init.lua` uses none; future bind growth may bring
Spoons in. When that happens, the Spoon source either lands as
additional `home.file` entries under `~/.hammerspoon/Spoons/`
or as a sibling Nix module that fetches+installs Spoons. Not in
scope.

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) —
  boundary rule placing Hammerspoon on the Mac via cask under
  clause 1.
- [`docs/desktop/karabiner.md`](./karabiner.md) — the
  modifier-production layer Hammerspoon binds on top of.
- [`docs/desktop/keybinds.md`](./keybinds.md) — the bind
  manifest; macOS bindings landed under §"Active bindings —
  macOS clients".
- Homebrew `hammerspoon` cask source (`.zip` enclosure, `auto_updates true`,
  Sparkle livecheck against `appcast.xml`) —
  https://github.com/Homebrew/homebrew-cask/blob/master/Casks/h/hammerspoon.rb
- Hammerspoon project — https://www.hammerspoon.org/
- Hammerspoon API reference — https://www.hammerspoon.org/docs/
