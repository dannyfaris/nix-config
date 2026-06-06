# keyd

Key-remapping daemon for Linux. Picked as the **metis-side realization of the Hyper modifier** from [keybinds.md](./keybinds.md)'s three-namespace philosophy: keyd remaps `caps_lock` to `Super + Ctrl + Alt + Shift` — the Linux analogue of the macOS `⌘ + ⌃ + ⌥ + ⇧` that [karabiner.md](./karabiner.md) produces on the mac-mini. This is the long-reserved "keyd-equivalent" keybinds.md kept naming; landing it makes metis's keyboard reach modifier-parity with the mac clients.

Scope: this realizes the modifier **and one first bind to validate it end-to-end** — `Hyper+Return` → foot, the metis mirror of the mac-mini's `Hyper+Return` → Ghostty (so the terminal opens on the same chord on both machines). Further Hyper binds (the #98 power menu is a natural next) follow one-per-ceremony per keybinds.md's cadence. The modifier production lives here; the bind itself is recorded in [keybinds.md](./keybinds.md).

## Selection

**keyd** (`services.keyd`, a system-level daemon), configured in `modules/nixos/keyd.nix` and imported via the system desktop-env bundle (`modules/nixos/bundles/desktop-env.nix`). It maps `caps_lock` to a `hyper` modifier-layer that holds `Super+Ctrl+Alt+Shift` while held; a bare Caps Lock tap emits nothing (matching the mac, where Hyper alone is inert).

keyd remaps at the **evdev layer**, below libinput and the compositor, so the modifier is realized identically everywhere the keyboard is read — niri, the greetd greeter, and any TTY. That is the Linux parallel to Karabiner's DriverKit layer on the mac: a thin, transparent layer beneath the application stack rather than a per-app shim.

## Rationale

**It's the tool keybinds.md already chose.** keybinds.md defines Hyper as "the combined Super+Ctrl+Alt+Shift modifier … conventionally bound to Caps Lock via keyd or equivalent," and repeatedly notes metis "awaits keyd-equivalent." keyd is in our nixpkgs pin, has a first-class NixOS module, and is the minimal single-purpose daemon for exactly this job.

**The four-modifier chord is what makes it parity, not just "a Hyper key."** The mac-mini's Karabiner rule (`home/darwin/karabiner.nix` `capsLockToHyper`) emits `left_shift` held with `left_command + left_control + left_option` — the ⌘⌃⌥⇧ chord. Mirroring that exact shape on Linux (Super+Ctrl+Alt+Shift) means the Hyper namespace is the *same modifier state* on both platforms: the mental model, the reserved namespace, and any future cross-referenced bind tables line up. A single distinct modifier (see Alternatives → xkb `caps:hyper`) would be "a hyper key" but not the same one the mac emits.

**It can't collide with niri's existing binds.** niri matches the *exact* set of modifiers on a bind. Every current bind is `Mod`, `Mod+Ctrl`, or `Mod+Shift` (see `home/nixos/niri.nix`); a Hyper chord is `Mod+Ctrl+Alt+Shift`, which matches none of them. Holding Hyper alone triggers nothing either — niri binds require a key press, and the four-modifier chord exact-matches only (future) Hyper binds. So realizing Hyper adds a clean, conflict-free namespace — exactly the property the reserved-namespace philosophy was protecting.

**Evdev-level, and recoverable.** Because keyd sits below the compositor, the modifier works at the greeter and in TTYs too, and niri needs no special config. keyd is resilient rather than fail-closed: a syntactically bad binding is logged and skipped rather than aborting the daemon, and if a config ever does wedge input, keyd ships an in-kernel escape — the `backspace+escape+enter` chord terminates keyd and restores raw input. Combined with this change touching only `caps_lock`, the exposure is bounded and recoverable at the physical console.

**Desktop-only by placement.** Wiring keyd through the system desktop-env bundle means only desktop hosts get the remap; headless hosts (mercury) — which import no desktop bundle — are untouched. A future Linux desktop host (mothership) inherits it for free.

## Alternatives considered

**niri xkb `caps:hyper`** — set `input.keyboard.xkb.options = "caps:hyper"` in niri, no new tool at all. Passed over: it maps Caps Lock to the single `Hyper_L` keysym, **not** the Super+Ctrl+Alt+Shift chord. That is a *different* modifier than the mac emits, so it isn't parity, and it diverges from keybinds.md's explicit definition of Hyper (and `Hyper_L` as a distinct modifier is unevenly surfaced across GTK/Qt toolkits). The no-new-tool appeal is real, but the whole point of this change is matching the mac's chord — which xkb `caps:hyper` cannot do.

**xkb `caps:super` / native single-modifier remaps** — makes Caps Lock just another Super (or Ctrl). Doesn't create a distinct namespace at all — the same reason karabiner.md rejected macOS's native "Caps Lock → Control" remap. Insufficient for the philosophy.

**keyd with tap-Escape (`overload(hyper, esc)`)** — the popular "tap Caps = Escape, hold = Hyper." Deliberately *not* adopted, to stay in lockstep with the mac, which is hold-only today (karabiner.md flags `to_if_alone` tap-Escape as a future *symmetric* extension, not a current one). If tap-Escape is ever wanted, it should land on both platforms together so parity holds.

**kanata** — a more capable (QMK-like, layers/tap-hold/chords) Rust remapper. Heavier and more configuration surface than this single mapping needs; keyd's one-line remap is the thin transparent layer, the same minimalism that picked a single Karabiner rule over Goku/Hammerspoon-for-remaps on the mac side. Revisit only if the remap needs grow into real layering.

## Configuration

`modules/nixos/keyd.nix` enables `services.keyd` with one keyboard entry matching all devices and the Caps-Lock→Hyper mapping:

```nix
services.keyd = {
  enable = true;
  keyboards.default = {
    ids = [ "*" ];
    settings = {
      main.capslock = "layer(hyper)";
      # The `hyper` layer holds all four modifiers while Caps Lock is
      # down (C=Ctrl, A=Alt, S=Shift, M=Meta/Super). An empty section
      # whose header carries the modifiers is keyd's idiom for a custom
      # modifier layer; toINI renders `"hyper:C-A-S-M" = { }` as a bare
      # `[hyper:C-A-S-M]` header, keeping the whole config in the typed
      # `settings` surface (no extraConfig needed).
      "hyper:C-A-S-M" = { };
    };
  };
};
```

`capslock = layer(hyper)` is deliberately *not* the more common `overload(hyper, esc)`: `layer` gives a hold-only Hyper with an inert tap, whereas `overload` would add a tap-Escape the mac doesn't have (see Alternatives). Imported by `modules/nixos/bundles/desktop-env.nix` alongside `niri.nix` / `greetd.nix`. niri Hyper binds, when they arrive, are written as `Mod+Ctrl+Alt+Shift+<key>` (niri's `Mod` is Super) — none are added in this change.

The load-bearing choice recorded here is the mapping (`caps_lock → Super+Ctrl+Alt+Shift`, hold-only); the precise module surface is verified against `services.keyd` at build time. keyd resolves layers by name, so section order in the generated file doesn't matter.

## Sharp edges

**Inert until a bind exists — validate the modifier directly.** Realizing Hyper changes nothing visible until a `Mod+Ctrl+Alt+Shift+…` bind is added. Confirm the remap works on first activation with `sudo keyd monitor` (hold Caps Lock, watch the four modifiers report) or a Wayland event viewer (`wev`) inside niri. Don't assume it landed just because activation succeeded.

**Break-glass sits behind this remap — verify login still works.** metis break-glass is the physical console (CLAUDE.md §Break-glass), and keyd remaps at evdev *including the greeter and TTYs*. Two things bound the risk: only `caps_lock` is touched (every other key passes through), and keyd ships an in-kernel panic escape — `backspace+escape+enter` terminates keyd and restores raw input at the console (keyd upstream). keyd does *not* fail closed (a bad binding is logged and skipped, not a refusal to start), so the first activation should be verified by actually logging in at the console, not trusted blind.

**No double-remap.** Leave niri's `input.keyboard.xkb` Caps Lock handling at default — keyd owns the remap exclusively. Setting an xkb `caps:*` option *and* keyd would fight. (Mirror of karabiner.md's "leave the macOS native Caps Lock remap at default" edge.)

**Hold-only, no tap action (parity).** A bare Caps Lock tap is intentionally a no-op, matching the mac. If a tap-Escape (or tap-anything) is ever added, add it on both platforms together so Hyper stays symmetric.

**`ids = [ "*" ]` matches every keyboard.** keyd excludes its own virtual device, so this is the normal catch-all. (Upstream notes `*` also matches some keyboard-emitting mice, e.g. the Logitech MX Master — harmless for a Caps-Lock-only map, but the reason to scope by device id if a future binding ever touches keys a mouse can emit.)

## References

- [keybinds.md](./keybinds.md) — the Hyper namespace this realizes; its Implementation-status table moves metis Hyper from *Reserved* to *Active* (modifier via keyd + the first bind, `Hyper+Return` → foot).
- [karabiner.md](./karabiner.md) — the mac-mini parallel; the `caps_lock → ⌘⌃⌥⇧` chord this mirrors as `Super+Ctrl+Alt+Shift`.
- `home/darwin/karabiner.nix` — the `capsLockToHyper` rule whose chord shape this matches.
- `modules/nixos/keyd.nix` — the implementation; `modules/nixos/bundles/desktop-env.nix` — where it is imported.
- keyd upstream (modifier layers, `ids`, `monitor`, the `backspace+escape+enter` recovery) — https://github.com/rvaiya/keyd
- niri key-binding resolution (exact-modifier matching) — https://github.com/YaLTeR/niri/wiki/Configuration:-Key-Bindings
- ADR-028 (desktop foundation), ADR-029 (niri-only desktop).
