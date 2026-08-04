# Runbook — yabai trial bootstrap and teardown (neptune)

> **Trial branch only** (`trial/yabai`). Not a fleet document. It exists because the branch is inert without the manual steps below and they are not derivable from the config. Delete it with the branch.

Scope: neptune. saturn stays on AeroSpace throughout — the swap is wired in `hosts/neptune/default.nix`, not in the shared `home/darwin/bundles/desktop-env.nix`.

## Know this before you start

Two behaviours differ sharply from AeroSpace and are not obvious from the config.

**Space switching is a synthesized gesture, not an instant jump.** With SIP enabled the scripting addition is unavailable, so `space --focus` falls through to `space_manager_focus_space_using_gesture` (`space_manager.c:993-999`), which synthesizes `abs(target − current)` high-velocity swipes. Desktop 1 → 9 fires eight of them. Every switch animates where AeroSpace's was instant, and a keypress landing mid-animation is rejected with `DISPLAY_IS_ANIMATING` and does nothing. This is the single biggest experiential change and probably what the trial verdict turns on.

**Service mode captures every key.** `Hyper+Shift+Semicolon` enters it, and while there `::  service @` swallows all input — typing reaches no application. Only three keys respond: `escape` returns to default, `r` balances the tree, `f` toggles float. It looks exactly like a wedged session. If the machine stops responding to the keyboard, press Escape first.

## Before activating

1. **Create Mission Control Desktops up to 9** on the main display (Mission Control → hover the top strip → `+`). Four exist today. The keymap addresses Spaces by mission-control index and, with SIP enabled, yabai *cannot* create them — `space --create` is scripting-addition-only. Until they exist, `Hyper+5‑9` and `Hyper+Shift+5‑9` are inert: **10 of the 41 binds, roughly a quarter of the keymap**, failing into `~/Library/Logs/skhd.err.log` with nothing at the keyboard. Judging the trial on a keymap with a quarter of it dead is not a fair test.
2. **Confirm "Displays have separate Spaces" is on** (System Settings → Desktop & Dock → Mission Control). yabai hard-requires it and *exits successfully* if it is off, so the failure is invisible to `launchctl list`.
3. **Confirm "Automatically rearrange Spaces" is off.** It reorders mission-control indices underneath the keymap.
4. **Re-entering the branch after the first time only:** stop AeroSpace before switching.

   ```
   launchctl bootout gui/$(id -u)/org.nix-community.home.aerospace
   ```

   nix-darwin loads the yabai agent in its `launchd` activation phase, which runs *before* home-manager's `postActivation` removes AeroSpace. The first time round this is harmless because yabai has no Accessibility grant yet and exits immediately — but once the grant exists for that store path, yabai starts fully while AeroSpace is still running, and two tilers contend over the same windows for the length of activation. Nothing is destroyed; the resulting layout is just nondeterministic.

## After activating

5. **Grant Accessibility to both yabai and skhd** (System Settings → Privacy & Security → Accessibility). Both prompt on first launch. Until granted, neither tiles nor binds anything.

   Both agents are configured `KeepAlive.SuccessfulExit = false` precisely so a missing grant does *not* respawn-prompt in a loop, so after granting, start them by hand:

   ```
   launchctl kickstart -k gui/$(id -u)/org.nixos.yabai
   launchctl kickstart -k gui/$(id -u)/org.nix-community.home.skhd
   ```

6. **Verify they are actually alive.** `launchctl list` is not evidence — both binaries exit with status 0 when their preconditions fail, so a dead daemon reports healthy and the fleet's `launchd-failure-notifier` stays silent.

   ```
   pgrep -xl yabai skhd            # both must appear
   yabai -m query --displays       # must return JSON
   tail ~/Library/Logs/yabai.err.log ~/Library/Logs/skhd.err.log
   ```

   The grant is keyed to the store path (both are ad-hoc signed with no Team Identifier), so **it is lost on every version bump** — after any `nix flake update` that moves either package, re-grant and kickstart again.

   Note that when yabai first starts with `layout bsp`, every window already open is enrolled and retiled. Nothing is lost, but positions are not restored on teardown.

## If activation fails partway

If home-manager's activation dies between removing AeroSpace and starting skhd, there is no window manager and no hotkeys. This is recoverable and nothing is lost: the mouse, Dock, Spotlight and Mission Control all still work. Roll back with `cd ~/nix-config && git checkout main && nh darwin switch`, or use neptune's break-glass (local keyboard and display at the login screen) if the shell is unreachable.

## Teardown

```
cd ~/nix-config && git checkout main && nh darwin switch
```

That restores the config but **not** the desktop state. Also:

- **Delete the Desktops you added**, back to the four that existed before the trial. Deleting a Desktop migrates its windows to the adjacent one, so there is no need to move anything by hand first. AeroSpace is built around a single native Space; left as-is it resumes owning a layout containing windows it cannot see.
- **Re-grant Accessibility to AeroSpace** if its own grant went stale.
- Stale yabai/skhd entries can be removed from the Accessibility list.
