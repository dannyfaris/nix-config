# Audio playback and volume control

The sound stack for the niri desktop on metis (#96): a sound server so applications can produce audio at all, plus the surfaces to drive it — quick volume/mute, media transport, a status-bar indicator, and a graphical mixer for routing. metis had no audio configuration of any kind before this; the desktop was silent. Bluetooth audio and patchbay-style graph routing (app-output into app-input) are out of scope — see Sharp edges.

## Selection

The stack is intentionally split across the layers it belongs to — a system-level sound server, and home-level control surfaces:

- **Sound server: PipeWire + WirePlumber** — `services.pipewire` (`alsa.enable`, `pulse.enable`) with WirePlumber as the session manager, plus `security.rtkit.enable = true`. System-level, in a new `modules/nixos/audio.nix` wired into the system `desktop-env` bundle beside `niri.nix` / `greetd.nix`.
- **Volume / mute / media / brightness: niri binds → `noctalia msg <verb>`** (Option B, settled 2026-07-31). The `XF86Audio*` / `XF86MonBrightness*` hardware keys are bound in `lib/niri-config.nix` to Noctalia's v5 IPC verbs (`volume-up`/`volume-down`/`volume-mute`/`mic-mute`/`media {toggle,next,previous}`/`brightness-up`/`brightness-down`) rather than to `wpctl`/`playerctl`, so Noctalia's native OSD owns the presentation surface. See §Rationale for the A-vs-B decision. (Original decision was Option A — `wpctl` for volume/mute, `playerctl` for media transport; superseded below.)
- **Status-bar surface: waybar's native `wireplumber` module**, added to `modules-right` in `home/nixos/waybar.nix`.
- **Graphical mixer: `pwvucontrol`** (native-PipeWire, GTK4/libadwaita), a `home.packages` addition, for per-app/per-device routing and microphone selection.

## Rationale

**PipeWire + WirePlumber is the convention, not a contested choice.** It is the NixOS default sound server and the universal stack across modern Wayland desktops (niri, Sway, Hyprland). PulseAudio is the previous generation; bare ALSA can only really serve one client at a time with no per-app volume or live device switching. `pulse.enable = true` is the compat shim that lets PulseAudio-era applications run unchanged against PipeWire, and `alsa.enable` provides the ALSA compatibility layer. `security.rtkit.enable = true` is the NixOS-recommended companion: it lets PipeWire request realtime scheduling, and omitting it produces real journal warnings and lost scheduling priority (PulseAudio used to enable rtkit implicitly; PipeWire does not).

**An explicit module owns what the nixpkgs baseline only defaults.** nixpkgs' `services.graphical-desktop` enables `services.pipewire` (with alsa/pulse) via `lib.mkDefault` on any host with a display manager — the trigger is `services.displayManager.enable` / `services.xserver.enable` (greetd here), not Wayland-ness — so PipeWire is *present* without any repo module. But present-by-default is unowned: nothing in the repo asserts it, an upstream default change would drop it silently, and the baseline leaves rtkit off entirely. `modules/nixos/audio.nix` turns the baseline into an owned guarantee: a normal-priority `enable = true` that merges over the mkDefault, plus the rtkit companion.

**Choosing PipeWire now is forward-compatible with #101.** Screen sharing goes through the xdg-desktop-portal screencast path, which runs over PipeWire. Selecting it here means the call/screen-share work later has its foundation already in place rather than bolting on a second audio decision.

**Media keys go to Noctalia's IPC (Option B), settled 2026-07-31.** The original selection was **Option A** — bind the `XF86Audio*` keys to `wpctl` (volume/mute) and `playerctl` (media transport), adopted verbatim from niri's [default `config.kdl`](https://github.com/YaLTeR/niri/blob/main/resources/default-config.kdl). That predated the move to the Noctalia v5 shell, which owns the on-screen volume/brightness OSD natively, so #668 re-opened the choice as A-vs-B:

- **Option A** — niri binds → `wpctl` / `playerctl`. Noctalia's OSD shows the change only if it reacts to external WirePlumber/backlight state.
- **Option B** — niri binds → `noctalia msg <verb>`, driving the shell's own OSD through its documented IPC.

A v5-capability probe on alnair decided it. `noctalia msg` **does** expose the volume/brightness/media verbs (`volume-up`/`volume-down`/`volume-mute`/`mic-mute`/`media`/`brightness-up`/`brightness-down`), and its OSD fires on them. The probe **also** found Noctalia's OSD reacting to *external* `wpctl` and `brightnessctl` changes — so Option A was genuinely viable, not a fallback. **Option B was chosen on the merits:** a documented IPC contract beats undocumented reactive behaviour that could regress silently on a shell bump, and it keeps a single owner of the presentation surface (the shell drives its own OSD directly rather than inferring state after the fact). The `XF86Audio*` / `XF86MonBrightness*` keys are dedicated hardware keys outside the curated Mod/Hyper namespaces, so these binds cost nothing against the namespace budget — they land via the keybinds.md doc-before-code cadence like every other bind. Keyboard-backlight keys are out of scope: no OS-side `kbd_backlight` device exists on alnair.

**waybar's native `wireplumber` module talks WirePlumber directly.** No Pulse shim in the readout path, consistent with the rest of the stack. The historical reason to prefer waybar's older `pulseaudio` module was feature gaps in the `wireplumber` one — and on our pinned waybar (0.15.0) those are closed: source/microphone volume landed in 0.14.0 (Waybar #3983), and the module exposes per-state style classes (`#wireplumber.muted` / `.sink-muted` / `.source-muted`) for mute-state coloring. It inherits the bar's base16 palette, text color, and font from the existing `stylix.targets.waybar` write, so it needs no new theming. The mute state is signalled by the **glyph swap**, not a color change: Stylix's per-module background/mute coloring lives in its `colors.nix`, gated behind `enableRightBackColors` (off by default and unset here). That toggle is left off deliberately — it repaints the *entire* right cluster into colored "pill" backgrounds (an all-or-nothing per-cluster restyle, not scoped to audio), which would change the bar's whole aesthetic. The bar stays monochrome here; the colored-pill direction is a whole-desktop visual-identity decision reserved for the north-star (#108), not something the audio work reaches into.

**`pwvucontrol` keeps every audio surface native.** A graphical mixer earns its place for the things the keys and the bar cannot do: switching output device (the ProDesk Mini exposes both an analog jack and DisplayPort/HDMI audio — see Sharp edges), per-app volume, selecting and levelling a microphone (with live meters — directly useful for #101), and triaging "no sound" by seeing every stream and device at once. `pwvucontrol` speaks libpipewire directly, so the control GUI stays on the same native path as `services.pipewire`, `wpctl`, and the waybar `wireplumber` module rather than reaching back through `pipewire-pulse`. It needs no Stylix per-app target (none exists for any mixer); it follows polarity via the existing `home/nixos/portal-color-scheme.nix` bridge and picks up the base16 accent/background from Stylix's default `gtk` target write (`gtk-4.0/gtk.css` named colors — that target is enabled by default and active on metis, so no new wiring is added).

## Alternatives considered

**PulseAudio (the server).** The previous-generation sound server, now legacy. PipeWire supersedes it with one server covering ALSA/Pulse/JACK compatibility, native Wayland-era screencast support, and the NixOS default status. No reason to choose the older server on a greenfield desktop.

**waybar's `pulseaudio` module (the bar readout).** Some users run it even on PipeWire (via the shim) to dodge historical `wireplumber`-module gaps. On our pinned waybar those gaps are closed, so the only thing the `pulseaudio` module would add is a dependency on the Pulse compat path for a readout that can talk WirePlumber natively. Recorded as a historical fallback, not a recommendation.

**`pavucontrol` (the GUI mixer).** The mature, long-standing freedesktop GTK3 mixer — and, honestly, it themes *more completely and stably* under Stylix than `pwvucontrol` does. Both toolkits receive the identical Stylix CSS, but GTK3 apps honour the full widget theme (widget shapes *and* the base16 colors together), whereas libadwaita ignores the widget theme and consumes only the `@define-color` named colors — keeping Adwaita's widget shapes — and arbitrary libadwaita theming is officially unsupported by GNOME. It was the closest call in this selection. It was passed over because it reaches the server through the `pipewire-pulse` shim — making it the one control surface not on the native path — and because the mixer is an occasional/triage tool rather than the daily driver (the everyday path is `wpctl` + the waybar module), so the theme-fidelity gap costs less than it would for an always-visible surface. The decision is also a trivially reversible one-line `home.packages` swap. `pavucontrol` remains the documented fallback if `pwvucontrol`'s pre-1.0 maturity or partial theming bites.

## Configuration

**System — `modules/nixos/audio.nix`** (wired into `modules/nixos/bundles/desktop-env.nix`, the import-only system bundle, beside `niri.nix` / `keyd.nix` / `greetd.nix`):

- `security.rtkit.enable = true`.
- `services.pipewire.enable = true` with `alsa.enable = true`, `pulse.enable = true`; WirePlumber is the default session manager and needs no extra enable. `alsa.support32Bit` is deliberately omitted — no 32-bit audio application (Steam/Wine-class) is anticipated on this dev box, so it stays off per the whitelist stance until one is.

**Home — control surfaces:**

- `lib/niri-config.nix` — nine hardware-key spawn binds → `noctalia msg <verb>` (Option B): three volume keys (`RaiseVolume`/`LowerVolume`/`Mute` → `volume-up`/`volume-down`/`volume-mute`), `MicMute` → `mic-mute`, three media keys (`Play`/`Next`/`Prev` → `media toggle`/`media next`/`media previous`), and two brightness keys (`MonBrightnessUp`/`MonBrightnessDown` → `brightness-up`/`brightness-down`), each with a row in `docs/desktop/keybinds.md`. `allow-when-locked` sits on the speaker-volume trio only (the lock-screen volume case). The spawned binary is store-pinned via `lib.getExe config.programs.noctalia.package`, matching the `spawn-at-startup` idiom, so nothing depends on session PATH. Landing them flips that doc's "Hardware & media keys" section from *unbound pending tooling* to bound.
- `home/nixos/waybar.nix` — add `wireplumber` to `modules-right` and configure it: `format` = `{icon} {volume}%`, `format-icons` from the **Material Design** set (`󰕿` low / `󰖀` medium / `󰕾` high), `format-muted` = `󰸈`, plus `scroll-step` and `on-click` to launch `pwvucontrol`. The MD set is chosen over Font Awesome for a rounder, more modern read; glyph coverage is verified visually on metis (eval can't check it). Lift the existing "No audio module" note from the module comment.
- `pwvucontrol` as a `home.packages` entry (no service, no module surface), following the `cursor-ide.nix` pattern.

**waybar layout coordinates with #98.** On `main` today `modules-right = [ network, tray, clock ]`; the in-flight power/session work (#98, `desktop/power-session-impl`, pushed but unmerged) prepends a `custom/power` glyph to the *same* list. Both changes edit `modules-right`, so whichever merges second reconciles the order — the intended end-state is `[ custom/power, wireplumber, network, tray, clock ]` (power glyph leading the cluster, audio next, clock rightmost per the macOS top-right convention). This is a deliberate one-time ordering call, recorded here so the second merge is a conscious reconcile rather than a conflict surprise.

**Theming needs no new wiring.** The waybar module rides the existing `stylix.targets.waybar`; `pwvucontrol` rides the existing `portal-color-scheme.nix` (polarity) and the default-on `gtk` target (base16 named colors). No new Stylix target is added.

## Sharp edges

**`rtkit` is load-bearing, not cosmetic.** Without `security.rtkit.enable`, PipeWire cannot acquire realtime scheduling and logs warnings on every session start. It is part of the recommended baseline, not an optional extra.

**`pulse.enable` is required for the long tail of apps.** Many applications still speak only the PulseAudio client API; `pulse.enable = true` provides the `pipewire-pulse` server they connect to. Leaving it off would silently break those apps even though PipeWire itself is running.

**The default output device on first boot may be the wrong one.** metis drives the LG UltraFine over DisplayPort (DP-1), so PipeWire may pick the *monitor's DisplayPort audio* as the default sink — which has no usable speakers — rather than the ProDesk's analog jack (or whatever is actually wired for sound). "No sound" on first activation is therefore as likely to be a default-sink-selection problem as a driver problem. First-activation check: `wpctl status` lists every sink; set the right default with `wpctl set-default <id>` (or click it in `pwvucontrol`). This device-routing reality is the strongest day-one justification for shipping the GUI mixer rather than deferring it.

**`pwvucontrol` is pre-1.0 and themes partially.** It is early-stage (0.5.x in our pin) and gets only libadwaita's partial Stylix theming (the named-color subset — see §Alternatives considered for the GTK3-vs-libadwaita mechanism). The accepted trade is native-stack consistency for a tool opened occasionally; `pavucontrol` (GTK3, fuller and more stable theming, more mature) is the fallback if this bites.

**Microphone selection lives in the GUI, not the bar.** The waybar `wireplumber` module mutes/shows the default source but does not let you choose among multiple mics or watch an input meter — that is `pwvucontrol`'s job, and the reason it matters for the #101 calls work.

**Verify sound on metis before trusting it.** Build-time eval cannot confirm the card is driven or the glyphs render. First activation should be checked on the box: `wpctl status` shows the sink/source graph, a test stream confirms output, the media keys + waybar readout confirm the control path, and the MD volume glyphs render in the bar font. metis break-glass is the physical console, so the `pwvucontrol` triage view is the fastest way to diagnose a misrouted or muted stream on the machine itself.

**Not a patchbay.** `pwvucontrol` (and `pavucontrol`) are mixers — per-app/device volume and routing to a sink. Routing one app's output into another app's input is a patchbay concern (`qpwgraph` / `helvum`), out of scope here and added only if that need ever appears.

**Bluetooth audio is out of scope here.** BlueZ runs on every desktop host (`hardware.bluetooth` via the desktop-env bundle, #773), and no explicit `services.pipewire` Bluetooth config is wired — none proved necessary: WirePlumber's stock bluez monitor covers A2DP on its own (verified on alcyone). The capability, its surfaces and its sharp edges live in [bluetooth.md](./bluetooth.md).

## References

- NixOS wiki — PipeWire (`services.pipewire`, `security.rtkit.enable`, the recommended config block).
- niri default config — the upstream `wpctl` / `playerctl` `XF86Audio*` binds ([resources/default-config.kdl](https://github.com/YaLTeR/niri/blob/main/resources/default-config.kdl); nine keys, all `allow-when-locked`), the reference point for the superseded Option A.
- Waybar `wireplumber` module wiki; Waybar #3983 (source volume, closed-completed, shipped 0.14.0). Our pin: waybar 0.15.0.
- `pwvucontrol` (saivert) — native-PipeWire GTK4/libadwaita mixer (0.5.2 in our pin); `pavucontrol` — the freedesktop GTK3 fallback.
- [keybinds.md](./keybinds.md) — the `XF86Audio*` rows land here first (Hardware media keys section, which already anticipates these binds).
- [waybar.md](./waybar.md) — the bar this adds a module to; #98 (`custom/power`) is the in-flight change `modules-right` coordinates with.
- [screen-lock.md](./screen-lock.md) — the same minimal/native posture, applied to the lock surface.
- #101 — screen sharing / calls; the PipeWire foundation here is its prerequisite, and the mic-metering case for `pwvucontrol`.
- ADR-028 (Stylix as surface source-of-truth), ADR-029 (niri-only desktop).
