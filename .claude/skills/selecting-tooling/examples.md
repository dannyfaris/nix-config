# Worked examples

Four real selections run through this process. Each is here for one reason: to show how **step 4 (verify against the real system/pins) changed the outcome** — the part a one-shot answer would have gotten wrong.

## Contents
- Audio — convention is the answer; verify it's *actually* convention
- Clipboard — the marquee feature was inert; the version we'd get lacked the fix
- Polkit — the premise was false, and "the only Qt app" unlocked a 573 MiB cleanup
- Removable media — the stated dependency didn't exist (passwordless mounting)

## Audio (sound server + volume)

**Request:** the desktop has no sound.

**What grounding + research found:** PipeWire + WirePlumber is the NixOS/Wayland default, and `wpctl` / `playerctl` are *niri's own shipped default binds* — so the lower layers were "adopt upstream," not invent.

**What verification changed:** the genuine forks were narrow — the waybar module (`wireplumber` vs legacy `pulseaudio`) and the GUI mixer. Checking the *pinned* waybar version showed the historical `wireplumber`-module gaps were already closed, collapsing that debate. The "GUI mixer" theming question turned on libadwaita vs GTK3 behaviour under Stylix — a mechanism detail, not a preference.

**Lesson:** when the answer is "the convention," still verify it *is* the convention in your pin — and find the small real fork instead of re-litigating the settled 80%.

## Clipboard (persistence + history)

**Request:** copied content should survive the source app closing, with history.

**What verification changed (twice):**
1. The candidate's headline security feature (clipse `excludedApps`, which ships with password managers pre-excluded) was read in **source** and found to query `wlrctl`/`hyprctl` only — it has no niri path, so it is **inert on niri**. The marquee advantage evaporated.
2. The protection that *does* work (the `CLIPBOARD_STATE=sensitive` hint chain) was broken at our pin: clipse **1.1.0** (what nixpkgs shipped) lacked the handler, added only in 1.1.1. The version we'd actually get mattered more than the latest upstream.

**Also:** "persistence" and "history" turned out to be two separate jobs (one tool gives history, another gives live-persistence) — a first-principles distinction the request blurred.

**Lesson:** verify marquee features against source on *your* compositor, and verify the *pinned* version has the fix — "it exists upstream" is not "you have it."

## Polkit (graphical auth agent)

**Request:** "nothing surfaces a graphical authentication prompt."

**What verification changed:**
- **The premise was false.** `niri-flake` already runs the KDE agent (`niri-flake-polkit`) — confirmed live on the host. The task became *swap*, not *add*.
- Walking the closure showed the KDE agent was the **only Qt app** on the host, making the Stylix `qt` target vestigial. The **marginal** removal (not the misleading standalone closure) measured **573 MiB / 62 paths** — and the running prompt was off-theme because no `kdeglobals` exists for a KDE app to read.

**Lesson:** check the premise first; compute *marginal* closure, not standalone; and a quick `/proc` / config-presence check ("does kdeglobals exist?") settled a theming claim no doc could.

## Removable media (USB mount + browse)

**Request:** plug in a USB → it mounts → it's reachable. The issue said it *depends on the graphical-auth work landing*.

**What verification changed:** udisks2's default polkit policy makes removable-media mounting **passwordless** for an active local session (`filesystem-mount = allow_active yes`); the auth agent is only invoked for internal/system disks. So the stated dependency on the polkit work **did not exist** for the common case. The stack (udisks2 + udiskie + the already-installed yazi) needed no GUI file manager and no gvfs.

**Lesson:** a stated dependency is a claim to verify, not a given — the actual policy/defaults often decouple things the issue coupled.
