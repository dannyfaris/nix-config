# Firefox

Mozilla's web browser. Gecko engine. Native Wayland support. The
chosen browser on metis and the default URL handler for
`xdg-open`.

## Selection

**Firefox** on metis. Enabled via `home/nixos/firefox.nix`
(HM module `programs.firefox.enable = true` + a `default` profile
so Stylix has somewhere to write its prefs). Registered as the
default handler for HTTP/HTTPS + HTML MIME types via HM's
`xdg.mimeApps.defaultApplications`. Stylix integration via
`stylix.targets.firefox.enable = true` +
`stylix.targets.firefox.profileNames = [ "default" ]` in
`home/shared/stylix-targets.nix` — font prefs only on day 1;
chrome-theming opt-ins (`colorTheme.enable`,
`firefoxGnomeTheme.enable`) deferred.

## Rationale

**First-class Wayland support, current.** Firefox enabled native
Wayland by default in version 121 (Dec 2023). Nixpkgs ships
Firefox 150-class builds on `nixos-unstable`; the wrapper script
detects `WAYLAND_DISPLAY` at runtime and launches Wayland-native
without `MOZ_ENABLE_WAYLAND=1` or other env-var ritual. Verification
surface is `about:support` → "Window Protocol" row shows
`wayland`; no XWayland fallback needed.

**Mature HM module.** `programs.firefox` supports per-profile
declarative configuration: `settings` (about:config prefs),
`extensions.packages`, `bookmarks`, `search`, `userChrome` /
`userContent` CSS. Profile state lives on disk (history, cookies,
sessions) — the module manages the declarative slice without
fighting Firefox's profile directory.

**Stylix target exists and is well-scoped.** Stylix writes
per-profile font prefs (sans-serif / serif / monospace mapped to
`stylix.fonts.*`) into the named profile's `settings`. The chrome
theming (`colorTheme` via the Firefox Color extension;
`firefoxGnomeTheme` via the `firefox-gnome-theme` upstream + a
base16 overlay) is opt-in and not enabled day 1. Rationale below
under Configuration.

## Alternatives considered

**Brave** — Chromium fork with privacy-leaning defaults
(ad-blocking, tracker-blocking on by default). Passed over for
two reasons: larger closure than Firefox; built-in BAT/crypto-rewards
ad-network the operator would have to disable on every install.
The defaults that look privacy-positive ship alongside revenue
defaults that aren't.

**Chromium** — The vanilla open-source upstream of Chrome.
Passed over: largest closure of any browser in nixpkgs; single
rendering engine for the ecosystem already; uBlock Origin's
manifest-v3 future on Chromium is meaningfully worse than on
Firefox. If a Chromium-engine browser is ever needed for
site-compat (e.g. a Google Workspace edge case), `nix run
nixpkgs#ungoogled-chromium` is the escape hatch — not worth
installing permanently.

**LibreWolf** — Firefox fork with privacy hardening baked in
(telemetry off, RFP on, etc.). Same engine. Stylix supports it
via the same target. Passed over because privacy hardening that
trades site-compat for stricter defaults is operator-tunable in
plain Firefox via `about:config` and the `programs.firefox.policies`
HM surface; the fork doesn't earn its maintenance overhead.

**Floorp** — Japanese Firefox fork, sidebar features, Stylix
target exists. Passed over: niche maintainer surface; the
sidebar features aren't earning their keep against Firefox's
own vertical-tabs experiment.

**Zen** — Firefox-derived, modern split-view + workspaces UI;
gaining notable nixpkgs-community traction in 2025-2026. Passed
over because it's still pre-1.0, no Stylix target, and the
workflow features (split view, tab workspaces) overlap with
niri's tiling — niri does that job at the WM layer.

**Mullvad Browser** — Tor-Browser-derived hardened Firefox built
with Mullvad; closer to LibreWolf in stance but without the
Tor-network coupling. Passed over for the same reason as
LibreWolf — privacy hardening that trades site-compat is
operator-tunable in plain Firefox; the fork doesn't earn its
maintenance overhead.

**qutebrowser** — Vim-style keyboard-driven, QtWebEngine. Passed
over: QtWebEngine is Chromium-derived; the Vim-style UX is a
deliberate retraining cost without a clear gain over Firefox's
keyboard shortcuts; the operator's macOS workflows would
diverge.

**Safari** — macOS-only, not an option on Linux.

**Arc / Vivaldi / Edge** — Chromium-based and closed-source
(Arc, Vivaldi) or vendor-locked (Edge). Passed over on those
grounds alone.

## Configuration

**HM module** — `home/nixos/firefox.nix`:

```nix
_: {
  programs.firefox = {
    enable = true;
    profiles.default = {
      id = 0;
      isDefault = true;
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "application/xhtml+xml" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
    };
  };
}
```

Lives under `home/nixos/` because the desktop registration
(`xdg.mimeApps`, the wider niri/foot-spawned `xdg-open` chain) is
Linux-only. **Unlike foot/fuzzel/fnott** (which don't build on
Darwin at all), `pkgs.firefox` does build on Darwin —
placement here is gated by `xdg.mimeApps` being a Linux-only
HM module surface, not by package portability. The macOS browser
selection (Safari / Arc / Brave / etc.) is a separate decision
deferred to the `home/darwin/` tree per epic #11.

The `default` profile is declared with both fields set explicitly
for clarity, though both have appropriate defaults
(`id` defaults to `0`, `isDefault` defaults to `id == 0`). The
stub profile exists primarily so Stylix has a profile name to
target; settings, bookmarks, extensions can land here later.

**Wayland enablement** — none required. Firefox 121+ auto-detects
`WAYLAND_DISPLAY` at startup. Niri sets that variable for
session-spawned processes; `xdg-open https://example.com` from a
foot terminal inside niri launches Firefox in Wayland mode. The
verification path is `about:support` → "Window Protocol" =
`wayland`. If a future regression forces a downgrade to XWayland,
the lever is `MOZ_ENABLE_WAYLAND=0` (forces X11); the historical
opt-in `MOZ_ENABLE_WAYLAND=1` is now a no-op.

**Stylix integration** — `home/shared/stylix-targets.nix`:

```nix
stylix.targets.firefox = {
  enable = true;
  profileNames = [ "default" ];
};
```

Both lines are required. The foundation sets
`stylix.autoEnable = false` (the whitelist stance from
[CLAUDE.md](../../CLAUDE.md)), so every Stylix target defaults
to disabled and must be opted into explicitly — matching the
`foot.enable`, `fuzzel.enable`, `fnott.enable`, `waybar.enable`
pattern. The `profileNames` field is the operator-required
input that Stylix's Firefox target cannot auto-detect
(documented in stylix's `modules/firefox/meta.nix` as a
module-system limitation).

Stylix writes the following per-profile prefs into the profile
named `default`:
- `font.name.{monospace,sans-serif,serif}.x-western` — set from
  `stylix.fonts.{monospace,sansSerif,serif}.name`.
- `font.size.{monospace,variable}.x-western` — set from
  `stylix.fonts.sizes.{terminal,applications}`, converted from
  pt to px with the 4/3 factor Firefox expects.

Three deliberate non-enables:
- `stylix.targets.firefox.colorTheme.enable = true` — would
  install the Firefox Color extension into the profile and
  configure a base16 chrome theme via extension settings. Adds an
  extension dependency and a settings-file that has to round-trip
  through Firefox at first launch. Stock chrome is fine day 1.
- `stylix.targets.firefox.firefoxGnomeTheme.enable = true` —
  would import the `firefox-gnome-theme` upstream
  (`userChrome.css` + `userContent.css`) plus a base16 overlay
  template. Restyles the chrome to match GNOME aesthetics. The
  operator isn't a GNOME user; the stock Firefox chrome on the
  monospace/sans-serif font palette reads coherently enough.
- We deliberately don't write any `programs.firefox.profiles.default.settings`
  ourselves. The font prefs that flow from Stylix are the only
  declarative prefs day 1; everything else is operator-tunable
  via the Firefox UI and persists into the profile state.

**MIME registration** — `xdg.mimeApps.defaultApplications` writes
`$XDG_CONFIG_HOME/mimeapps.list` and ensures `xdg-mime query
default text/html` returns `firefox.desktop`. The six entries
above cover the URL paths an `xdg-open` invocation can take:
`text/html` + `application/xhtml+xml` for local HTML/XHTML
files; `http`/`https` for network URLs; `about` for
`about:config`-style URIs Firefox itself emits; `unknown` for
`xdg-open something://opaque` cases. Tools downstream (e.g.
Cursor's auth-callback flow, mail clients) hand URLs to
`xdg-open` which resolves the entry here. We register only the
practically-exercised types; the upstream `firefox.desktop`
registers a wider list.

## Sharp edges

**`profileNames` MUST match a real profile, or Stylix warns and
writes nothing.** Stylix's Firefox module documents (in
`modules/firefox/meta.nix`) that profile detection is unsolvable
inside the module system without infinite recursion — so the
profile-name list is operator-declared. If `profileNames` is `[ ]`
(the default), Stylix emits `stylix: firefox:
config.stylix.targets.firefox.profileNames is not set` at build
time and produces no prefs. If `profileNames` lists a name that
doesn't exist in `programs.firefox.profiles.*`, eval fails. The
two surfaces (this doc's `programs.firefox.profiles.default` and
`stylix.targets.firefox.profileNames = [ "default" ]`) must stay
in lockstep.

**Firefox profile state is not declarative.** Bookmarks, history,
cookies, sessions, login DB, extension prefs that aren't
explicitly set via Nix — all live in
`~/.mozilla/firefox/default/` (the legacy path; see "Profile-config
XDG path" below for why we pin this) as a stateful blob.
This is by design (Firefox is a stateful application). The
declarative HM module writes a small subset of `prefs.js`-equivalents
and lays down extension packages; everything else is mutable
runtime state. If `default/` is deleted, Firefox recreates it on
next launch and Stylix re-writes the declarative prefs on next
HM-switch; user state (bookmarks, sessions) is lost in that path.

**Profile-config XDG path moved in HM 26.05; we pin legacy.** The
default `configPath` in the HM Firefox module migrated from
`.mozilla/firefox` to `$XDG_CONFIG_HOME/mozilla/firefox` in HM
release 26.05. Our `home.stateVersion` is `"25.11"` (set once,
never change, per `modules/nixos/home-manager.nix`), so the legacy
path is what HM picks — but HM also emits a per-rebuild warning
asking us to choose explicitly. We pin
`programs.firefox.configPath = ".mozilla/firefox"` in
`home/nixos/firefox.nix` to silence the warning while preserving
the current on-disk layout. Same pattern as
`stylix-targets.nix`'s `gtk.gtk4.theme` pin. Migrating to the
XDG path would require physically moving `~/.mozilla/firefox` →
`~/.config/mozilla/firefox` (Firefox profile state is not
declarative — see above); that's a deliberate future move, not
something to do implicitly via a stateVersion bump.

**Stylix font prefs override Firefox's own font picker UI.** The
per-profile font.name and font.size prefs that Stylix writes are
operator-overridable via the Firefox preferences UI (Settings →
Fonts), but the next HM-switch resets them to Stylix's values.
Anyone wanting permanent font tweaks should change
`stylix.fonts.*` (host-wide) rather than fighting via the
Firefox UI.

## References

- [`home/nixos/firefox.nix`](../../home/nixos/firefox.nix)
  — the HM module enabling Firefox + `xdg.mimeApps` registration.
- [`home/shared/stylix-targets.nix`](../../home/shared/stylix-targets.nix)
  — `stylix.targets.firefox.profileNames`.
- [`home/nixos/bundles/desktop-env.nix`](../../home/nixos/bundles/desktop-env.nix)
  — bundle import.
- [fonts.md](./fonts.md) — `stylix.fonts.*` selections that
  flow into Firefox's per-profile font prefs.
- Firefox upstream — https://www.mozilla.org/firefox
- HM Firefox module — `programs.firefox` options reference at
  https://nix-community.github.io/home-manager/options.xhtml
- Stylix Firefox target source —
  https://github.com/nix-community/stylix/tree/master/modules/firefox
- firefox-gnome-theme upstream (currently not enabled) —
  https://github.com/rafaelmardojai/firefox-gnome-theme.
