# Karabiner-Elements

Keyboard customisation utility for macOS — intercepts input at the
IOKit/DriverKit layer, below macOS's own keyboard-shortcut and
modifier-remap systems, allowing arbitrary key-to-key and
key-to-modifier-combo remaps. Picked as the macOS-side realization
of the **Hyper modifier** from
[`docs/desktop/keybinds.md`](./keybinds.md)'s three-namespace
philosophy: Karabiner remaps `caps_lock` to `⌘ + ⌃ + ⌥ + ⇧` (the
macOS analogue of the Linux `Super + Ctrl + Alt + Shift` Hyper).

## Selection

Darwin: Homebrew cask `karabiner-elements`, declared in
`modules/darwin/homebrew.nix` per
[ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md)'s
**clause 2** (this doc owns the carve-out — see Rationale).
Declarative config at `~/.config/karabiner/karabiner.json` managed
by `home/darwin/karabiner.nix`.

Update stance: **Sparkle, but pkg-enclosure — expect admin
prompts on every update.** Same shape as Tailscale (pkg-bearing
cask with system extension). `SUEnableAutomaticChecks` +
`SUAutomaticallyUpdate` keys wired in `modules/darwin/homebrew.nix`
under bundle ID `org.pqrs.Karabiner-Elements`, belt-and-braces only.

## Rationale

**MAS unavailable.** Karabiner is distributed only via the upstream
`.dmg` (`pqrs.org`) and the Homebrew cask that wraps it; no
apps.apple.com listing exists. Sandboxed MAS distribution is
structurally incompatible with the DriverKit system extension
Karabiner requires. Rejected at ADR-031 Step 0; clause 3 cannot
apply.

**Clause-2 carve-out, framed operationally — the strongest case
in this repo to date.** `pkgs.karabiner-elements` is available on
`aarch64-darwin` and `x86_64-darwin` at v15.7.0 (`meta.platforms`
covers both Darwin archs). The binaries converge — both paths
ultimately derive from the same upstream
`Karabiner-Elements-X.Y.Z.dmg` from
`github.com/pqrs-org/Karabiner-Elements/releases`.

The cask is chosen because the nixpkgs Darwin derivation has
multiple named, load-bearing degradations — closer in shape to
Tailscale than to Typora:

- **Named integration: DriverKit system extension.** Karabiner
  ships `org.pqrs.Karabiner-DriverKit-VirtualHIDDevice`, a macOS
  DriverKit `.dext` that registers a virtual HID device through
  which all remapped events flow. The system extension requires
  user approval in System Settings → Login Items & Extensions →
  Driver Extensions on first install, and macOS validates the
  extension's signed location against its expected install path.
  The cask's vendor `.pkg` installer is the load-bearing path
  that drives this registration via macOS's standard
  `systemextensionsctl` flow.
- **Named integration: privileged launchd jobs.** Karabiner's
  upstream pkg installs 7+ launchctl jobs at
  `/Library/LaunchDaemons/` and `/Library/LaunchAgents/`
  (`org.pqrs.karabiner.agent.karabiner_grabber`,
  `org.pqrs.karabiner.agent.karabiner_observer`,
  `org.pqrs.karabiner.karabiner_console_user_server`,
  `org.pqrs.karabiner.karabiner_grabber`,
  `org.pqrs.karabiner.karabiner_observer`,
  `org.pqrs.karabiner.karabiner_session_monitor`, and the
  `NotificationWindow` agent — per the upstream cask's uninstall
  block). These are root-owned, system-scoped, and load on boot.
- **Named integration: privileged install location.** The
  vendor pkg places the `karabiner_cli` binary, runtime libs, and
  `Karabiner-DriverKit-VirtualHIDDevice` scripts under
  `/Library/Application Support/org.pqrs/Karabiner-Elements/` —
  not under `/Applications/`. The cask binary stanza wires this
  CLI onto PATH.
- **Named degradation:** `pkgs.karabiner-elements` extracts the
  pkg payload into the nix store and `substituteInPlace`s the
  plist paths from `/Library/...` to `$out/Library/...`. The
  binary is viable as a mechanism on paper, but at minimum the
  operator would have to stand up an ad-hoc privileged init
  layer the cask delivers for free in a single notarized pkg:
  manually `launchctl load` each of the 7+ launchd jobs from
  nix-store paths; manually register the DriverKit system
  extension via `systemextensionsctl` from a nix-store path with
  the open structural question of whether macOS will accept a
  `.dext` loaded from a non-standard install location (the OS
  validates signed extensions against their expected location
  and may refuse — empirical, not asserted); and accept that
  Sparkle-driven updates can't write back to the immutable
  store. The ad-hoc privileged init layer is the load-bearing
  cost of the carve-out, not the system-extension question
  alone — even if macOS accepts the `.dext` from the nix store,
  the operator is reproducing what the vendor pkg does on every
  bump. This is materially worse than the Sparkle-in-immutable-
  store case for Typora and ChatGPT, where the operator just
  accepts a no-Sparkle-writes posture.
- **Named verification path:** if a contributor wants to flip
  to `pkgs.karabiner-elements`, verify: (1) the DriverKit system
  extension registers correctly when loaded from a nix-store
  path (`systemextensionsctl list` shows
  `org.pqrs.Karabiner-DriverKit-VirtualHIDDevice` in `activated`
  state, not `terminated` / `error`); (2) all 7+ launchd jobs
  load reliably across reboots without manual intervention;
  (3) Karabiner's Sparkle path can be cleanly disabled (no
  error popups) when the bundle is immutable; (4) operator-
  cadence flake bumps land Karabiner updates often enough to be
  acceptable. If all four pass, clause 2's degradation premise
  dissolves and ADR-031 Migration trigger 1 applies.

**Update stance — Sparkle, but pkg-shaped.** Karabiner uses
Sparkle (livecheck against `appcast.pqrs.org/karabiner-elements-appcast.xml`
per the upstream cask). The appcast ships **`.dmg` enclosures
carrying `sparkle:installationType="package"`** — Sparkle's
second no-silent-path case per its package-updates docs (the
first being raw `.pkg` enclosures). Either shape triggers
Sparkle's "updates always require user authorization which also
prevents silent automatic installs" path. The SU\* keys below are
belt-and-braces only; expect an admin-password prompt on every
update. Same shape as Tailscale's pkg-bearing updates, with the
extra wrinkle that Karabiner's enclosure is a `.dmg`-wrapping-a-
`.pkg` rather than a `.zip`-wrapping-a-`.pkg`.

## Alternatives considered

**MAS** — not on MAS, structurally cannot be (DriverKit + sandbox
incompatible). Rejected at ADR-031 Step 0.

**`pkgs.karabiner-elements` on Darwin** — viable as a mechanism on
paper; carved out on the operational grounds above (DriverKit
system-extension registration, privileged launchd jobs, privileged
install location, all delivered by the vendor pkg installer the
cask path runs). The verification path in §Rationale enumerates
what a contributor would have to prove for the carve-out to dissolve.

**macOS native "Caps Lock as ⌃" remap** (System Settings → Keyboard
→ Modifier Keys → Caps Lock → Control). Maps caps_lock to a
single modifier; cannot produce a 4-modifier chord, which is what
Hyper requires. Functionally insufficient for the philosophy.

**Hammerspoon + key-remap Lua** — viable but heavier (full Lua
runtime, accessibility-permission scope, custom event handlers).
Karabiner's single-rule remap is closer to the philosophy's
goal of a thin, transparent layer.

**Goku** (Karabiner config in EDN) — a layer on top of Karabiner
that compiles to karabiner.json. Useful if the rule library grows
large, but unnecessary today: a single remap rule is more honestly
expressed as a Nix attrset than as EDN + a compiler. Revisit if
the rule count crosses a threshold where Nix-attrset readability
breaks down.

## Configuration

**Cask declaration** — `modules/darwin/homebrew.nix`:

```nix
homebrew.casks = [ "karabiner-elements" ];

system.defaults.CustomUserPreferences = {
  "org.pqrs.Karabiner-Elements" = {
    SUEnableAutomaticChecks = true;
    SUAutomaticallyUpdate = true;
  };
};
```

Bundle ID `org.pqrs.Karabiner-Elements` is the runtime main-app
bundle — distinct from the Sparkle updater bundle
`org.pqrs.Karabiner-Elements.Updater` (the suffix observed in the
upstream cask's zap-trash listing
`~/Library/Preferences/org.pqrs.Karabiner-Elements.Updater.plist`)
and the DriverKit extension bundle
`org.pqrs.Karabiner-DriverKit-VirtualHIDDevice`. The SU\* keys
land on the main app bundle; see §Sharp edges "Bundle ID
layering" for the full set.

**Declarative config** — `home/darwin/karabiner.nix` writes
`~/.config/karabiner/karabiner.json` via `home.file.<path>.text`
with the JSON serialized from a Nix attrset.

Two rule classes live in the config:

- **Modifier-production rules** — caps_lock → Hyper. The
  foundational rule that makes Hyper exist as a chord this Mac
  can emit. Owned by this doc because the choice of Karabiner
  is in service of producing the modifier; the chord shape
  (`caps_lock` source; `left_shift` + `cmd` + `ctrl` + `option`
  target) is the load-bearing detail captured in the
  carve-out's §Rationale.
- **Bind rules** — `Hyper + X → <native macOS chord>` remaps
  that translate Hyper-anchored bindings into existing macOS
  shortcuts at the DriverKit layer (consuming Hyper's mandatory
  modifiers in the process, so the emitted event is clean and
  macOS routes it natively). These are *bindings* and live in
  the bind manifest, not this doc; see
  [`keybinds.md`](./keybinds.md) §"Active bindings — macOS
  clients" for the enumeration.

The `home/darwin/karabiner.nix` source carries both classes in
its `complex_modifications.rules` list. The bind-rule entries
each carry a short header comment cross-referencing the
keybinds.md section they implement; the Nix source is the
implementation, the keybinds.md manifest is the source of truth
for *which* binds exist.

The config is symlinked into the nix store (read-only). This is
deliberate — see §Sharp edges "UI edits do not survive activation."

## Update behaviour

**Default (this config):** Sparkle checks on its schedule, but the
appcast enclosure is `.pkg` — Sparkle prompts for admin auth on
every update (per ADR-031 §Update mechanism stance + Sparkle's own
docs on package-updates). SU\* keys are set belt-and-braces but
do not produce a silent path.

Verify the keys took effect after first activation:

```bash
defaults read org.pqrs.Karabiner-Elements SUEnableAutomaticChecks   # → 1
defaults read org.pqrs.Karabiner-Elements SUAutomaticallyUpdate     # → 1
```

(Run as `system.primaryUser`, or prefix with `sudo --user=<primary-user>`
from a different account.)

**Fallback if Sparkle's prompts become intolerable:**

```nix
system.defaults.CustomUserPreferences."org.pqrs.Karabiner-Elements" = {
  SUEnableAutomaticChecks = false;
  SUAutomaticallyUpdate = false;
};
```

Then update Karabiner manually via
`brew update && brew upgrade --cask --greedy karabiner-elements`.
Same shape as Tailscale's fallback.

## Sharp edges

**First-install ceremony is multi-step and not declarative.**
Three operator-confirmed prompts on first install:

1. Pkg installer admin password (`/Library/...` writes).
2. **DriverKit system extension approval** in System Settings →
   Login Items & Extensions → Driver Extensions → enable
   `Karabiner-DriverKit-VirtualHIDDevice`. One-time per Mac. If
   skipped, Karabiner runs but no remaps fire — the virtual HID
   device the rules target doesn't exist.
3. **Input Monitoring TCC permission** for `karabiner_grabber`,
   `karabiner_observer`, and the main Karabiner-Elements UI in
   System Settings → Privacy & Security → Input Monitoring.
   macOS prompts on first launch; one-time.

None of these have a nix-darwin-declarative path. Documented in
the bootstrap runbook alongside the App Store sign-in.

**UI edits do not survive activation.** `home.file` symlinks
`karabiner.json` from the nix store. The Karabiner-Elements
Preferences UI writes to `karabiner.json` when the operator
changes anything via the GUI — those writes will fail (read-only
symlink) or replace the symlink with a real file (broken on next
`nh darwin switch`). **Edit `home/darwin/karabiner.nix` to change
the config; do not use the UI.** Same posture as Ghostty
(`home/darwin/ghostty.nix`).

**Pkg-shaped Sparkle ≠ silent.** Unlike Ghostty's `.zip`-enclosure
Sparkle path, Karabiner's `.dmg`-enclosure-with-`sparkle:installationType="package"`
path **cannot be silent** per Sparkle's own docs. SU\* keys are
honest hedges, not a silent posture. Tailscale's pkg-bearing path
is the closest precedent in this repo.

**macOS Ventura floor.** Cask `depends_on macos: ">= :ventura"`
for v16.x. Not a constraint for mac-mini (current OS).

**Conflict with macOS native caps-lock remap.** macOS's System
Settings → Keyboard → Modifier Keys lets you remap caps_lock
system-wide. Karabiner intercepts at a lower layer (DriverKit)
and wins. To avoid confusion: leave the macOS setting at "Caps
Lock" (default) — Karabiner handles the remap exclusively.

**Empty `global` + `complex_modifications.parameters` blocks are
defensive.** `home/darwin/karabiner.nix` ships both as empty
attrsets even though the current single-rule config doesn't need
them. Karabiner-Elements writes default values into these keys on
first launch if absent — which would fail against the read-only
symlink and surface a UI error. Pre-populating neutralizes the
normalization. A future rule using `to_if_alone` (e.g. the
"caps_lock tap → Escape, hold → Hyper" common extension) or
`simultaneous` key chords adds its parameter overrides to the
existing `parameters = { }` block — no shape changes elsewhere.

**The system extension is shared between updates.** When Karabiner
self-updates via Sparkle, the DriverKit extension may need
re-approval if its signed bundle changes. macOS surfaces its
own system-extension authorisation prompt on each such update,
independent of Sparkle's admin prompt. Not suppressible from
this layer; expect occasional Apple prompts beyond the Sparkle
admin prompt.

**Bundle ID layering.** The runtime app bundle is
`org.pqrs.Karabiner-Elements`; the Sparkle updater plist is
`org.pqrs.Karabiner-Elements.Updater.plist`; the DriverKit
extension is `org.pqrs.Karabiner-DriverKit-VirtualHIDDevice`;
the EventViewer companion app is `org.pqrs.Karabiner-EventViewer`.
Use the *main app* bundle ID for SU\* keys.

**`karabiner_cli` lives outside `/Applications/`.** The cask
binary stanza points at
`/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli`
— wired onto PATH by the cask. Available for scripting (e.g.
`karabiner_cli --select-profile <name>`) once the cask is
installed.

## References

- [ADR-031](../decisions/ADR-031-nix-homebrew-boundary.md) —
  boundary rule placing Karabiner on the Mac via cask under
  clause 2; this doc owns the carve-out justification.
- [`docs/desktop/keybinds.md`](./keybinds.md) — bind manifest
  covering both the Karabiner-implemented Hyper modifier
  (caps_lock → ⌘⌃⌥⇧) and the Hyper-anchored Mission Control
  binds (`Hyper+Arrow`, `Hyper+1`..`9`) layered on top via
  additional `complex_modifications.rules`.
- Homebrew `karabiner-elements` cask source (pkg installer,
  DriverKit uninstall block, Sparkle livecheck) —
  https://github.com/Homebrew/homebrew-cask/blob/master/Casks/k/karabiner-elements.rb
- Karabiner-Elements complex_modifications reference —
  https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/
- Sparkle package-updates docs (`.pkg`-vs-`.zip` enclosure
  semantics — why pkg-enclosure cannot be silent) —
  https://sparkle-project.org/documentation/package-updates/
