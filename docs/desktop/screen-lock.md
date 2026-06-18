# Screen lock and idle handling

> **Decommissioned 2026-06-18** ([ADR-036](../decisions/ADR-036-noctalia-shell-linux-desktop.md), #385). swaylock + swayidle were removed; Noctalia owns the lock surface and idle handling (lock-on-idle, displays-off, lock on Noctalia-initiated suspend) — see [noctalia.md](./noctalia.md). One guarantee was deliberately *not* carried over: lock on an externally-initiated `systemctl suspend` (noctalia.md §Sharp edges, "Accepted gap"). This document is retained as the selection record for the swaylock/swayidle era and the fallback for any non-Noctalia host.

Automatic session locking and idle behaviour for the niri desktop on metis (#97). Covers the *unattended* path — lock on idle, displays off on deeper idle, and lock before the system sleeps. Deliberate user actions (a "lock now" keybind, suspend/reboot/logout controls) are out of scope here and belong to the power-and-session-controls work (#98).

## Selection

**swaylock** (locker) + **swayidle** (idle daemon), wired home-manager-only in `home/nixos/screen-lock.nix`, imported via the desktop-env home bundle. Idle policy:

- **5 min idle → lock** (`swaylock`).
- **10 min idle → displays off** (`niri msg action power-off-monitors`; restored with `power-on-monitors` on resume).
- **before sleep → lock**, so resuming from suspend always lands on the lock screen.

swaylock is themed by Stylix (`stylix.targets.swaylock.enable` in `home/nixos/stylix-targets-desktop.nix`), so the lock screen follows the host palette like the rest of the surface.

## Rationale

**Same minimal, wlroots-lineage posture as the rest of the chrome.** foot, fuzzel, and fnott were chosen as small, Wayland-native tools built for the wlroots/niri lineage (the dnkl family; #72–#74). swaylock + swayidle extend that posture to the lock surface: both are mature wlroots-ecosystem tools, depend on no compositor-specific libraries, and carry a small closure. The lock screen is security infrastructure, not a place that benefits from widgets or GPU effects — minimal is the right bias.

**Both halves are first-class in home-manager and in our pinned Stylix.** `programs.swaylock` and `services.swayidle` are native home-manager modules, and Stylix ships a `swaylock` target in our pin — so theming is declarative and automatic rather than hand-wired palette colours.

**niri provides the DPMS action natively.** `niri msg action power-off-monitors` / `power-on-monitors` drive display power directly, so the idle→display-off step needs no extra tool — swayidle just calls the niri IPC action on timeout and resume.

**The lock-before-sleep hook closes the resume gap.** swayidle's `before-sleep` event runs the locker before systemd suspends, so a laptop-lid-style resume (or any wake) always requires authentication. This is the unattended-security guarantee the issue asks for, separate from *who or what* triggered the suspend.

## Alternatives considered

**hyprlock + hypridle.** A fancier lock surface (clock, widgets, GPU blur) and also Stylix-themed in our pin. Passed over: it pulls in the Hyprland library stack (`hyprlang`, `hyprutils`, `hyprgraphics`), a larger closure and a coupling to the Hyprland ecosystem that cuts against the minimal-wlroots posture every other desktop tool here follows. The extra lock-screen polish has no security value, so the closure cost isn't justified.

**gtklock.** A GTK-themed locker that would inherit the GTK Stylix target indirectly. Passed over: our pinned Stylix has **no `gtklock` target**, so theme cohesion (ADR-028's "Stylix is the source of truth for the surface") would require hand-wiring CSS from the palette — exactly the manual coupling the swaylock target avoids.

**swaylock-effects.** A swaylock fork adding blur/screenshot backgrounds. Passed over for the same reason as hyprlock's effects: visual flourish with no security benefit, and it diverges from upstream swaylock's maintenance.

## Configuration

`home/nixos/screen-lock.nix` is home-manager-only — no system module is needed:

- `programs.swaylock.enable = true` — installs swaylock and lets the Stylix target write `~/.config/swaylock/config`.
- `services.swayidle` — a systemd user service (bound to `graphical-session.target`) carrying the timeouts above plus the `before-sleep` and logind `lock` events.
- `stylix.targets.swaylock.enable = true` in `home/nixos/stylix-targets-desktop.nix` (desktop-only, co-located with the other desktop targets).

**No PAM change required.** swaylock authenticates via PAM, and NixOS already ships the `swaylock` PAM service (`/etc/pam.d/swaylock` is present on metis by default), so the classic "swaylock locks but can't unlock" lock-out does not apply here.

## Sharp edges

**Verify unlock before trusting it.** metis break-glass is the physical console (CLAUDE.md §Break-glass). A locker that grabs the session but fails to authenticate would force a TTY recovery. Although the PAM service is present, the first activation should be verified by actually locking (`loginctl lock-session` or waiting out the idle timeout) and unlocking with the account password before relying on the auto-lock.

**`niri msg` needs the niri socket in the swayidle service environment.** The display-off timeout calls `niri msg action power-off-monitors`; `niri msg` resolves the compositor via `NIRI_SOCKET`. This works because `niri-session` runs `systemctl --user import-environment` before starting `niri.service`, and swayidle is ordered `After=graphical-session.target`, so it inherits both `NIRI_SOCKET` and the session PATH (this is also why `modules/nixos/niri.nix` registers niri's systemd user units rather than relying on a PATH drop-in). If the display-off step is a no-op, an unset `NIRI_SOCKET` in the service environment is the first thing to check.

**Idle inhibitors.** swayidle honours the idle-inhibit / idle-notify protocols, so a fullscreen video or a manual inhibitor suppresses the idle timeouts as expected. Apps that don't set an inhibitor (some terminals, some players) won't — that's app behaviour, not a config gap.

## References

- niri IPC actions `power-off-monitors` / `power-on-monitors` — confirmed via `niri msg action` on metis.
- home-manager `programs.swaylock`, `services.swayidle`.
- Stylix `swaylock` target — present in this flake's pin (verified via `stylix.targets` attribute names).
- [keybinds.md](./keybinds.md) — a deliberate "lock now" bind, if added, lands there under the #98 deliberate-controls work.
- ADR-028 (Stylix as surface source-of-truth), ADR-029 (niri-only desktop).
