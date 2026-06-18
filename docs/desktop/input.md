# Input device configuration

Keyboard and pointer ergonomics on metis (niri): key-repeat, scrolling, pointer feel, and the gaming mouse's DPI / buttons / onboard profiles. Hardware in scope: a wired **Logitech G502 HERO** mouse (onboard memory) and a **Keychron K1** keyboard.

## Selection

**Two layers, two tools, by where the setting physically lives:**

- **Device layer** — DPI steps, button remaps, report rate, LEDs, **onboard profiles** → **libratbag/ratbagd** (`services.ratbagd.enable`), driven interactively with `ratbagctl` (and optionally the **Piper** GTK GUI). Settings are written to the **G502's onboard memory**, so they travel *with the mouse* across reboots and machines.
- **Compositor layer** — key-repeat rate/delay, scroll method, natural-scroll, pointer acceleration → **niri's declarative per-category `input` block** (`programs.niri.settings.input.{keyboard,mouse}`). niri configures input *by device category*, not by device name, so these apply to whatever pointer/keyboard is plugged in.

## Rationale

**The operator wanted a GUI rather than declarative config, and resilience to swapping mice. Both concerns are satisfied — but by splitting the problem, not by finding one GUI for everything.** The settings that actually have a rich knob-surface worth a GUI (DPI tiers, the G502's eleven buttons, onboard profiles) are exactly the device-layer settings, and libratbag/Piper is the established Wayland-era tool for them. Those settings live in the mouse's onboard memory, which is also what makes them swap-resilient — they're carried by the hardware, not pinned to a host config, and survive a move to any machine. So the GUI desire and the swap-resilience desire are served by the *same* layer.

**The compositor layer needs neither a GUI nor swap-proofing.** Key-repeat, scroll method, and accel are a handful of set-once scalars; a GUI would add ceremony over five values. And the original fragility worry — "declarative config breaks when I change mice" — does not hold for niri, because niri keys input settings by device *category* (`mouse`, `keyboard`, …), not by device name or `event` number. The genuinely swap-fragile pattern is per-device `udev`/`xinput` rules tied to a device identity, which this config does not and would not use. So the compositor layer is the repo-native declarative home, in lockstep with the rest of the niri config — no tension with the project's declarative posture.

**The split keeps the declarative stance intact.** The flake declaratively enables the *capability* (`services.ratbagd.enable` + `piper`); the *device profile* (DPI/buttons) lives in mouse firmware, which was never in the flake's scope — no more than a monitor's OSD or keyboard firmware is. The compositor feel is fully declarative in niri-flake. Nothing imperative leaks into OS or user state.

**Acceleration is set once, deliberately, at the compositor.** Pointer accel is computed in **libinput** (niri passes `accel-speed`/`accel-profile` straight through), and it is *independent of and multiplicative with* the mouse's onboard DPI. With niri/libinput's default `adaptive` profile, raising onboard DPI also shifts where you sit on the velocity curve, so the two compound non-linearly. The selection is to set sensitivity via **device DPI** and pin the compositor to **`accel-profile "flat"`** (velocity-independent), so the two layers don't fight.

## Alternatives considered

**Device layer:**

- **Solaar** — works over wired USB HID++ and *does* see a wired G502 HERO, but it cannot remap the G-buttons (no UI for it) and shares the same onboard-mode revert gotcha. Viable as a *secondary* read-out tool; not a replacement for the button/profile surface. Passed over as the primary.
- **logiops / logid** — wrong tool: its tested-device list is entirely MX-series; no G502, no G-series. Runtime gestures/SmartShift only, no onboard-profile writes.
- **Logitech G HUB / Onboard Memory Manager** — Windows/macOS only; no native Linux build and no credible Wine path. Not an option on metis.

**Compositor layer:**

- **Third-party niri config GUIs** (niri-settings, NiriMod, …) — none packaged in nixpkgs, and they'd write imperative state *outside* the flake, which is the opposite of what this repo wants. The compositor layer belongs in `programs.niri.settings.input` regardless, so "no GUI here" isn't a loss.
- **GNOME Settings / KDE System Settings** — do not apply: niri is Smithay-based, not Mutter or KWin, and reads input only from its own KDL. `gsettings`/`dconf` don't drive niri's accel/repeat/scroll.
- **All-on-device** (fix DPI on the mouse, neutralise the compositor with flat accel and do nothing else) — a legitimate minority approach. Rejected because key-repeat and scroll *must* live at the compositor on Wayland anyway (see Sharp edges), so the compositor layer can't be empty.

## Configuration

- **Device layer** — `services.ratbagd.enable = true;` (NixOS). The module is deliberately minimal: it ships `libratbag` (giving the `ratbagctl` CLI), registers the package for D-Bus activation, and installs the systemd unit. `ratbagd` is **D-Bus-activated — do not `systemctl enable` it.** Piper, if installed, is *only* a frontend and requires `ratbagd` running. Settings are authored interactively and persisted to the G502's onboard memory; they are intentionally **not** declared in the flake.
- **Compositor layer** — `programs.niri.settings.input` in `home/nixos/niri.nix`: `keyboard.{repeat-delay,repeat-rate}` (niri's defaults are a sluggish 600 ms / 25 Hz), `mouse.{accel-profile = "flat", accel-speed, natural-scroll}` (scroll-method left at niri's default — the G502's wheel needs no override). The non-feel-dependent choice is `accel-profile "flat"` with `accel-speed 0` (rationale above); the feel-dependent values (exact repeat rate/delay, scroll direction) are tuned on metis.

## Sharp edges

- **libratbag/Piper is in maintenance mode.** No tagged release since 2024-09 (libratbag 0.18 / Piper 0.8 — which are the versions in our pin, so we're current, not lagging); commits continue but are almost entirely device-data additions, with a large open-issue backlog. The engine is effectively frozen. Acceptable: the device layer is non-critical, and the G502 HERO is first-class supported (the `logitech-g502-hero.device` data file is present in the pinned `libratbag`).
- **G502 HERO button-mapping bugs in Piper.** Some side/extra buttons (delivered via hidraw) can't be remapped or saved through Piper, and modifier keys can't be assigned to buttons. Prefer **`ratbagctl`** over the GUI for button work on this device — which dents the "GUI-managed" goal for the *button* sub-surface specifically (DPI/profiles via the GUI are fine).
- **Onboard-mode gotcha — the #1 "it didn't stick" cause.** libratbag writes to onboard profiles, which only take effect when the mouse is in onboard-profile mode. If G HUB on another OS ever switched the G502 to host/software mode, libratbag's writes silently no-op and settings appear to "revert after reboot." Check the mode first if anything fails to persist.
- **`ratbagd` registers no udev rules.** The NixOS module sets `systemd.packages`/`services.dbus.packages` but not `services.udev.packages`. Fine because `ratbagd` runs as a root D-Bus daemon; if a non-root `ratbagctl` ever needs device access, add `services.udev.packages = [ pkgs.libratbag ];`.
- **niri has no per-device input config yet.** Settings are category-wide ([niri #371](https://github.com/niri-wm/niri/issues/371) open; per-device PRs unmerged as of the 2026-06-16 pin). If the operator ever runs two pointers simultaneously wanting different *compositor* feel, that's blocked upstream until per-device lands — re-check on each niri-flake bump. (Different *device* settings for two mice are fine — they live on each mouse's onboard memory.)
- **Wayland key-repeat is compositor-owned.** Rate/delay travel via `wl_keyboard.repeat_info`; `xset r rate` is inert for native Wayland clients. So `repeat-rate`/`repeat-delay` *must* live in niri config, not in any X-era tool.

## References

- [#107](https://github.com/dannyfaris/nix-config/issues/107) — input device configuration (this selection).
- [niri.md](./niri.md) — compositor selection; this doc covers its `input` block.
- [keyd.md](./keyd.md) — Caps Lock → Hyper remap at the evdev layer (distinct concern: a modifier remap, not input ergonomics).
- niri input reference — https://github.com/niri-wm/niri/wiki/Configuration:-Input
- niri per-device tracking — https://github.com/niri-wm/niri/issues/371
- libratbag (+ G502 HERO device data) — https://github.com/libratbag/libratbag · https://github.com/libratbag/libratbag/blob/master/data/devices/logitech-g502-hero.device
- Piper GUI — https://github.com/libratbag/piper
- NixOS `services.ratbagd` module — https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/hardware/ratbagd.nix
- libinput pointer acceleration — https://wayland.freedesktop.org/libinput/doc/latest/pointer-acceleration.html
