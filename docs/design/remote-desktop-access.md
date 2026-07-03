# Remote desktop access to the metis desktop

**Status:** Proposed — design note (`docs/design/`), dated 2026-07-03; no tracking issue yet. Not built; core thinking only — intent and forces, mechanisms surveyed — stops short of de-risk, build, and a selection. The capability is *remote control* of the metis niri desktop, distinct from the view-only screencast in [docs/desktop/screen-sharing.md](../desktop/screen-sharing.md) (which scopes remote control out, niri #390). Compositor choice enters only as one consideration among the options (§Rationale); the interaction-model tangent to [macos-deterministic-tiling.md](./macos-deterministic-tiling.md) is parked in §Future so it does not contaminate the need.

## Summary

The need: reach and *drive* the metis desktop environment remotely — from the operator's M2 MacBook Air, over Tailscale — as a full interactive session, not merely a shared view. metis runs niri (Wayland/Smithay) on an Intel iGPU. This note frames that capability and the forces any solution must satisfy (private transport, a client-sized display, low-latency interactivity, declarative packaging, ideally headless-capable), surveys the realistic mechanisms (Sunshine/Moonlight via KMS + uinput, wayvnc via wlr-screencopy, and the compositor-virtual-output variants), and stops before selecting one. The compositor is a *consideration within* this design — niri's lack of a pure headless output shapes which mechanisms are clean — not the subject of it.

## Motivation

The operator wants to use the metis desktop from the MacBook the way they would at the machine: a full niri session, controllable, over the network. Today the repo offers only *view-only* screencast ([docs/desktop/screen-sharing.md](../desktop/screen-sharing.md)) — the browser-into-a-call PipeWire/portal path — which explicitly scopes *remote control* out (niri has no RemoteDesktop input portal, niri #390). So remote *desktop* is a genuinely new capability, not an extension of screencast.

Sunshine was the operator's prior tool for this elsewhere; the question that opened the exercise was whether it works with niri. It does — but not via the Wayland portal (the path that fails on niri); via KMS/DRM capture + `/dev/uinput`, both compositor-agnostic. That established the capability is reachable on the current stack and turned the exercise into *which mechanism, under what forces*.

Forces any solution must honour:

1. **Remote *control*, not view-only.** The session must be drivable (keyboard/mouse), not merely observed — this is what separates it from the existing screencast capability.
2. **Private transport.** Reachable over Tailscale (already on metis), no ports opened to the internet — consistent with the repo's key-only, whitelist posture.
3. **Client-sized display.** A display sized to the M2 Air (1470×956 logical / 2560×1664 native) so the remote view is neither letterboxed nor rescaled — ideally a *dedicated* remote display rather than a mirror of a physical monitor.
4. **Headless-capable.** metis should be usable remotely whether or not a monitor is attached — so the display must exist without physical hardware present.
5. **Low-latency interactivity.** Good enough to actually work in, which favours hardware-encoded H.264/HEVC (metis's Intel iGPU has VAAPI) over plain framebuffer VNC.
6. **Declarative, in-git.** Install + config live in the flake (capability wrappers, udev rules, service units, kernel params), no imperative host state — core repo philosophy.
7. **Minimal disruption to the current desktop.** The metis niri/Stylix desktop (ADR-028/029) keeps working unchanged; a solution that forces a compositor swap pays a large, separate cost (§Rationale).

Forces 3 and 4 together are the crux, and the reason the compositor enters at all: the cleanest way to get a dedicated, client-sized, monitor-less display is a *pure compositor virtual output*, and mainline niri does not offer one ([niri #714](https://github.com/YaLTeR/niri/discussions/714)) — so on niri the same effect must come from a forced-EDID real output instead. That is a *consideration shaping the options*, not the design's subject.

## Design

Candidate mechanism (leading option — logged to make the shape concrete, **not** yet selected): **Sunshine + Moonlight over Tailscale.**

- **Capture.** Sunshine's KMS/DRM grab reads frames off a real scanout — compositor-agnostic, so it works under niri where portal-based tools fail. Requires the `cap_sys_admin` capability on the Sunshine binary.
- **Input.** `/dev/uinput` injects a virtual keyboard/mouse/gamepad at the kernel level, below Wayland — again compositor-agnostic. Requires a uinput udev rule.
- **Display (forces 3 + 4).** Because niri has no pure virtual output, provide a **forced-EDID output**: a kernel `video=` line or an EDID blob (`drm.edid_firmware`) that makes the Intel connector present a display at the Mac's logical resolution with no monitor attached — a genuine KMS scanout Sunshine can capture, sized to the client.
- **Encode (force 5).** VAAPI hardware H.264/HEVC on the Intel iGPU.
- **Transport (force 2).** Sunshine's ports bound to / reachable only over the Tailscale interface; pair Moonlight on the Mac to the tailnet address.
- **Packaging (force 6).** `pkgs.sunshine` with the `cap_sys_admin` wrapper (`security.wrappers`), the uinput udev rule, the service wired declaratively, and the forced-EDID line in metis's kernel params — none of it imperative.

How this meets the forces: control (uinput) ✓, private transport (Tailscale) ✓, client-sized + headless (forced-EDID) ✓, low latency (VAAPI) ✓, declarative ✓ — and, decisively for force 7, **no compositor change**: it runs on metis's niri as-is.

## De-risk evidence

**None yet — deliberately (core thinking).** Load-bearing assumptions, stated unverified, to be tested before a selection:

- **KMS capture works on niri/Intel** with `cap_sys_admin` — documented and community-reported ([niri #680](https://github.com/YaLTeR/niri/discussions/680)), but **not verified on metis**.
- **Forced-EDID yields a capturable scanout** at the target resolution on the i915 connector with no monitor attached — a standard mechanism, but **unverified on this hardware**.
- **uinput input reaches the niri session** correctly (no stuck keys, focus intact). **Unverified.**
- **Latency over Tailscale is workable** from the Mac in daily use. **Unverified.**
- **Nix packaging composes** — the cap wrapper + udev rule + service + kernel param land cleanly against the pins. **Unverified.**

## Drawbacks

- **Sunshine + forced-EDID is machinery.** A cap-wrapped binary, a udev rule, and a kernel EDID hack are more moving parts than a single VNC daemon — each a thing to maintain and a small attack surface (mitigated by Tailscale-only exposure).
- **`cap_sys_admin` is a broad capability** to grant a user-facing service; worth a deliberate look even behind Tailscale.
- **The forced-EDID display is a compromise for force 3.** It is a *real* output faked into existence, not the elegant compositor-invented virtual output — a fixed resolution baked into kernel params, not negotiated with the client.
- **Doing nothing** leaves the metis desktop reachable only by SSH/CLI and view-only screencast — no remote GUI session, which is exactly the gap.

## Cost

The standing price of the Sunshine route once chosen: a little **privileged declarative plumbing to carry** on metis (cap wrapper + uinput rule + forced-EDID kernel param) that other hosts do not have, plus a fixed remote resolution to revisit if the client changes. Modest, and localised to one host.

## Rationale & alternatives

Weighed against the forces; none selected — the exercise stops at survey. **This is where the compositor enters — as one axis among several, not the frame.**

- **Sunshine + Moonlight (KMS + uinput + forced-EDID)** — leading candidate. Clears every force *on the current compositor* (force 7): best interactivity (HW encode, force 5), works on niri today. Cost: the privileged plumbing above.
- **wayvnc (wlr-screencopy + virtual pointer/keyboard)** — viable since niri implements the virtual-pointer protocol (25.02+; metis runs 26.04). Lighter (one daemon), but plain VNC → worse latency/quality (force 5) and minor stuck-key/shortcut quirks reported. Its one distinctive edge — capturing a *pure compositor virtual output* — niri cannot supply, so on niri it *still* needs a forced-EDID real output like Sunshine.
- **Pure compositor virtual output (the ideal for forces 3 + 4)** — a compositor-invented, client-sized, monitor-less display (`create_output`). Elegant and headless-clean, but **niri lacks it** ([niri #714](https://github.com/YaLTeR/niri/discussions/714), fork-only). This is the *only* place the compositor becomes decisive: obtaining it would mean **either** waiting for niri #714 **or** swapping metis to a wlroots compositor (sway/Hyprland) or a full desktop (GNOME remote-login). **Swapping the compositor is thus one option to enable one variant of this capability — a heavyweight one that reopens [ADR-029](../decisions/ADR-029-niri-only-desktop.md) and trades away niri's scrollable tiling — and is not pursued here.** The need is met on niri via forced-EDID without it; a compositor change would need its own justification (§Future), not this need's.
- **waypipe** — forwards individual Wayland apps over SSH, not a full desktop session. Fails force 1's "the desktop" intent; useful adjacent, not the answer.
- **GNOME / KDE remote-login** — first-class client-sized virtual-monitor remote desktop, but means running that desktop, not niri — a far larger swap than sway. Out of scope.
- **Do nothing** — the gap (no remote GUI session) stands; SSH + view-only screencast remain the only reach.

## Prior art

- **[docs/desktop/screen-sharing.md](../desktop/screen-sharing.md)** — the existing *view-only* screencast capability and its explicit remote-control scope-out (niri #390); the boundary this note sits just past.
- **[niri #680](https://github.com/YaLTeR/niri/discussions/680)** — community confirmation that Sunshine remote desktop works on niri via KMS capture + uinput.
- **[niri #714](https://github.com/YaLTeR/niri/discussions/714)** — the headless/virtual-output request; the feature whose absence forces the EDID workaround.
- **Sunshine / LizardByte** — the KMS-capture + uinput + VAAPI host model; the operator's prior remote-desktop tool.
- **wayvnc** — the wlr-screencopy + virtual-pointer VNC path (niri 25.02+).

## Unresolved questions

- **Sunshine vs wayvnc** — the actual selection, deferred to a `selecting-tooling` run once the need is endorsed; this note surveys, it does not pick.
- **Is headless (force 4) a hard requirement, or does metis normally have a monitor attached?** If a monitor is usually present, the forced-EDID work may be unnecessary (capture the real display) — a cheap fact that materially simplifies the design.
- **Which resolution to target** — 1470×956 (logical) vs 2560×1664 (native 2×); logical-at-scale-1 is the bandwidth-sane default for a stream.
- **Is `cap_sys_admin` acceptable** for this service, or should the KMS-capture privilege be narrowed?
- **Out of scope:** the selection itself, the compositor question (its own exercise if ever raised), and multi-client / multi-monitor remoting.

## Future possibilities

- **A compositor with native virtual-output support.** If the operator later wants the *pure* virtual-output experience (no forced-EDID), that is a separate compositor exercise (sway/Hyprland, or niri #714 landing) carrying its own independent pull — **i3-model convergence with AeroSpace on neptune** ([macos-deterministic-tiling.md](./macos-deterministic-tiling.md)). Parked here explicitly so it does not contaminate *this* need, which niri meets today.
- **A shared remote-desktop bundle.** The Sunshine/wayvnc + Tailscale wiring as a reusable capability, decoupled from the compositor, usable by whichever desktop a host runs.
- **Dynamic client-sized resolution.** Matching the remote display to the connecting client automatically (as GNOME remote-login does), rather than a fixed forced-EDID mode.
