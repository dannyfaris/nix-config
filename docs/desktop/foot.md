# Foot

Wayland-native terminal emulator. Lightweight, minimal closure, used
on Linux desktop hosts. On macOS clients, Ghostty is the chosen
terminal.

## Selection

**foot** on metis. Enabled via `home/nixos/foot.nix` (HM module
`programs.foot.enable = true`). Stylix integration via
`stylix.targets.foot.enable = true` in
`home/shared/stylix-targets.nix`.

The cross-platform terminfo entry `xterm-ghostty` ships on every host
via `modules/shared/ghostty-terminfo.nix` so SSH'ing from a
Ghostty-on-Mac terminal into any Linux host renders cleanly. Foot's
own terminfo is in the standard ncurses database — no shared module
required.

## Rationale

**Lightweight, fast, Wayland-native — and a clean match for niri.**
Foot's closure is small (no embedded scripting runtime, no
GPU-acceleration layer, no platform-abstraction layer); startup is
instant; the codebase is purpose-built for Wayland in the
niri/wlroots/sway lineage. Inside niri — which already does
compositor-level GPU work — the terminal doesn't need to bring its
own GPU rendering.

**Ghostty remains the operator's terminal on macOS.** This is a
deliberate Linux/Mac split, not a downgrade. ADR-028 §History
2026-05-28 records the original swap from Ghostty to Foot on Linux
desktop; Ghostty stays the chosen terminal for macOS clients (where
its features earn their weight) via the future `home/darwin/`
tree.

## Alternatives considered

**Ghostty** — original `tier3-desktop-deferred` selection; matures
release-by-release; actively maintained. Passed over for Linux desktop
for two reasons: heavier closure (Zig runtime + libuv + GPU rendering
layer); GPU-accelerated TUI features are largely redundant inside a
niri session (which already does compositor-level GPU work).
**Retained for macOS clients** — see Rationale.

**alacritty** — niri's `default-config.kdl` binds `Mod+T` to spawn
alacritty as a placeholder. Passed over because alacritty's closure
is comparable to Foot's without Foot's tighter Wayland integration.

**wezterm** — multiplatform, Lua-scriptable, feature-rich. Passed
over because the Lua scripting layer + multiplatform abstractions
aren't earning their keep for a single-OS, single-user desktop.

## Configuration

**HM module** — `home/nixos/foot.nix`:

```nix
_: {
  programs.foot.enable = true;
}
```

Minimal — all real configuration flows through Stylix targets.

**Stylix integration** — `home/shared/stylix-targets.nix`:

```nix
stylix.targets.foot.enable = true;
```

Stylix writes `programs.foot.settings.main`:
- `font = "JetBrainsMono Nerd Font:size=11"` (from
  `stylix.fonts.monospace.name` + `stylix.fonts.sizes.terminal` —
  see [fonts.md](./fonts.md))
- `dpi-aware = "no"` (Stylix's default; see Sharp edges)
- `initial-color-theme` + per-polarity colour palette from the base16
  scheme

We deliberately don't set `programs.foot.settings.main.*` directly —
Stylix is the source of truth. If a per-host or per-user override
that can't go through Stylix is ever needed, it would need to coexist
with Stylix's option-priority handling; current state has no need.

## Sharp edges

**`dpi-aware = "no"` is a Stylix default**, inherited from
foot 1.15.0's upstream default change (the toggle flipped from
`auto` to `no` in that release). Under this default, the `:size=N`
points value is multiplied by the compositor scale rather than the
monitor DPI; on a scale-1 output, the historical sizing reads
smaller. Mitigated by `stylix.fonts.sizes.terminal = 11` in
`modules/nixos/desktop-fonts.nix` (PR #63). On a HiDPI external
display the operator may want to retune. The lever is Stylix's font
surface, NOT `programs.foot.settings.main` (which would conflict
with the Stylix-set values). Full story in [fonts.md](./fonts.md)
§"Sharp edges".

**Font-availability dependency.** Foot reads
`stylix.fonts.monospace.name` ("JetBrainsMono Nerd Font") and asks
fontconfig for it. If the package isn't installed (the gap that
surfaced post-#69 baseline), fontconfig substitutes to whatever it
has — historically DejaVu Sans (proportional), triggering foot's
"font does not appear to be monospace" warning. Resolved by the
two-wires fix in [fonts.md](./fonts.md) — the install wire
(`fonts.packages = config.stylix.fonts.packages`) plus the
fontconfig-target wire (`stylix.targets.fontconfig.enable = true`).
Durable fix lives in fonts.md.

**Cross-platform SSH context.** SSHing from a Ghostty-on-Mac
terminal into metis triggers `TERM=xterm-ghostty`; Linux hosts
recognise this only because `modules/shared/ghostty-terminfo.nix`
ships the entry universally. If that module ever gets removed, SSH
from Ghostty clients into this host falls back to `xterm-256color`
with reduced rendering fidelity. The module is "shared" because it's
client-side terminfo (no Wayland dependency).

## References

- [ADR-028](../decisions/ADR-028-stylix-foundation-and-desktop-env.md)
  §History "Terminal swapped from Ghostty to Foot (2026-05-28)" — the
  original swap decision; rationale for Foot on Linux + Ghostty
  retention on macOS.
- [ADR-029](../decisions/ADR-029-niri-only-desktop.md) — Stylix/foot
  integration preserved through DMS retraction.
- [`home/nixos/foot.nix`](../../home/nixos/foot.nix) — the
  HM module enabling foot.
- [`modules/shared/ghostty-terminfo.nix`](../../modules/shared/ghostty-terminfo.nix)
  — cross-platform terminfo for the Ghostty-on-Mac SSH path.
- [`home/shared/stylix-targets.nix`](../../home/shared/stylix-targets.nix)
  — `stylix.targets.foot.enable = true`.
- [fonts.md](./fonts.md) — font configuration that affects foot's
  appearance + the DejaVu fallback warning that surfaced + the
  dpi-aware nuance.
- [keybinds.md](./keybinds.md) — `Mod+Return` → spawn foot.
- foot upstream — https://codeberg.org/dnkl/foot
