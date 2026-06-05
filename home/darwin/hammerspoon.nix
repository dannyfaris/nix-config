# Hammerspoon declarative init.lua on Darwin. The .app is installed
# via the Homebrew cask declared in modules/darwin/homebrew.nix
# (ADR-031 clause 1: pkgs.hammerspoon does not exist on Darwin).
# This file owns ~/.hammerspoon/init.lua.
#
# See docs/desktop/hammerspoon.md for selection rationale, the
# Accessibility TCC ceremony, the `.zip`-enclosure Sparkle silent
# path, and verification commands. The bind manifest lives in
# docs/desktop/keybinds.md §"Active bindings — macOS clients".
#
# Symlinked into the nix store and therefore read-only — edit this
# file to change the config; do not edit init.lua through the
# Hammerspoon console. Hammerspoon's hs.pathwatcher auto-reload
# fires on file change, but FSEvents may not surface every
# symlink-target swap at `nh darwin switch` — see docs/desktop/
# hammerspoon.md §Sharp edges for the manual `hs -c 'hs.reload()'`
# fallback.
#
# Hyper (⌘⌃⌥⇧) is produced by Karabiner-Elements per
# home/darwin/karabiner.nix. Hammerspoon listens for the chord at
# the userspace event-tap layer and binds Lua actions to it.
_:
let
  initLua = ''
    -- ~/.hammerspoon/init.lua — managed by home/darwin/hammerspoon.nix.
    -- Hyper = ⌘⌃⌥⇧ produced by Karabiner-Elements from caps_lock.

    -- Hide the menu-bar status item. The config is driven entirely by
    -- Hyper hotkeys, not the menu icon, so it's pure clutter. hs.menuIcon
    -- also persists the choice to Hammerspoon's prefs; re-applying it on
    -- every load (this file runs on each hs.reload) keeps the icon hidden
    -- even if that pref is flipped out-of-band. See
    -- docs/desktop/hammerspoon.md §Configuration.
    hs.menuIcon(false)

    local hyper = { "cmd", "ctrl", "alt", "shift" }

    -- Apps are identified by both bundle ID and macOS display name.
    -- The two layers exist because Hammerspoon uses them asymmetrically:
    --
    --   * Bundle ID — passed to hs.application.get and
    --     hs.application.launchOrFocusByBundleID. Robust against
    --     display-name drift (Chrome Beta/Canary etc.).
    --   * Display name — required by hs.window.filter:setAppFilter,
    --     which keys per-app filters off hs.application:name()
    --     (verified against window_filter.lua line ~530). Passing a
    --     bundle ID to setAppFilter silently registers a filter that
    --     never matches. hs.application:name() returns the *localized*
    --     name on non-English macOS locales — see docs/desktop/
    --     hammerspoon.md §Sharp edges "Display-name app identification
    --     is locale-sensitive" for the failure mode and the bundle-ID
    --     predicate workaround.
    --
    -- Both layers are kept here so every helper has the identifier it
    -- needs without re-derivation.
    local GHOSTTY = { bundleId = "com.mitchellh.ghostty", name = "Ghostty" }
    local CHROME  = { bundleId = "com.google.Chrome",    name = "Google Chrome" }

    -- Generous spawn timeout: Chrome cold-start with extensions +
    -- session restore can take several seconds.
    local SPAWN_TIMEOUT = 10

    -- Refocus delay after native-fullscreen. macOS's AXFullScreen
    -- Space-entry animation on a fresh window runs ~0.5-1.2s on
    -- Apple Silicon. 1.2s is the defensible upper bound; the
    -- operator-perceived cost is "~100ms slow if already done",
    -- acceptable for a hotkey that fires manually.
    local REFOCUS_DELAY = 1.2

    -- ----------------------------------------------------------------
    -- Helpers
    -- ----------------------------------------------------------------

    -- Bring a specific window to the foreground. The explicit
    -- app:activate(false) pulls the owning app forward without
    -- raising sibling windows the operator didn't ask for. focus()
    -- internally calls becomeMain() so no explicit becomeMain step
    -- is needed.
    local function focusWindow(win)
      if not win or not win:isStandard() then return end
      if win:isMinimized() then win:unminimize() end
      win:focus()
      local app = win:application()
      if app then app:activate(false) end
    end

    -- Native-fullscreen a window, then re-focus once the animation
    -- settles. setFullScreen is asynchronous: the window animates
    -- onto its own Space, and focus can drift during the animation.
    local function fullscreenAndFocus(win)
      if not win then return end
      focusWindow(win)
      win:setFullScreen(true)
      hs.timer.doAfter(REFOCUS_DELAY, function()
        focusWindow(win)
      end)
    end

    -- Subscribe to the next window-created event for the named app,
    -- run fn(win) once. Subscribe BEFORE triggering the spawn so the
    -- event cannot be missed. A timeout tears the subscription
    -- down and alerts the operator if no window appeared.
    --
    -- appName is the macOS display name (hs.application:name()),
    -- NOT the bundle ID — see the GHOSTTY / CHROME comment above.
    local function onNextWindow(appName, fn)
      local wf = hs.window.filter.new(false)
        :setAppFilter(appName, { allowRoles = "AXStandardWindow" })

      local fired = false
      wf:subscribe(hs.window.filter.windowCreated, function(win)
        if fired then return end
        fired = true
        wf:unsubscribe(hs.window.filter.windowCreated)
        fn(win)
      end)

      hs.timer.doAfter(SPAWN_TIMEOUT, function()
        if not fired then
          wf:unsubscribe(hs.window.filter.windowCreated)
          hs.alert.show("Spawn timed out: " .. appName, 2)
        end
      end)
    end

    -- Find the most-recently-focused existing window of an app,
    -- across all Mission Control Spaces. Returns nil if no window
    -- exists. Uses hs.window.filter rather than app:allWindows()
    -- because app:allWindows() is current-Space-only.
    --
    -- currentSpace = nil (no constraint) admits cross-Space windows;
    -- sortByFocusedLast orders by Hammerspoon's own focus-history
    -- bookkeeping (more reliable than app:focusedWindow(), which is
    -- undefined when the target app is not frontmost).
    local function bestExistingWindow(appName)
      local wf = hs.window.filter.new(false)
        :setAppFilter(appName, {
          allowRoles = "AXStandardWindow",
          currentSpace = nil,
        })
      local wins = wf:getWindows(hs.window.filter.sortByFocusedLast)
      if wins and #wins > 0 then return wins[1] end
      return nil
    end

    -- Spawn a new window for the app identified by bundleId, then
    -- hand the new window to fn. Cmd+N is the default "new window"
    -- shortcut in both Ghostty and Chrome. The 200000 µs inter-press
    -- delay is Hammerspoon's documented default for keyStroke — gives
    -- the target app's run loop time to register the modifier
    -- between key-down and key-up.
    local function spawnWindow(app, fn)
      onNextWindow(app.name, fn)
      local hsApp = hs.application.get(app.bundleId)
      if hsApp then
        hsApp:activate(false)
        hs.timer.doAfter(0.05, function()
          hs.eventtap.keyStroke({ "cmd" }, "n", 200000, hsApp)
        end)
      else
        hs.application.launchOrFocusByBundleID(app.bundleId)
      end
    end

    -- ----------------------------------------------------------------
    -- Actions
    -- ----------------------------------------------------------------

    -- Hyper + Return: always spawn a new fullscreen Ghostty window.
    local function ghosttyNewWindow()
      spawnWindow(GHOSTTY, fullscreenAndFocus)
    end

    -- Hyper + B: focus the most-recently-used Chrome window if one
    -- exists (unminimizing and Space-switching as needed); otherwise
    -- spawn a new fullscreen Chrome window.
    local function chromeFocusOrNew()
      local existing = bestExistingWindow(CHROME.name)
      if existing then
        focusWindow(existing)
      else
        spawnWindow(CHROME, fullscreenAndFocus)
      end
    end

    -- ----------------------------------------------------------------
    -- Bindings
    -- ----------------------------------------------------------------
    hs.hotkey.bind(hyper, "return", ghosttyNewWindow)
    hs.hotkey.bind(hyper, "b",      chromeFocusOrNew)

    -- ----------------------------------------------------------------
    -- Auto-reload: re-evaluate this file on any .lua change in
    -- ~/.hammerspoon/. Picks up direct edits (e.g. via the
    -- Hammerspoon console for ephemeral experimentation).
    -- FSEvents may not surface every symlink-target swap from
    -- `nh darwin switch`; the documented fallback is
    -- `hs -c 'hs.reload()'` (see docs/desktop/hammerspoon.md).
    -- ----------------------------------------------------------------
    hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", function(files)
      for _, f in ipairs(files) do
        if f:sub(-4) == ".lua" then hs.reload(); return end
      end
    end):start()

    hs.alert.show("Hammerspoon config loaded")
  '';
in
{
  home.file.".hammerspoon/init.lua".text = initLua;
}
