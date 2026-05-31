# Waybar

GTK3-based Wayland status bar. The de-facto choice for niri/sway
desktops. Selected because it's the only mainstream Wayland bar with
StatusNotifierItem (system tray) support — load-bearing for Slack,
1Password, and similar tray-resident applications.

## Selection

**waybar** on metis. Enabled via `home/core/nixos/waybar.nix` (HM
module `programs.waybar.enable = true` + `programs.waybar.systemd.enable
= true` for auto-start). Top of screen, minimal day-1 module set
(niri/workspaces on the left; network + tray + clock on the right).
Stylix integration via `stylix.targets.waybar.enable = true` in
`home/core/shared/stylix-targets.nix`.

## Rationale

**Tray support is the load-bearing requirement.** The chrome-roundup
work (fuzzel, fnott) extended the dnkl-family pattern naturally —
foot, fuzzel, fnott are all by the same upstream maintainer and share
the same architectural posture. The status bar pattern would extend
to yambar (also dnkl). But **yambar has no system tray module**, and
the author has stated this is intentional. For tray-resident apps
(Slack, 1Password's windowed UI, Discord, KeePassXC, VPN clients),
the missing tray would push those apps into permanent alt-tab-only
visibility. That's a real workflow penalty the dnkl-family
consistency doesn't earn back.

**Waybar is the niri-community default.** Nearly every public niri
config in the wild uses waybar. The module library is comprehensive,
Stylix integration is mature, the niri-workspaces module reads
niri's IPC directly.

## Alternatives considered

**yambar** — dnkl-family (same author as foot + fuzzel + fnott),
Wayland-native, lighter closure. Has a `niri` module for workspace
integration. **Passed over because yambar has no system tray
module.** The author's stance (per upstream issues) is that the
StatusNotifierItem protocol is too complex to implement; tray
support is out of scope. For our workflow this is a hard constraint,
not a stylistic preference.

**eww** — ElKowar's Wacky Widgets. Rust-based, programmable via
Yuck (a Lisp-DSL). Most flexible status bar; you write widgets
yourself. **Passed over** for two reasons: high config complexity
(writing widgets vs assembling modules); no Stylix target. eww
is the right tool for someone who wants a fully custom bar; we
want a sensible default that themes through Stylix.

**i3bar / i3status** — X11-rooted. Passed over by virtue of not
being Wayland-native; same reasoning as for dunst on the
notification side.

## Configuration

**HM module** — `home/core/nixos/waybar.nix`:

```nix
{ ... }:
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 30;
      modules-left = [ "niri/workspaces" ];
      modules-right = [ "network" "tray" "clock" ];

      "niri/workspaces" = { };  # defaults: shows niri's active workspaces
      network = {
        format-ethernet = "wired";
        format-disconnected = "offline";
      };
      tray.spacing = 10;
      clock.format = "{:%I:%M %p  %a %d %b}";  # 02:23 PM  Fri 29 May
    };
  };
}
```

Lives under `home/core/nixos/` because waybar is Linux-only —
same placement reasoning as foot.nix / fuzzel.nix / fnott.nix.

Day-1 module set is minimal — clock + niri workspaces + network +
tray. No audio module (deliberate; volume control happens via
hardware keys or `wpctl` from a terminal as needed). Clock sits in
the rightmost slot, macOS top-right convention.

**Stylix integration** — `home/core/shared/stylix-targets.nix`:

```nix
stylix.targets.waybar.enable = true;
```

Stylix writes `programs.waybar.style` (the CSS) with:
- Full base16 palette as `@define-color` variables (base00–base0F).
- Default background = `@base00` with desktop opacity applied.
- Default text colour = `@base05`.
- Workspaces module: bottom border on each button, `@base05` for
  focused/active, `@base08` for urgent.
- Tooltip styling (background, text, border via `@base0D`).
- A base CSS ruleset (line spacing, padding, hover behaviour) bundled
  by Stylix.
- Font defaults to `monospace` (JetBrains Mono Nerd Font from our
  Stylix `fonts.monospace`). This is deliberate — status icons in the
  network and tray modules render as Nerd Font glyphs, which Inter
  doesn't carry. The monospace font reads fine at 10pt in a status
  bar.

**Auto-start via systemd** — `programs.waybar.systemd.enable = true`
adds a systemd user unit bound to `graphical-session.target`. Unlike
fnott's lazy D-Bus activation, this is target-pulled: niri activates
`graphical-session.target` on session start, and waybar starts as a
side effect. Status: `systemctl --user status waybar.service`.

## Sharp edges

**GTK3 closure footprint.** Waybar is GTK3-based (cairo, GLib, pango,
GTK widgets). The closure is meaningfully larger than the dnkl-family
tools' ~single-binary footprint. Accepted because tray support
earns the cost; quantified roughly as "tens of MB" rather than the
"single-MB" range fnott/foot/fuzzel sit in. Not measured precisely
because the difference doesn't change the decision.

**Tray protocol coverage is StatusNotifierItem-only.** Waybar's tray
module implements the modern StatusNotifierItem protocol (KDE/Plasma
convention), not the legacy XEmbed system tray (GTK2-era). Most
modern apps (Slack, 1Password, Discord, Telegram, KeePassXC) speak
StatusNotifierItem natively or via libappindicator. Edge case: a
very old GTK2-only app trying to use XEmbed won't appear in the
tray — but there are essentially none of these on a 2025-era
desktop. If one ever surfaces, an XEmbed-to-StatusNotifierItem
bridge (snixembed) could pair with waybar, but that's a future
problem.

**niri workspaces vs static workspaces in the bar.** Niri creates
workspaces dynamically — there isn't a fixed 1..N set, workspaces
appear and disappear with activity. Waybar's `niri/workspaces`
module follows niri's IPC, so the bar reflects the live state. This
is different from how the bar looks under sway (fixed 1..10
workspaces). Don't be surprised when the workspace count in the bar
fluctuates as you open/close workspaces.

**Font choice trade-off.** Stylix defaults the bar font to
`monospace` (JetBrains Mono Nerd Font), giving us icon-glyph
coverage. Aesthetically a sans-serif (Inter) would match macOS
menu-bar styling more closely, but Inter lacks the Nerd Font glyphs
used in the status modules. The monospace default is the right
trade-off; flagged here so a future contributor doesn't switch
fonts without realising the icons break.

**Clock format restricted to C++20 chrono specifiers, not GNU
strftime extensions.** Waybar's clock module uses fmt's chrono
formatter (`std::chrono::format`), which accepts standard
POSIX/C strftime tokens but rejects GNU extensions like `%-I`
(no-pad hour). An initial draft used `%-I`; the clock module
rendered nothing on the bar and logged `chrono format error:
invalid specifier in chrono-specs` (visible via `journalctl
--user -u waybar.service`). Use `%I` (zero-pad,
`02:23 PM`) or `%l` (space-pad, ` 2:23 PM`) for unpadded-style
hours instead. The current format uses `%I` for column-width
consistency.

## References

- [`home/core/nixos/waybar.nix`](../../home/core/nixos/waybar.nix) —
  the HM module enabling waybar.
- [`home/core/shared/stylix-targets.nix`](../../home/core/shared/stylix-targets.nix)
  — `stylix.targets.waybar.enable = true`.
- [`home/core/nixos/bundles/desktop-env.nix`](../../home/core/nixos/bundles/desktop-env.nix)
  — bundle import.
- [niri.md](./niri.md) — compositor; waybar's `niri/workspaces`
  module reads niri's IPC.
- [fonts.md](./fonts.md) — font selection backdrop; the monospace
  default explained above ties to JetBrains Mono Nerd Font.
- waybar upstream — https://github.com/Alexays/Waybar
- waybar wiki (modules + config) — https://github.com/Alexays/Waybar/wiki
