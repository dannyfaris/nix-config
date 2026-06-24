# keyd

Key-remapping daemon for Linux. Picked as the **metis-side realization of the Hyper modifier** from [keybinds.md](./keybinds.md): keyd remaps `caps_lock` to the Hyper base, `Ctrl+Alt` ([ADR-039](../decisions/ADR-039-capability-registry.md) §3). The modifier set is read from the single-source capability registry (`lib/capabilities.nix`, `tiers.hyper.linux`), the same constant the niri emitter consumes — so the base shape is one edit (ADR-039 §4).

This is **parity-not-identity** with neptune's macOS Hyper (ADR-039 §3): same UX — Caps Lock becomes a layer with `Shift`/`Super` free to stack as escalators — but each platform uses its best-fit chord (Linux `Ctrl+Alt`, macOS `Ctrl+Opt`). The macOS counterpart migrates to `Ctrl+Opt` in the macOS emitter phase (#440); until then neptune still produces the pre-cutover all-four `Super+Ctrl+Alt+Shift`, so the two hosts' bases differ in the interim.

Scope: keyd produces the Hyper *modifier*; the chord→action binds are generated from the registry (`home/nixos/niri.nix` consumes `caps.niriBinds`) and recorded in [keybinds.md](./keybinds.md). keyd owns substrate production only — the registry owns chord→action (ADR-039 §4).

## Selection

**keyd** (`services.keyd`, a system-level daemon), configured in `modules/nixos/keyd.nix` and imported via the system desktop-env bundle (`modules/nixos/bundles/desktop-env.nix`). It maps `caps_lock` to a `hyper` modifier-layer that holds `Ctrl+Alt` while held; a bare Caps Lock tap emits nothing (matching the mac, where Hyper alone is inert).

keyd remaps at the **evdev layer**, below libinput and the compositor, so the modifier is realized identically everywhere the keyboard is read — niri, the greetd greeter, and any TTY. That is the Linux parallel to Karabiner's DriverKit layer on the mac: a thin, transparent layer beneath the application stack rather than a per-app shim.

## Rationale

**It's the tool the taxonomy already chose.** keybinds.md realizes the Hyper layer via "keyd or equivalent" on Linux; keyd is in our nixpkgs pin, has a first-class NixOS module, and is the minimal single-purpose daemon for exactly this job — a thin transparent layer, not a programmable input engine (see Alternatives → kanata).

**Parity-not-identity, not a four-modifier mirror.** An earlier design made keyd emit the mac's exact `⌘⌃⌥⇧` chord (`Super+Ctrl+Alt+Shift`) so the modifier *state* matched on both platforms. ADR-039 §3 superseded that: the base is now `Ctrl+Alt`, deliberately minimal so `Shift` and `Super` stay free as escalators. The objective is UX parity (Caps → a layer + the same escalators + the same action per chord), not an identical modifier set — each platform uses its best-fit chord (Linux `Ctrl+Alt`, macOS `Ctrl+Opt`). The base-shape rationale is single-sourced in ADR-039 §3 and the [hyper-layer-redesign note](../research/hyper-layer-redesign.md); keyd just produces the Linux side of it.

**It stays clear of niri's other binds.** niri matches the *exact* set of modifiers on a bind. The registry's Hyper chords are `Ctrl+Alt+<key>` (plus `Shift`/`Super` escalators); the hand-authored remainder is `Mod`, `Mod+Shift`, or the `Print` family — disjoint modifier sets, so no collision (the registry's own collision lint enforces this within the Hyper layer, ADR-039 §8). The one inherited reservation: `Ctrl+Alt+F1‑12` is the kernel VT switch, so the F-row is never bound — enforced from day one by the lint.

**Evdev-level, and recoverable.** Because keyd sits below the compositor, the modifier works at the greeter and in TTYs too, and niri needs no special config. keyd is resilient rather than fail-closed: a syntactically bad binding is logged and skipped rather than aborting the daemon, and if a config ever does wedge input, keyd ships an in-kernel escape — the `backspace+escape+enter` chord terminates keyd and restores raw input. Combined with this change touching only `caps_lock`, the exposure is bounded and recoverable at the physical console.

**Desktop-only by placement.** Wiring keyd through the system desktop-env bundle means only desktop hosts get the remap; headless hosts (mercury) — which import no desktop bundle — are untouched. A future Linux desktop host (mothership) inherits it for free.

## Alternatives considered

**niri xkb `caps:hyper`** — set `input.keyboard.xkb.options = "caps:hyper"` in niri, no new tool at all. Passed over: it maps Caps Lock to the single `Hyper_L` keysym, not the `Ctrl+Alt` modifier combo the registry emits and niri binds. `Hyper_L` as a distinct modifier is unevenly surfaced across GTK/Qt toolkits, and it would only cover niri (xkb is compositor-scoped) — not the greeter or TTYs that keyd's evdev-layer remap reaches. The no-new-tool appeal is real, but it doesn't produce the base the cross-platform layer is built on.

**xkb `caps:super` / native single-modifier remaps** — makes Caps Lock just another Super (or Ctrl). Doesn't create a distinct namespace at all — the same reason karabiner.md rejected macOS's native "Caps Lock → Control" remap. Insufficient for the philosophy.

**keyd with tap-Escape (`overload(hyper, esc)`)** — the popular "tap Caps = Escape, hold = Hyper." Deliberately *not* adopted, to stay in lockstep with the mac, which is hold-only today (karabiner.md flags `to_if_alone` tap-Escape as a future *symmetric* extension, not a current one). If tap-Escape is ever wanted, it should land on both platforms together so parity holds.

**kanata** — a more capable (QMK-like, layers/tap-hold/chords) Rust remapper. Heavier and more configuration surface than this single mapping needs; keyd's one-line remap is the thin transparent layer, the same minimalism that picked a single Karabiner rule over Goku/Hammerspoon-for-remaps on the mac side. Its one apparent edge — a single remapper for both hosts — is weaker than it looks: kanata on macOS runs *on* Karabiner's DriverKit driver, so adopting it would not even remove the Karabiner dependency (and nixpkgs ships no nix-darwin module), trading two short single-purpose configs for one tool plus a hand-rolled root daemon. Revisit only if the remap needs grow into real layering — the one case where kanata's shared layered/leader DSL across both platforms would justify that macOS cost.

## Configuration

`modules/nixos/keyd.nix` enables `services.keyd` with one keyboard entry matching all devices and the Caps-Lock→Hyper mapping:

```nix
services.keyd = {
  enable = true;
  keyboards.default = {
    ids = [ "*" ];
    settings = {
      main.capslock = "layer(hyper)";
      # The `hyper` layer holds Ctrl+Alt while Caps Lock is down (keyd
      # letters C=Ctrl, A=Alt). The layer name (`hyper`) and its modifier
      # suffix (`:C-A`) are derived from the registry's `tiers.hyper.linux`
      # constant, not hand-written, so the base shape is one edit. An empty
      # section whose header carries the modifiers is keyd's idiom for a
      # custom modifier layer; toINI renders `"hyper:C-A" = { }` as a bare
      # `[hyper:C-A]` header, keeping the whole config in the typed
      # `settings` surface (no extraConfig needed).
      ${hyperLayer} = { };
    };
  };
};
```

`capslock = layer(hyper)` is deliberately *not* the more common `overload(hyper, esc)`: `layer` gives a hold-only Hyper with an inert tap, whereas `overload` would add a tap-Escape the mac doesn't have (see Alternatives). Imported by `modules/nixos/bundles/desktop-env.nix` alongside `niri.nix` / `greetd.nix`. niri Hyper binds are written as `Ctrl+Alt+<key>` (plus `Shift`/`Super` escalators) and generated from the registry in `home/nixos/niri.nix`, not authored here.

The load-bearing choice recorded here is the mapping (`caps_lock → Ctrl+Alt`, hold-only); the modifier set itself comes from the registry, and the module surface is verified against `services.keyd` at build time. keyd resolves layers by name, so section order in the generated file doesn't matter.

## Sharp edges

**Validate the modifier directly.** Confirm the remap works on first activation with `sudo keyd monitor` (hold Caps Lock, watch `Ctrl`+`Alt` report) or a Wayland event viewer (`wev`) inside niri — don't assume it landed just because activation succeeded. (`services.keyd` wires only the daemon, so this module adds `pkgs.keyd` to `environment.systemPackages` to put the `keyd` CLI — `monitor`, `reload` — on `PATH`.) **On-box AltGr verify (#384, ADR-039 §Implementation):** bare `Ctrl+Alt` is the known-good base; whether to pad the chord with `ISO_Level3_Shift` (AltGr) for extra collision insulation is decided by a one-off check at the physical metis keyboard — bind `ISO_Level3_Shift+<key>` and confirm the keyd-Hyper chord delivers it (hyper-layer-redesign §12). If fussy, plain `Ctrl+Alt` stands.

**Break-glass sits behind this remap — verify login still works.** metis break-glass is the physical console (CLAUDE.md §Break-glass), and keyd remaps at evdev *including the greeter and TTYs*. Two things bound the risk: only `caps_lock` is touched (every other key passes through), and keyd ships an in-kernel panic escape — `backspace+escape+enter` terminates keyd and restores raw input at the console (keyd upstream). keyd does *not* fail closed (a bad binding is logged and skipped, not a refusal to start), so the first activation should be verified by actually logging in at the console, not trusted blind.

**No double-remap.** Leave niri's `input.keyboard.xkb` Caps Lock handling at default — keyd owns the remap exclusively. Setting an xkb `caps:*` option *and* keyd would fight. (Mirror of karabiner.md's "leave the macOS native Caps Lock remap at default" edge.)

**Hold-only, no tap action (parity).** A bare Caps Lock tap is intentionally a no-op, matching the mac. If a tap-Escape (or tap-anything) is ever added, add it on both platforms together so Hyper stays symmetric.

**`ids = [ "*" ]` matches every keyboard.** keyd excludes its own virtual device, so this is the normal catch-all. (Upstream notes `*` also matches some keyboard-emitting mice, e.g. the Logitech MX Master — harmless for a Caps-Lock-only map, but the reason to scope by device id if a future binding ever touches keys a mouse can emit.)

## References

- [ADR-039](../decisions/ADR-039-capability-registry.md) — the capability-registry architecture; §3 fixes the Hyper base shape (`Ctrl+Alt`, parity-not-identity), §4 the substrate boundary this doc sits on.
- [keybinds.md](./keybinds.md) — the Hyper taxonomy this realizes; its §Implementation-status records the Linux cutover to the `Ctrl+Alt` base.
- [karabiner.md](./karabiner.md) — the neptune-side parallel; its Hyper migrates to `Ctrl+Opt` in the macOS emitter phase (#440), still the pre-cutover all-four until then.
- `home/darwin/karabiner.nix` — the `capsLockToHyper` rule (pre-cutover; migrates under #440).
- `modules/nixos/keyd.nix` — the implementation; `modules/nixos/bundles/desktop-env.nix` — where it is imported.
- keyd upstream (modifier layers, `ids`, `monitor`, the `backspace+escape+enter` recovery) — https://github.com/rvaiya/keyd
- niri key-binding resolution (exact-modifier matching) — https://github.com/YaLTeR/niri/wiki/Configuration:-Key-Bindings
- ADR-028 (desktop foundation), ADR-029 (niri-only desktop).
