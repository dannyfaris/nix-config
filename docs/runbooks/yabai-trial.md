# Runbook — yabai trial bootstrap and teardown (neptune)

> **Trial branch only** (`trial/yabai`). Not a fleet document. It exists because the branch is inert without the manual steps below and they are not derivable from the config. Delete it with the branch.

Scope: neptune, the fleet's only Mac since saturn was purged (#759). The swap is wired in `hosts/neptune/default.nix`, not in the shared `home/darwin/bundles/desktop-env.nix`, so the shared macOS desktop surface stays untouched and teardown is a clean branch checkout.

## Know this before you start

Two behaviours differ sharply from AeroSpace and are not obvious from the config.

**Two different space-switch mechanisms are in play, and they feel nothing alike.** With SIP enabled the scripting addition is unavailable, so `yabai -m space --focus` falls through to `space_manager_focus_space_using_gesture` (`space_manager.c:993-999`), which synthesizes `abs(target − current)` dock swipes at a hardcoded `9999` velocity (`:956`) — the stated intent being to *skip* the macOS slide. The result is an instant cut, not an animation. `Hyper+1‑9` therefore does **not** use it: those nine synthesize macOS's own "Switch to Desktop N" instead, keeping the slide (step 4). The gesture path still backs `Hyper+Tab` and the `Hyper+←/→` edge-scroll, so those still cut instantly — a deliberate inconsistency, not an oversight. Either way, a keypress landing mid-animation is rejected with `DISPLAY_IS_ANIMATING` and does nothing.

**Service mode captures every key.** `Hyper+Shift+Semicolon` enters it, and while there `::  service @` swallows all input — typing reaches no application. Only three keys respond: `escape` returns to default, `r` balances the tree, `f` toggles float. It looks exactly like a wedged session. If the machine stops responding to the keyboard, press Escape first.

## Before activating

1. **Create Mission Control Desktops up to 9** on the main display (Mission Control → hover the top strip → `+`). **One exists today**, so eight must be added — AeroSpace owns the workspace layer on a single native Space ([ADR-040](../decisions/ADR-040-macos-window-manager-aerospace.md)), which is the state this branch is entered from. The keymap addresses Spaces by mission-control index and, with SIP enabled, yabai *cannot* create them — `space --create` is scripting-addition-only. Until they exist, `Hyper+2‑9` and `Hyper+Shift+2‑9` are inert: **16 of the 41 binds, roughly 40% of the keymap**, failing into `~/Library/Logs/skhd.err.log` with nothing at the keyboard. Judging the trial on a keymap with that much of it dead is not a fair test.

   Count them — do not eyeball Mission Control, and do not count `uuid` keys in `com.apple.spaces` (that sweeps in `Collapsed Space` records for disconnected displays and overcounts). The live display's Spaces array is the only honest source:

   ```
   defaults read com.apple.spaces | awk '/"Display Identifier" = Main/,/\);/' | grep -c ManagedSpaceID
   ```
2. **Confirm "Displays have separate Spaces" is on** (System Settings → Desktop & Dock → Mission Control). yabai hard-requires it and *exits successfully* if it is off, so the failure is invisible to `launchctl list`.
3. **Confirm "Automatically rearrange Spaces" is off.** It reorders mission-control indices underneath the keymap.
4. **Verify "Switch to Desktop 1" through "Switch to Desktop 9" are enabled** (System Settings → Keyboard → Keyboard Shortcuts… → Mission Control, expand the collapsed *Mission Control* group). They bind `Ctrl+1‑9` and are **on by default** on macOS 26, so this is a check, not a change. Confirm from the shell instead if preferred — the absence of `118`-and-up entries under `AppleSymbolicHotKeys` means *at system default*, because only a deviation is ever written:

   ```
   defaults read com.apple.symbolichotkeys AppleSymbolicHotKeys | grep -E '^\s{4}[0-9]+ ='
   ```

   Order matters: a `Ctrl+N` does nothing when Desktop N does not exist, and System Settings lists only as many entries as there are Desktops — so step 1 has to come first, and testing these before it will mislead.

   `Hyper+1‑9` synthesizes these rather than calling `yabai -m space --focus`, because yabai's SIP-free path deliberately skips the macOS slide (`space_manager.c:956` posts dock swipes at a hardcoded 9999 velocity) and the slide is wanted. **They are therefore load-bearing**: switch them off and `Hyper+1‑9` goes *silently* dead — skhd fires a shortcut macOS no longer listens for, with nothing in any log. They are left **undeclared deliberately**. Being correct by default, the only thing a declaration would buy is a guard against someone disabling them; and hand-authoring the `com.apple.symbolichotkeys` structure (symbolic-hotkey ids plus `(charCode, keyCode, modifier)` triples, whose keycodes for 1‑9 are non-sequential) risks *breaking* a working default to defend against something that has not happened. The lightest mechanism that holds the guarantee is this paragraph ([ADR-032](../decisions/ADR-032-proportionate-enforcement-and-rationale.md)).

   The `Hyper+←/→` edge-scroll also leans on these: its wrap (Desktop 1 → last, and back) synthesizes a numbered Switch-to-Desktop, because macOS's Move-left/right-a-space does not wrap. Its plain step uses Move-a-space, which unlike the numbered shortcuts is **enabled by default** and needs no ticking. Consequence of the wrap being a numbered jump: go beyond **9** Desktops and the wrap silently no-ops while the step keeps working, since there is no "Switch to Desktop 10" shortcut bound.

   The trade accepted here: the native slide is longer than yabai's cut, and yabai rejects a switch arriving mid-animation (`DISPLAY_IS_ANIMATING`), so rapid switching drops more keypresses than the `space --focus` path did.
5. **Re-entering the branch after the first time only:** stop AeroSpace before switching.

   ```
   launchctl bootout gui/$(id -u)/org.nix-community.home.aerospace
   ```

   nix-darwin loads the yabai agent in its `launchd` activation phase, which runs *before* home-manager's `postActivation` removes AeroSpace. The first time round this is harmless because yabai has no Accessibility grant yet and exits immediately — but once the grant exists for that store path, yabai starts fully while AeroSpace is still running, and two tilers contend over the same windows for the length of activation. Nothing is destroyed; the resulting layout is just nondeterministic.

## After activating

6. **Grant Accessibility to both yabai and skhd** (System Settings → Privacy & Security → Accessibility). Both prompt on first launch. Until granted, neither tiles nor binds anything.

   Both agents are configured `KeepAlive.SuccessfulExit = false` precisely so a missing grant does *not* respawn-prompt in a loop, so after granting, start them by hand:

   ```
   launchctl kickstart -k gui/$(id -u)/org.nixos.yabai
   launchctl kickstart -k gui/$(id -u)/org.nix-community.home.skhd
   ```

7. **Verify they are actually alive.** `launchctl list` is not evidence — both binaries exit with status 0 when their preconditions fail, so a dead daemon reports healthy and the fleet's `launchd-failure-notifier` stays silent.

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

- **Delete the Desktops you added**, back to the single one that existed before the trial. Deleting a Desktop migrates its windows to the adjacent one, so there is no need to move anything by hand first. AeroSpace is built around a single native Space; left as-is it resumes owning a layout containing windows it cannot see.
- **Re-grant Accessibility to AeroSpace** if its own grant went stale.
- Stale yabai/skhd entries can be removed from the Accessibility list.
- **Quit SwiftBar and delete its preference.** Two pieces of it outlive a branch checkout. The launchd agent only `open`s the app, so unloading the agent does not quit the running process — it survives until you quit it or log out. And `targets.darwin.defaults` is a one-way `defaults write` in an activation script; home-manager tracks no state for user defaults and never reverts one, so `PluginDirectory` persists pointing at a directory that is about to be empty. The plugin symlink itself *is* home-manager-owned and goes on its own.

  ```
  osascript -e 'quit app "SwiftBar"'
  defaults delete com.ameba.SwiftBar
  rmdir ~/.local/share/swiftbar-plugins    # only if empty — the symlink is HM-removed
  ```

## Findings

Dated log of what the live trial established, kept here because it shares the branch's lifecycle. **No verdict yet** — this records evidence, not a decision. If the trial concludes GO, this graduates into the superseding ADR's §History, the way [ADR-040](../decisions/ADR-040-macos-window-manager-aerospace.md) §History preserved the `trial/aerospace` log.

### 2026-08-11 — activated on neptune, full keymap exercised

**The SIP-enabled claims that documentation alone could not settle are confirmed on macOS 26.5.2.** All three had been read out of the pinned 7.1.25 source rather than observed, which is precisely the gap [CLAUDE.md](../../CLAUDE.md) §Conventions calls out ("set ≠ enforced"):

- **`window --space N` moves windows** (`Hyper+Shift+1‑9`). This was the load-bearing uncertainty — 7.1.25's changelog claims the non-SA path was restored after a Sequoia-era regression, and the trial confirms it holds on Tahoe.
- **`space --focus N` works via the synthesized gesture path** and the animated switch was judged acceptable in day-to-day use. The runbook predicted the verdict would turn on this; it did not turn out to be the obstacle expected.
- **`window --toggle zoom-fullscreen` is a stable, reversible maximise**, which AeroSpace could not offer — its `fullscreen` drops on focus-change, forcing the one-way maximise-by-isolation hack and leaving [#491](https://github.com/dannyfaris/nix-config/issues/491) / [#492](https://github.com/dannyfaris/nix-config/issues/492) open.

**Service mode verified end to end.** Capture confirmed by the only test that actually proves it — keystrokes reach no application while in the mode. `r` (`space --balance`) and `f` (`window --toggle float`) both act, and both auto-return to `default` via their trailing `skhd -k escape`. That trailer is the most fragile mechanism in the config (skhd synthesizing a keypress into its own mode machinery) and was verified separately from the actions themselves.

### 2026-08-11 — corrections this trial forced on the runbook above

- **One Space existed pre-trial, not four.** Eight had to be created, not five. The original figure would have left the operator four Desktops short with a quarter of the keymap silently dead — the exact failure the step exists to prevent.
- **Counting `uuid` keys in `com.apple.spaces` is not a valid Space count.** It sweeps in `Collapsed Space` records for displays that are not connected. The Main monitor's `Spaces` array is the only honest source; the corrected probe is in step 1.
- **"Switch to Desktop N" is on by default, not off.** Step 4 briefly said otherwise, and the commit that introduced the native-shortcut binds ([`3b5d374`](https://github.com/dannyfaris/nix-config/commit/3b5d374)) argues from the same wrong premise — read its message with that in mind. The error came from probing the shortcuts while only **one** Desktop existed: `Ctrl+1` was already the current Desktop and Desktop 3 did not exist, so both were no-ops regardless of whether anything was bound. The control test that seemed to clear the mechanism (`ctrl + alt - 2` switching correctly) proved only that *synthesis* worked — that chord was caught by skhd, so it said nothing about macOS's own bindings. **A negative result from a probe run against absent state is not evidence.** Nine Desktops later the same probe passes with no plist entry present at all, which is what "at system default" looks like.

### 2026-08-11 — observations carried, not yet acted on

- **Service mode has no visual indicator.** AeroSpace surfaced the active mode in its menu-bar item; yabai + skhd surface nothing, and the mode captures the whole keyboard. This is the most likely future "the machine is wedged" moment and the sharpest usability regression found so far.
- **`yabai -m query --windows` lists phantom window records.** A hidden 1Password record (`has-ax-reference: false`, empty `title`/`role`, stale `frame`) reads at a glance as an untiled window overlapping the layout, and was briefly misdiagnosed as a missing float rule during this trial. **`has-ax-reference` is the discriminator, not `is-visible`** — the latter means only "on a Space that is not currently visible" and is false for every window on every other Space, so filtering on it discards most of the fleet of windows rather than the phantoms.
- **Multi-display is unexercised.** neptune is single-display, so the interaction between nine fixed Spaces and a display connect/disconnect is untested — and `space --create` being scripting-addition-only means yabai cannot repair a Space shortfall itself.
