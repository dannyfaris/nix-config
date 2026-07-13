# Foot

Wayland-native terminal emulator. Lightweight, minimal closure, used
on Linux desktop hosts. On macOS clients, Ghostty is the chosen
terminal.

## Selection

**foot** on metis. Enabled via `home/nixos/foot.nix` (HM module
`programs.foot.enable = true`). Colours come from Noctalia, not Stylix
(ADR-036, #385) — see Configuration.

The terminfo entry `xterm-ghostty` ships on every NixOS host via
`modules/nixos/ghostty-terminfo.nix` so SSH'ing from a Ghostty-on-Mac
terminal into any Linux host renders cleanly. Darwin hosts can't
ship the entry from nixpkgs (`pkgs.ghostty` is Linux-only); inbound
Ghostty SSH into neptune relies on Ghostty's shell-integration
ssh-terminfo push or falls back to `xterm-256color`. Foot's own
terminfo is in the standard ncurses database — no module required.

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

**HM module** — `home/nixos/foot.nix` sets the font, `dpi-aware`, and an `include` pointing at the theme-menu conductor's per-target resolved symlink (ADR-044, #609):

```nix
programs.foot = {
  enable = true;
  settings.main = {
    font = "monospace:size=${toString profile.fonts.terminal}";
    "dpi-aware" = "no";
    include = "~/.local/state/theme-menu/foot.ini";
  };
};
```

**Theming is the theme-menu conductor's** (ADR-044, #609 — replacing Noctalia per ADR-036). The Stylix `foot` target remains removed; foot's colours come from `~/.local/state/theme-menu/foot.ini`, a symlink managed by `home/nixos/theme-menu.nix`'s seed activation and the `theme` CLI. We declare the `include` ourselves — the seed guarantees the path exists before any foot window can spawn (foot exits 230 on a missing include). The font face resolves via the `monospace` fontconfig generic (the runtime font conductor, #390); the size comes from the active display profile (`lib/display-profiles.nix` — size 8 at metis's 2×); `dpi-aware = "no"` is set here to preserve pt-based sizing.

**[colors-dark] convention:** the theme-menu renders BOTH polarities under a `[colors-dark]` section header — foot's active section never flips; the conductor swaps the file content. **Never set `initial-color-theme = light`** anywhere in foot's config: doing so would invert the `[colors-dark]`-header convention and render the wrong polarity's colours. This guard is documented in `home/nixos/foot.nix` (R4 guard comment) and enforced by convention, not a lint gate. See `home/nixos/theme-menu.nix` §renderFoot.

## Sharp edges

**`dpi-aware = "no"` is a Stylix default**, inherited from
foot 1.15.0's upstream default change (the toggle flipped from
`auto` to `no` in that release). Under this default, the `:size=N`
points value is multiplied by the compositor scale rather than the
monitor DPI. This is exactly what lets the display profile own the
terminal's sizing: `stylix.fonts.sizes.terminal` is set from the
active profile in `modules/nixos/desktop-fonts.nix` (size ∝ 1/scale,
holding apparent size), so a scale change retunes the size in one
place (PR #63 landed the original pin; #106 made it profile-driven).
The lever is Stylix's font surface, NOT
`programs.foot.settings.main` (which would conflict with the
Stylix-set values). Full story in [fonts.md](./fonts.md) §"Sharp
edges".

**Font-availability dependency.** Foot reads
`stylix.fonts.monospace.name` ("MonaspiceAr Nerd Font") and asks
fontconfig for it. If the package isn't installed (the gap that
surfaced post-#69 baseline), fontconfig substitutes to whatever it
has — historically DejaVu Sans (proportional), triggering foot's
"font does not appear to be monospace" warning. Resolved by the
two-wires fix in [fonts.md](./fonts.md) — the install wire
(`fonts.packages = config.stylix.fonts.packages`) plus the
fontconfig-target wire (`stylix.targets.fontconfig.enable = true`).
Durable fix lives in fonts.md.

**Cross-platform SSH context.** SSHing from a Ghostty-on-Mac
terminal into metis triggers `TERM=xterm-ghostty`; NixOS hosts
recognise this because `modules/nixos/ghostty-terminfo.nix` ships
the entry on every NixOS host. If that module ever gets removed,
SSH from Ghostty clients into this host falls back to
`xterm-256color` with reduced rendering fidelity. The module lives
under `modules/nixos/` (not `modules/shared/`) because
`pkgs.ghostty.meta.platforms` is Linux-only — Darwin hosts can't
ship the entry from nixpkgs (see #167 for the move rationale).

## References

- [ADR-028](../decisions/ADR-028-stylix-foundation-and-desktop-env.md)
  §History "Terminal swapped from Ghostty to Foot (2026-05-28)" — the
  original swap decision; rationale for Foot on Linux + Ghostty
  retention on macOS.
- [ADR-029](../decisions/ADR-029-niri-only-desktop.md) — Stylix/foot
  integration preserved through DMS retraction.
- [`home/nixos/foot.nix`](../../home/nixos/foot.nix) — the
  HM module enabling foot.
- [`modules/nixos/ghostty-terminfo.nix`](../../modules/nixos/ghostty-terminfo.nix)
  — terminfo for the Ghostty-on-Mac → NixOS SSH path. (NixOS-only;
  Darwin hosts use Ghostty's client-side ssh-terminfo push instead.)
- [noctalia.md](./noctalia.md) — Noctalia owns foot's colours (ADR-036,
  #385); the Stylix `foot` target was removed.
- [fonts.md](./fonts.md) — font configuration that affects foot's
  appearance + the DejaVu fallback warning that surfaced + the
  dpi-aware nuance.
- [keybinds.md](./keybinds.md) — `Mod+Return` → spawn foot.
- foot upstream — https://codeberg.org/dnkl/foot
