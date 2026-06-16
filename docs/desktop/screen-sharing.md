# Screen sharing (screencast)

Screen sharing in browsers and calls for the niri desktop on metis (#101). Covers the *screencast* path — an application asks the desktop to capture a monitor or window, the user picks a target, and frames flow to the app over PipeWire. Remote *control* (input injection over the network) is a different capability and is out of scope here — see Sharp edges.

## Selection

**xdg-desktop-portal-gnome** as the screencast backend, driving niri's native `org.gnome.Mutter.ScreenCast` implementation, with **PipeWire** (+ wireplumber) as the frame transport. Nothing in this stack is added by this repo directly: niri-flake's nixosModule already wires `xdg.portal` + the gnome backend + PipeWire, and niri ships the `niri-portals.conf` that routes ScreenCast to `gnome`. This document records that the resulting stack is the deliberate choice for #101 — not an accident to be re-derived later. Every link below was verified *present and wired* (config eval + live D-Bus); the one thing not provable headlessly — that the wired stack actually delivers frames into a call — is the operator acceptance test in Configuration.

The chain, end to end:

```
app (Firefox)
  → xdg-desktop-portal            (frontend, org.freedesktop.portal.ScreenCast)
  → xdg-desktop-portal-gnome      (backend, org.freedesktop.impl.portal.ScreenCast)
  → org.gnome.Mutter.ScreenCast   (implemented by niri itself)
  → PipeWire node                 (the captured stream the app consumes)
```

## Rationale

**This is niri's own documented recommendation, not a wlroots reflex.** niri is Smithay-based, not wlroots, so the usual wlroots screencast backend (`xdg-desktop-portal-wlr`) is *not* its native portal path. niri's wiki states plainly that `xdg-desktop-portal-gnome` is "required for screencasting support," and niri implements the `org.gnome.Mutter.ScreenCast` D-Bus API that the gnome backend drives. The gnome backend here is talking to niri, not to GNOME Shell or Mutter — Mutter does not need to run.

**It is already what niri-flake selects, so "keep" is the lowest-surprise call.** `xdg.portal` arrives from niri-flake and the repo deliberately does not re-assert it — `libsecret.nix` records exactly this "inherited and not re-asserted" precedent for `xdg.portal`. The screencast backend and PipeWire arrive through the same transitive wiring. Re-declaring `services.pipewire.enable` or pinning `xdg.portal.config.screencast` in this repo would duplicate upstream defaults that could later drift out of sync, for no behavioural gain. The consistent stance is to **rely on niri-flake's wiring and document the dependency here**, rather than re-state it in Nix. If niri-flake ever stops providing the backend, this doc plus the empirical test below is what catches it.

**The browser surface needs no wiring.** metis browses with Firefox (Gecko, native Wayland). Gecko 121+ enables PipeWire/Wayland screen sharing by default and auto-detects `WAYLAND_DISPLAY` — no `media.webrtc` prefs, no flags. There is no Chromium daily-driver on metis, so the Chromium-specific "must run native Ozone Wayland to use the portal" caveat does not apply today; if a Chromium-based app is added later, that becomes its concern to document.

## Alternatives considered

**xdg-desktop-portal-wlr (xdpw).** The wlroots screencast backend, speaking the `wlr-screencopy` Wayland protocol. niri *does* implement `wlr-screencopy` (so tools like `grim` and OBS's "Wayland output (scpy)" source work directly against it), but that is a separate, portal-bypassing path. For the *portal* screencast that browsers and call apps use, niri routes through `org.gnome.Mutter.ScreenCast`, which xdpw does not serve. Picking xdpw as the portal backend would mean fighting niri's own `niri-portals.conf`. Passed over: wrong backend for niri's portal path; offered upstream only as an optional alternative, never the recommendation.

**xdg-desktop-portal-gtk as the screencast backend.** The gtk portal is the generic fallback and handles file-chooser / Access / Notification well, but it does **not** implement the ScreenCast interface. It is a companion to the gnome backend, not a substitute for it. (See Sharp edges — it is referenced by `niri-portals.conf` but not currently installed.)

## Configuration

No new Nix is required for screencast itself — the stack is present transitively. Confirmed on metis by config eval and live D-Bus introspection:

- `xdg.portal.enable = true` and `xdg.portal.extraPortals` contains `xdg-desktop-portal-gnome` — both inherited from niri-flake's nixosModule.
- `services.pipewire.enable = true` (PipeWire + wireplumber running) — also from niri-flake.
- niri's shipped `niri-portals.conf` carries `default=gnome;gtk;`, so ScreenCast (not pinned to a specific backend) falls through to `gnome` first.
- Versions in the current pin: niri 25.08, xdg-desktop-portal-gnome 50.0, PipeWire 1.6.5.

**Acceptance test (operator, interactive — the one step not provable headlessly).** In a live niri session, open a Google Meet / Zoom / Jitsi call (or `about:webrtc` test) in Firefox and start "Share screen." The portal picker should appear and the chosen monitor or window should stream. This is the gate that confirms the verified-capable stack actually delivers frames end to end.

## Sharp edges

- **Remote control is not available.** niri implements ScreenCast (view-only sharing) but not the RemoteDesktop portal (input injection / remote control) — niri #390 is open. Screen *sharing* in calls works; letting a remote participant *control* the machine (RustDesk-style) does not. This is an upstream gap, not a config choice.
- **gtk portal companion is not installed.** `niri-portals.conf` routes `Access` and `Notification` to `gtk` and lists `gtk` in the `default` fallback, but `xdg-desktop-portal-gtk` is not in `extraPortals`. This does not affect screencast (the gnome backend advertises those impl interfaces and absorbs the fallback), but the file-chooser / Access portals run through gnome rather than gtk. If a file-picker or access-dialog rough edge shows up, adding the gtk portal is the fix — tracked as adjacent to this work, not part of #101.
- **Portal startup race after login.** Both niri (#2399) and nixpkgs (#391489) record cases where the portal services need a restart after login before screencast works. If the first share of a session fails, `systemctl --user restart xdg-desktop-portal xdg-desktop-portal-gnome` is the recovery; only escalate to a Nix-level ordering fix if it proves repeatable.
- **Do not set `GDK_BACKEND` globally.** The niri wiki warns that a global `GDK_BACKEND` breaks the screencast portal. The repo does not set it anywhere (grep-confirmed); keep it that way.
- **GPU/DMABUF black-screen** has been reported on NVIDIA (niri #2223). metis is Intel (i915), so this risk is low here; it would resurface on an NVIDIA host.

## References

- niri wiki — Screencasting: https://github.com/niri-wm/niri/wiki/Screencasting
- niri wiki — Important Software (portal recommendations, GDK_BACKEND warning): https://github.com/niri-wm/niri/wiki/Important-Software
- niri #390 — RemoteDesktop portal support (open): https://github.com/niri-wm/niri/issues/390
- niri #2399 — screencast may need portal restart after login: https://github.com/niri-wm/niri/issues/2399
- nixpkgs #391489 — gtk portal login race under niri: https://github.com/NixOS/nixpkgs/issues/391489
- niri-portals.conf (upstream): https://github.com/niri-wm/niri/blob/main/resources/niri-portals.conf
- Firefox Wayland screen-sharing on by default (Jan Grulich): https://jgrulich.cz/2022/02/16/webrtc-journey-to-make-wayland-screen-sharing-enabled-by-default/
