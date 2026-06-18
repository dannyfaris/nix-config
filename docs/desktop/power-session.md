# Power and session controls

> **Mooted 2026-06-18** ([ADR-036](../decisions/ADR-036-noctalia-shell-linux-desktop.md), #385). This was an unbuilt #98 proposal — a `fuzzel`-dmenu power menu built on swayidle's `lock`/`before-sleep` events. Both dependencies (fuzzel, swayidle) were decommissioned in #385, and Noctalia provides lock/logout/suspend/reboot/shut-down natively (its session menu + lock-screen session buttons). So this proposal is superseded before implementation; retained as history. (Note the externally-initiated-suspend lock gap recorded in [noctalia.md](./noctalia.md) §Sharp edges.)

Deliberate power- and session-state controls for the niri desktop on metis (#98) — a discoverable way to **lock, log out, suspend, reboot, and shut down** without dropping to a TTY or memorising `systemctl` invocations. This is the *attended* counterpart to the unattended idle/lock automation in [screen-lock.md](./screen-lock.md) (#97); that doc explicitly deferred "a 'lock now' keybind, suspend/reboot/logout controls" to here.

## Selection

A **`fuzzel --dmenu` power menu** — a small shell script that presents a labelled action list to fuzzel in dmenu mode and dispatches the chosen entry to `loginctl` / `systemctl` / `niri msg`. Triggered two ways onto the **same script**: a niri keybind (**`Hyper+Escape`** — a proper `Hyper`-namespace bind now that keyd realizes the modifier on metis, [keyd.md](./keyd.md), #282) and a **waybar `custom/power` button** (`on-click`) for the mouse. No new package: fuzzel (#73) is already the launcher, waybar (#75) is already the bar, and the action verbs are stock systemd / logind / niri-IPC.

The menu entries and what each runs:

| Entry | Command | Notes |
|---|---|---|
| Lock | `loginctl lock-session` | Fires swayidle's `lock` event → swaylock (the #97 integration). This is the deliberate "lock now" control #97 deferred here. |
| Log out | `niri msg action quit` | niri shows its built-in quit-confirm dialog (this *is* the logout confirmation); on confirm the niri session ends → greetd/regreet login screen. |
| Suspend | `systemctl suspend` | swayidle's `before-sleep` locks first, so resume always lands on the lock screen (#97). |
| Reboot | `systemctl reboot` | Destructive — second-stage confirm (see Configuration). |
| Shut down | `systemctl poweroff` | Destructive — second-stage confirm. |

fuzzel is already a Stylix target (`stylix.targets.fuzzel.enable`, full base16 palette), so the menu inherits the host theme automatically — no per-tool theming to hand-wire.

## Rationale

**Reuse the launcher we already chose; add no new tool.** fuzzel is installed and is *the* launcher (#73); `--dmenu` is a built-in mode that reads choices on stdin. The action verbs — `loginctl`, `systemctl`, `niri msg` — are all stock on a logind + niri session. So the whole capability is one small script plus one bind, with nothing new in the closure. That is the whitelist-minimalism / "a tool earns its place" posture the rest of the chrome follows (foot, fuzzel, fnott; #72–#74).

**Stylix themes it for free — the same argument that picked swaylock over gtklock.** Because fuzzel has a Stylix target in our pin, the power menu renders in the host palette with zero hand-wiring. wlogout — the obvious purpose-built alternative — has **no Stylix target in our pin** (verified), so adopting it would mean hand-wiring CSS colours from the palette. That is exactly the manual coupling [screen-lock.md](./screen-lock.md) cited for passing over gtklock in #97; the same reasoning lands the same way here.

**One discoverable surface, reachable two ways — and it fits the keybind cadence.** [keybinds.md](./keybinds.md) holds a hard cadence: *one bind per learning ceremony*, *no silent additions*. A single menu exposes all five actions without scattering five raw chords across the keymap (and without binding `systemctl poweroff` to a fat-fingerable key with no confirmation). It's reachable by keyboard (`Hyper+Escape`) and by the waybar button — both spawning the *same* script, so there's one menu definition, one confirm, one themed surface. The menu *is* the "discoverable graphical path" the issue asks for.

**Composes cleanly with the #97 lock automation.** The lock surface was wired with these triggers in mind: swayidle already honours `loginctl lock-session` (its `lock` event) and locks before any suspend (its `before-sleep` event). So "Lock" and "Suspend" here are just the deliberate triggers for machinery that already exists — resume always requires auth regardless of how the suspend was initiated.

**Power/session is a `Hyper`-namespace capability — and Hyper now exists on metis.** Under the keybinds philosophy, lock / personal-system commands belong to the `Hyper` namespace, and keyd now realizes that modifier on metis ([keyd.md](./keyd.md), #282). So the menu binds directly to `Hyper+Escape`, landing in its philosophically-correct home from the start with no interim `Super`-side detour (Escape reads as "get me out" — the session/power surface). `Mod+Shift+E` → quit niri is left untouched, so the direct keyboard quit still works.

## Alternatives considered

**wlogout** — the purpose-built Wayland power menu (a grid of icon buttons: lock/logout/suspend/hibernate/reboot/shutdown). The category default in many Hyprland/niri configs. Passed over: **no Stylix target in our pinned Stylix** (verified at the home-manager level alongside fuzzel/swaylock/waybar/fnott, all of which *are* targets), so theme cohesion (ADR-028) would require hand-wiring CSS from the palette — the gtklock problem from #97. It is also a new package + a CSS layout file to maintain, for a job `fuzzel --dmenu` already does in the palette we already theme. And — like the native menu below — wlogout has **no per-action confirmation**; its only guard is the menu being an intermediate screen (it's the most common dedicated power menu in the wild, especially Hyprland rices, but that doesn't change the fit here).

**Direct per-action niri keybinds** — bind logout/suspend/reboot/shutdown each to its own chord. Passed over: it adds four binds at once (against *one bind per ceremony*), spends scarce keymap real estate on rare actions, and — worst — wires `systemctl poweroff`/`reboot` to single keystrokes with no confirmation (niri's quit-confirm dialog covers only `action.quit`, not arbitrary spawns). A single deliberate menu pick (plus a confirm on the destructive two) is safer and tidier. A *dedicated* lock-now bind may still be worth adding later as its own one-bind ceremony (lock is the highest-frequency action); it is deliberately not bundled here.

**waybar's native `menu` (in-bar GTK dropdown)** — waybar can render the menu directly via `menu` / `menu-file` / `menu-actions` (it even ships a power-menu example). Passed over: it has **no built-in confirmation** and is **flat-only — no submenus** ([`waybar-menu(5)`](https://man.archlinux.org/man/extra/waybar/waybar-menu.5.en)), so guarding reboot/shutdown means routing its actions through a confirm-wrapper script regardless — at which point spawning the script directly is simpler. It also duplicates the action list (separate from the script), is relatively new (mid-2024), needs an absolute `menu-file` path, and carries a live `:hover`-stuck bug ([waybar #4638](https://github.com/Alexays/Waybar/issues/4638)). The mouse surface we *do* adopt is a `custom/power` `on-click` → the same script (see Configuration) — the button is the trigger; fuzzel stays the menu.

**nwg-bar / rofi-wayland power-menu modes** — heavier GTK/cairo stacks already passed over on the launcher selection (#73, fuzzel.md). No reason to reintroduce that weight here when the chosen launcher covers it.

## Configuration

**HM module** — a new `home/nixos/power-session.nix`, added to the desktop-env home bundle's imports (`home/nixos/bundles/desktop-env.nix`) alongside `screen-lock.nix`, placed under `nixos/` for the same Wayland-only reason as fuzzel/foot.

- The menu is a `pkgs.writeShellApplication` (shellcheck-clean, to satisfy the pre-commit `shellcheck` hook) that pipes the labelled entries to `fuzzel --dmenu` and `case`-dispatches the selection. fuzzel prints the chosen line to stdout and *nothing* on Escape/cancel, so an unrecognised or empty selection falls through the `case` to a no-op.
- **Destructive actions are confirmed; safe ones dispatch directly.** Lock and Suspend run immediately. Log out relies on niri's *built-in* quit-confirm dialog, so it needs no extra prompt. Reboot and Shut down route through a second `fuzzel --dmenu` prompt (`Cancel` / `Yes, <action>`) with `Cancel` pre-highlighted as the default (`fuzzel --select-index 0`); because cancel/Escape emits nothing, a stray Enter on the default lands on `Cancel` and dispatches nothing. This second-prompt confirm is the established `--dmenu` idiom — [jluttine/rofi-power-menu](https://github.com/jluttine/rofi-power-menu) confirms logout/reboot/shutdown by default and ships a standalone `dmenu-power-menu` variant; this follows that model.
- Entry order puts the safe, frequent action (Lock) first and the destructive pair last.

**Keybind** — `home/nixos/niri.nix` gains `"Mod+Ctrl+Alt+Shift+Escape".action.spawn` → the menu script (niri spells `Hyper` as the four modifiers `Mod+Ctrl+Alt+Shift`). One new `Hyper` bind — one learning ceremony — and `Mod+Shift+E` → `action.quit` is left as-is (direct quit-niri stays; the menu's "Log out" entry is the fuller path). The Hyper modifier this needs is realized by keyd (#282, landed), so the chord fires. [keybinds.md](./keybinds.md) gains the `Hyper+Escape` row in the same PR (the bind-manifest commit).

**waybar trigger** — `home/nixos/waybar.nix` gains a `custom/power` module (a power glyph) whose `on-click` spawns the same menu script. Mouse and keyboard hit one script, so the menu definition, the confirm, and the Stylix-themed surface are all shared. The button needs no modifier, so it is **keyd-independent** — the mouse path works regardless of keyd.

**No system module / no sudo expected.** The actions are issued by the operator's *active* graphical session (niri under greetd is a proper logind seat session), which logind's default polkit rules let suspend/reboot/poweroff and lock without authentication. So this is home-manager-only, like screen-lock.nix — but see Sharp edges to verify on first activation.

## Sharp edges

**Verify the active session may power-control without a polkit prompt.** The design assumes logind grants the active seat session `suspend`/`reboot`/`poweroff` and `lock-session` without auth — the systemd default for a *single* local active session, but not yet exercised on metis. First-activation check: run each menu entry once. Two failure modes to keep apart: (a) if an action silently no-ops or a polkit prompt appears with nowhere to type, the session isn't being treated as active — fix with a polkit rule, or confirm the greetd session registers with logind as `seat0`/active (not a script change); (b) reboot/poweroff specifically route to logind's `*-multiple-sessions` polkit action — **auth-required by default** — whenever a *second* session exists (a lingering SSH login, a leftover TTY, or root), so a surprise prompt there usually means "something else is logged in," not a seat-registration problem. On a single-operator box (b) is usually moot, but it is the likelier real cause of an unexpected prompt. metis break-glass is the physical console (CLAUDE.md §Break-glass), so a wrong reboot/poweroff is recoverable but disruptive — verify before trusting.

**Logout returns to greetd, not a fresh niri.** "Log out" quits the compositor; the niri user session ends and you land on the regreet greeter. Any unsaved work in the session is gone — same semantics as a real logout. `niri msg action quit` deliberately keeps niri's built-in quit-confirm dialog (it does **not** skip it — niri shows the dialog by default; `niri msg action quit --skip-confirmation` is what bypasses it). That dialog is the logout confirmation, which is why "Log out" needs no separate fuzzel confirm. Add `--skip-confirmation` only if a one-tap logout is ever wanted.

**`fuzzel`, `niri msg`, `loginctl`, `systemctl` must resolve in the spawn environment.** niri spawns inherit the session PATH and `NIRI_SOCKET` (the same import-environment path screen-lock.nix relies on for `niri msg`), so the script's tools resolve. If the menu opens but `niri msg action quit` no-ops, an unset `NIRI_SOCKET` is the first thing to check — same failure mode documented in screen-lock.md §Sharp edges.

**The bind uses the Hyper modifier from #282 (landed).** `Hyper+Escape` is `Mod+Ctrl+Alt+Shift+Escape`, which fires because keyd now maps Caps Lock to that chord ([keyd.md](./keyd.md), #282). `Mod+Shift+E` → quit niri is unaffected and remains the keyboard quit regardless. The waybar button needs no modifier, so it is reachable by mouse independent of keyd.

**Smoke-test the waybar `on-click` launch.** There are old reports of launching a launcher from a waybar `custom`-module `on-click` mis-routing the *next* bar click ([waybar #1968](https://github.com/Alexays/Waybar/issues/1968), ~2022, pre-niri) — likely a stale layer-shell artifact, but on first activation verify that clicking the power button opens the menu and the bar stays responsive afterward.

**Hibernate is deliberately omitted.** No swap-to-disk is configured on metis, so `systemctl hibernate` would fail; the menu offers suspend only. Revisit if hibernation is ever set up.

## References

- [screen-lock.md](./screen-lock.md) (#97) — the unattended lock/idle automation this composes with; `swayidle` `lock` + `before-sleep` events are the triggers used here.
- [keybinds.md](./keybinds.md) — modifier-namespace philosophy + cadence; gains the `Hyper+Escape` row (the `Hyper` namespace; `Mod+Shift+E`/Session left as-is).
- [keyd.md](./keyd.md) (#282) — realizes the `Hyper` modifier on metis that this bind depends on.
- [fuzzel.md](./fuzzel.md) (#73) — the launcher reused in `--dmenu` mode; its Stylix target is what themes the menu.
- `home/nixos/power-session.nix` — the menu script + dispatch (the implementation surface).
- `home/nixos/niri.nix` — the `Hyper+Escape` (`Mod+Ctrl+Alt+Shift+Escape`) bind; `home/nixos/waybar.nix` — the `custom/power` `on-click` mouse trigger.
- [jluttine/rofi-power-menu](https://github.com/jluttine/rofi-power-menu) — the `--dmenu` confirm idiom (default-confirm logout/reboot/shutdown) this follows.
- waybar [`menu(5)`](https://man.archlinux.org/man/extra/waybar/waybar-menu.5.en) (native dropdown — rejected, §Alternatives) and [#1968](https://github.com/Alexays/Waybar/issues/1968) (the `on-click` smoke-test).
- ADR-028 (Stylix as surface source-of-truth — the "no Stylix target ⇒ hand-wired CSS" argument against wlogout), ADR-029 (niri-only desktop).
- logind / polkit defaults for active-session power actions; niri IPC `quit` action.
