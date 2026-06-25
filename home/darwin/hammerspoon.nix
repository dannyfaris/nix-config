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
# Hyper (Ctrl+Opt) is produced by Karabiner-Elements per
# home/darwin/karabiner.nix. Hammerspoon listens for the chord at
# the userspace event-tap layer and binds Lua actions to it.
#
# Every Hyper bind is generated from the single-source capability
# registry (lib/capabilities.nix — `hammerspoonBinds`, #440 / #455 /
# ADR-039): the registry emits the `hs.hotkey.bind` calls referencing
# handler *names*; the handler bodies — geometry and the cross-Space
# spawn helpers alike — are the hand-authored Lua library below.
# Routing the spawn binds (Hyper+Return/B) through the emitter too
# (rather than binding them by hand) means their chords are covered by
# the darwin collision lint (#455). Taxonomy: docs/desktop/keybinds.md;
# selection + behaviour: docs/desktop/macos-window-management.md.
{ lib, ... }:
let
  caps = import ../../lib/capabilities.nix { inherit lib; };
  initLua = ''
    -- ~/.hammerspoon/init.lua — managed by home/darwin/hammerspoon.nix.
    -- Hyper = Ctrl+Opt produced by Karabiner-Elements from caps_lock.

    -- Hide the menu-bar status item. The config is driven entirely by
    -- Hyper hotkeys, not the menu icon, so it's pure clutter. hs.menuIcon
    -- also persists the choice to Hammerspoon's prefs; re-applying it on
    -- every load (this file runs on each hs.reload) keeps the icon hidden
    -- even if that pref is flipped out-of-band. See
    -- docs/desktop/hammerspoon.md §Configuration.
    hs.menuIcon(false)

    -- Hyper = Ctrl+Opt (the macOS base-shape, ADR-039 §3/§4), produced from
    -- caps_lock by Karabiner. Every Hyper bind below is generated from the
    -- capability registry as hs.hotkey.bind({ "ctrl", "alt" }, …).

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
    -- Geometry handlers — stateless, act on the focused window. Bound by
    -- the registry-generated hs.hotkey.bind calls below (the handler
    -- *names* are referenced from lib/capabilities.nix; these are the
    -- bodies). See docs/desktop/macos-window-management.md for behaviour.
    -- ----------------------------------------------------------------

    -- Width step (fraction of screen width) for Hyper+−/=, and the preset
    -- cycle for Hyper+R. Presets are width fractions: ½ → ⅔ → full → ½.
    local WIDTH_STEP = 0.05
    local WIDTH_PRESETS = { 0.5, 2 / 3, 1.0 }
    local MIN_WIDTH_FRACTION = 0.2

    -- Clamp a frame's x so it stays within the screen's visible frame.
    local function clampX(f, sf)
      if f.x < sf.x then f.x = sf.x end
      if f.x + f.w > sf.x + sf.w then f.x = sf.x + sf.w - f.w end
      return f
    end

    -- Hyper+F: native fullscreen — the window moves to its own Space.
    local function fullscreenWindow()
      local win = hs.window.focusedWindow()
      if win then win:setFullScreen(not win:isFullScreen()) end
    end

    -- Hyper+M: maximize to the screen's visible frame (menu bar + Dock
    -- respected — hs.window:maximize() targets screen:frame(), not fullFrame).
    local function maximizeToFrame()
      local win = hs.window.focusedWindow()
      if win then win:maximize() end
    end

    -- Hyper+C: center the window on screen at its current size.
    local function centerWindow()
      local win = hs.window.focusedWindow()
      if win then win:centerOnScreen() end
    end

    -- Resize the focused window's width by `delta` (fraction of screen width),
    -- about its current center, keeping vertical extent; clamped to the screen.
    local function resizeWidthBy(delta)
      local win = hs.window.focusedWindow()
      if not win then return end
      local screen = win:screen()
      if not screen then return end
      local sf = screen:frame()
      local f = win:frame()
      local newW = math.max(sf.w * MIN_WIDTH_FRACTION, math.min(sf.w, f.w + delta * sf.w))
      f.x = (f.x + f.w / 2) - newW / 2
      f.w = newW
      win:setFrame(clampX(f, sf))
    end

    -- Hyper+−/=: shrink / grow the window's width by a fixed step.
    local function shrinkWindow() resizeWidthBy(-WIDTH_STEP) end
    local function growWindow()   resizeWidthBy(WIDTH_STEP) end

    -- Hyper+R: stateless preset-width snap — read the current width fraction
    -- and snap to the next preset (wrapping). Vertical extent is preserved;
    -- the next step is inferred from the frame, never stored.
    local function snapPresetWidth()
      local win = hs.window.focusedWindow()
      if not win then return end
      local screen = win:screen()
      if not screen then return end
      local sf = screen:frame()
      local f = win:frame()
      local frac = f.w / sf.w
      local target = WIDTH_PRESETS[1]
      for _, p in ipairs(WIDTH_PRESETS) do
        if p > frac + 0.02 then target = p; break end
      end
      -- Re-center about the current center (consistent with resizeWidthBy), so
      -- alternating Hyper+R and Hyper+± resizes in place rather than shuffling x.
      local cx = f.x + f.w / 2
      f.w = sf.w * target
      f.x = cx - f.w / 2
      win:setFrame(clampX(f, sf))
    end

    -- ----------------------------------------------------------------
    -- Bindings
    -- ----------------------------------------------------------------

    -- Every Hyper bind — geometry (Hyper+F/M/C/R/±) and spawn (Hyper+Return/B)
    -- alike — is generated from the single-source capability registry
    -- (lib/capabilities.nix, #440 / #455 / ADR-039). Each line is
    -- `hs.hotkey.bind({ "ctrl", "alt" }, "<key>", <handler>)`; the handler
    -- bodies (including the cross-Space spawn helpers) are the library above.
    ${caps.hammerspoonBinds}

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
