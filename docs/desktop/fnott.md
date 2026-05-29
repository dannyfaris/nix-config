# Fnott

Wayland-native notification daemon. Third member of the dnkl family
on this desktop (foot + fuzzel + fnott), under one upstream
maintainer with consistent design idioms.

## Selection

**fnott** on metis. Enabled via `home/core/nixos/fnott.nix` (HM
service module `services.fnott.enable = true`). The HM service
unit auto-starts via D-Bus activation — no `spawn-at-startup` hack
required. Stylix integration via `stylix.targets.fnott.enable = true`
in `home/core/shared/bundles/theming.nix`.

## Rationale

**Third dnkl-family extension; consistent posture.** Foot (#72),
fuzzel (#73), fnott (#74) are all by the same upstream maintainer
(dnkl on codeberg) and share the same architectural posture: small
closure, Wayland-native, no runtime ballast, narrow scope. The
desktop chrome accumulates as a coherent trio under one project
family rather than three independently-curated upstreams. Same idioms
(INI config, signal handling, debug output) across all three.

**Lightest viable option.** Aligns with the "start lighter, build
complexity in as justified" stance applied across #72 + #73. fnott's
feature surface (toast rendering, urgency-level styling, dismissal,
in-memory history) covers day-to-day notification needs without
bundling unused complexity (no control-center surface; no plugin
host).

**Auto-start is built-in via D-Bus activation.** HM ships an
`org.freedesktop.Notifications` D-Bus service file pointing at
`fnott.service`; the unit comes up the first time any client emits a
notification. No niri `spawn-at-startup` hack; no manual session
integration. `PartOf = graphical-session.target` ties shutdown to
session lifetime for clean teardown.

## Alternatives considered

**mako** — emersion-authored, common sway/niri-ecosystem choice.
Battle-tested, slightly richer feature set (notification grouping,
more elaborate per-app rules). Passed over because the
dnkl-family-coherence argument that drove foot + fuzzel selections
extends naturally to fnott. mako's grouping feature is the marginal
win it offers; not currently load-bearing for the operator's
workflow.

**dunst** — historically X11; has Wayland support but the
architecture is X11-rooted. Mature, large user base. Passed over
because the Wayland adaptation is downstream of an X11-first design;
fnott is a first-class Wayland citizen. The legacy-X11 framing also
runs against the "small Wayland-native tools" posture we've adopted.

**swaync** — notification daemon + control-center hybrid (sidebar UI
with system toggles). More featureful. Passed over because the
control-center surface is unused for our setup — the closure carries
the bundled UI concern without payoff. If a control center ever
becomes useful, swaync could be reconsidered as a one-tool
replacement for fnott + a separate notification-center add-on.

## Configuration

**HM module** — `home/core/nixos/fnott.nix`:

```nix
_: {
  services.fnott.enable = true;
}
```

Minimal — all real configuration flows through Stylix targets.

Layout values (anchor, timing, urgency-level handling) stay at
fnott's defaults — explicitly not tuned day-1. The defaults position
notifications top-right, matching macOS notification convention. If
a different position is ever wanted, set
`services.fnott.settings.main.anchor` to one of `top-left`,
`top-center`, `top-right`, `bottom-left`, `bottom-center`, or
`bottom-right`.

Lives under `home/core/nixos/` because fnott is Wayland-only —
same placement reasoning as foot.nix and fuzzel.nix; same shared-
purity rule (ADR-027) gating.

**Stylix integration** — `home/core/shared/bundles/theming.nix`:

```nix
stylix.targets.fnott.enable = true;
```

Stylix writes three sets of `services.fnott.settings`:

- **Fonts** — `title-font`, `summary-font`, `body-font` all set to
  `Inter:size=10` (from `stylix.fonts.sansSerif.name` +
  `stylix.fonts.sizes.popups`). Same sans-serif-for-UI-chrome
  rationale as fuzzel.
- **Colours** — base16 palette mapped to fnott's colour slots
  (background, title-color, summary-color, body-color,
  progress-color) plus per-urgency-level border accents:
  - `low.border-color` → base03 (subdued, informational)
  - `normal.border-color` → base0D (accent blue, default notifications)
  - `critical.border-color` → base08 (accent red, urgent)
- **Icon theme** — picked from `stylix.polarity` via
  `stylix.icons.{dark,light}`.

The urgency-level border accents are a fnott-specific theming
feature; the visual signal (red border for critical, blue for
normal, muted for low) carries information without requiring custom
prose in the notification body.

**Auto-start via D-Bus activation** — HM's `services.fnott` module
ships an `org.freedesktop.Notifications` D-Bus service file pointing
at `fnott.service`. The unit comes up the first time any client emits
a notification (the D-Bus daemon activates it on demand). No manual
session wiring; no `spawn-at-startup`. `PartOf =
graphical-session.target` ties shutdown to session lifetime for clean
teardown. See Sharp edges for the lazy-activation gotcha during
verification.

## Sharp edges

**`icon-theme` not written until `stylix.icons` is configured.**
Stylix's fnott target writes `services.fnott.settings.main.icon-theme`
only if `stylix.icons.{dark,light}` is set. We haven't configured
those; fnott falls back to its default icon-theme behaviour. Not a
functionality blocker — notifications still render — only affects
which icon set notifications display when they include icons. Same
gap as fuzzel.md; common follow-up.

**Lazy D-Bus activation surprises `systemctl status` after fresh
login.** On a freshly-logged-in session that hasn't received any
notifications yet, `systemctl --user status fnott.service` reads
*inactive (dead)*. This is normal — fnott is D-Bus-activated, not
session-target-pulled. To verify the daemon is wired correctly,
send a test notification: `notify-send test`. The unit activates
and the status flips to *active (running)*.

**First post-install `notify-send` may fail with `ServiceUnknown`
until dbus-broker rescans.** `dbus-broker` scans D-Bus service
directories at session start and caches the result for the
lifetime of the session. When `home-manager` first lays down
fnott's `org.freedesktop.Notifications.service` file mid-session
(i.e. on the activation that turns on `services.fnott.enable`),
the broker doesn't see it until the cache is refreshed. The
symptom is `notify-send test` failing with
`GDBus.Error:org.freedesktop.DBus.Error.ServiceUnknown: The name
... is not activatable`. The fix is one-shot:
`systemctl --user reload dbus.service`. Subsequent sessions
(after logout / reboot) pick up the service file automatically,
so this is only ever an issue on the activation that introduces
fnott. Same shape applies to any future HM-installed D-Bus
service.

**Wayland-only; Linux-only build.** Fnott doesn't compile off
Linux — same constraint as foot and fuzzel. Hence the
`home/core/nixos/` placement. If a Darwin host ever imports the
desktop-env HM bundle directly, eval will fail on `pkgs.fnott`. Mac
side notifications come from macOS Notification Center natively when
`home/core/darwin/` lands (per the mac-mini onboarding epic #11);
no fnott port needed.

**In-memory only; no cross-reboot persistence.** Fnott holds
notifications in memory; on reboot or unit restart the history is
lost. This is the typical Wayland-notification-daemon stance (mako
does the same). If cross-reboot history ever becomes load-bearing,
swaync's persistence layer is the only alternative in this category.
Currently fine: day-to-day notifications are ephemeral by intent.

## References

- [`home/core/nixos/fnott.nix`](../../home/core/nixos/fnott.nix) —
  the HM service module enabling fnott.
- [`home/core/shared/bundles/theming.nix`](../../home/core/shared/bundles/theming.nix)
  — `stylix.targets.fnott.enable = true`.
- [`home/core/nixos/bundles/desktop-env.nix`](../../home/core/nixos/bundles/desktop-env.nix)
  — bundle import.
- [foot.md](./foot.md) — sibling dnkl-family terminal.
- [fuzzel.md](./fuzzel.md) — sibling dnkl-family launcher.
- fnott upstream — https://codeberg.org/dnkl/fnott
