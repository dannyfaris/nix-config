# Bluetooth — BlueZ peripherals on the desktop hosts

Bluetooth peripherals (headphones, keyboards, mice) for every NixOS desktop host — alcyone, alnair — via `modules/nixos/bluetooth.nix` in the system `desktop-env` bundle (#773). Born as a laptop concern in the mobility bundle (#636); promoted fleet-wide when alcyone's fully-functional adapter turned out to have no userspace stack behind it. electra (headless) and celaeno (Darwin) carry none of this.

## Premise

Not a selection — BlueZ is the only Linux Bluetooth stack, so there was no A-vs-B to run. The stack is kernel HCI + `bluetoothd` (from `hardware.bluetooth.enable`) + surfaces: Noctalia's Bluetooth panel for day-to-day pairing/connecting, `bluetoothctl` as the always-works fallback. This doc exists for the sharp edges, which the #773 rollout produced in quantity.

## Configuration

- `hardware.bluetooth.enable = true` — the whole module, deliberately minimal; BlueZ defaults are fine for peripheral use.
- Pairings live in `/var/lib/bluetooth`, persisted across the ephemeral root via the module's `persist.enable`-gated entry (module-owns-its-state, [docs/design/ephemeral-root.md](../design/ephemeral-root.md)) — pair once, survive reboots.
- Bluetooth *audio* needs nothing extra: WirePlumber's stock bluez monitor registers the A2DP endpoints the moment `bluetoothd` appears, so a connected headset becomes a PipeWire sink with zero `services.pipewire` Bluetooth config — see [audio.md](./audio.md) §Sharp edges for that boundary.

## Sharp edges

**Noctalia pairs but doesn't connect (upstream bug).** The panel's pair flow calls BlueZ `Pair()` — which only bonds — and never chains the `Connect()` that brings up audio profiles: the device shows paired, but no connection chime sounds and no PipeWire sink appears, which reads as a failed pairing. Upstream [noctalia#3867](https://github.com/noctalia-dev/noctalia/issues/3867) (found and filed here 2026-08-11; the issue carries the code pointer and one-line fix direction). Workaround: hit connect on the newly-paired device in the panel — connect/disconnect from the panel are verified working — and headset-side auto-reconnect on power-on is standard BlueZ trust behaviour (not yet exercised here), so in practice this bites first pair only. No local patch carried (proportionate: one extra tap, beta-tagged pin, fix lands with a routine bump).

**A shell older than the daemon shows a dead panel.** `nh os switch` starts newly-declared system services, but user-session processes keep the D-Bus view from *their* start: a Noctalia launched before `bluetooth.service` existed shows no adapter until the shell restarts, even while `bluetoothctl` (fresh connection) works perfectly. WirePlumber handles late adapter arrival; Noctalia doesn't. Restart the shell (or re-login) after a switch that adds a daemon the session fronts.

**Discovery no-shows are usually the headset, not the stack.** A multipoint headset already connected to a phone doesn't advertise at all, and most headsets need explicit pairing mode (WH-1000XM5: hold power ~7 s until the LED double-blinks) rather than just being on. If `bluetoothctl scan on` doesn't list the device within ~20 s, fix the headset side before suspecting BlueZ.

## Verification (runtime, before done)

Verified on alcyone 2026-08-11 (set ≠ enforced, #303): `bluetooth.service` active; WH-1000XM5 discovered, paired, trusted, connected via `bluetoothctl`; headset became the default PipeWire sink with audio confirmed; `/var/lib/bluetooth` confirmed bind-mounted from the persist subvolume; Noctalia panel drives connect/disconnect after a shell restart.

## History

#636 introduced the module for alnair's laptop peripherals inside the mobility bundle. #773 (2026-08-11) reclassified Bluetooth as a desktop capability and moved the import to desktop-env — landed as the repo's first stacked-PR pair (#774 enable + #775 mobility retirement, atomic squash merge). The rollout's runtime verification surfaced the Noctalia pair bug and the stale-session race, which motivated this doc (#781).

## References

- [BlueZ](https://www.bluez.org/) — the Linux Bluetooth stack; `bluetoothctl` is its interactive CLI.
- [noctalia#3867](https://github.com/noctalia-dev/noctalia/issues/3867) — pair-without-connect (open at time of writing; diagnosis and suggested fix inline).
- NixOS options: `hardware.bluetooth.*` (bluez package, `powerOnBoot`, `settings` passthrough to `main.conf`).
