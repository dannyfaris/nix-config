# Firefox

Mozilla's web browser. Gecko engine. Native Wayland support. The chosen browser on metis and the default URL handler for `xdg-open`.

## Selection

**Firefox** on the NixOS desktop hosts. Enabled via `home/nixos/firefox.nix` (HM module `programs.firefox.enable = true` + a `default` profile). Registered as the default handler for HTTP/HTTPS + HTML MIME types via HM's `xdg.mimeApps.defaultApplications`. Stylix's `firefox` target — which used to write per-profile font prefs — was **dropped whole** in the G6 Stylix-exit audit (#825, #819 Epic G): zero decision weight per the operator ruling, accepted collateral of the ADR-048 delegation, no replacement wiring. Firefox now renders its own stock font and colour defaults.

## Rationale

**First-class Wayland support, current.** Firefox enabled native Wayland by default in version 121 (Dec 2023). Nixpkgs ships Firefox 150-class builds on `nixos-unstable`; the wrapper script detects `WAYLAND_DISPLAY` at runtime and launches Wayland-native without `MOZ_ENABLE_WAYLAND=1` or other env-var ritual. Verification surface is `about:support` → "Window Protocol" row shows `wayland`; no XWayland fallback needed.

**Mature HM module.** `programs.firefox` supports per-profile declarative configuration: `settings` (about:config prefs), `extensions.packages`, `bookmarks`, `search`, `userChrome` / `userContent` CSS. Profile state lives on disk (history, cookies, sessions) — the module manages the declarative slice without fighting Firefox's profile directory.

**Stylix target dropped, not narrowed (G6, #825).** Firefox's theming fate carries zero decision weight per the operator ruling recorded in `docs/design/noctalia-theming-delegation.md` — its loss is accepted collateral of the ADR-048 delegation, with no replacement wiring (no fontconfig follow, no Noctalia template). See §Configuration for what this doc used to describe.

## Alternatives considered

**Brave** — Chromium fork with privacy-leaning defaults (ad-blocking, tracker-blocking on by default). Passed over for two reasons: larger closure than Firefox; built-in BAT/crypto-rewards ad-network the operator would have to disable on every install. The defaults that look privacy-positive ship alongside revenue defaults that aren't.

**Chromium** — The vanilla open-source upstream of Chrome. Passed over: largest closure of any browser in nixpkgs; single rendering engine for the ecosystem already; uBlock Origin's manifest-v3 future on Chromium is meaningfully worse than on Firefox. If a Chromium-engine browser is ever needed for site-compat (e.g. a Google Workspace edge case), `nix run
nixpkgs#ungoogled-chromium` is the escape hatch — not worth installing permanently.

**LibreWolf** — Firefox fork with privacy hardening baked in (telemetry off, RFP on, etc.). Same engine. Stylix supports it via the same target. Passed over because privacy hardening that trades site-compat for stricter defaults is operator-tunable in plain Firefox via `about:config` and the `programs.firefox.policies` HM surface; the fork doesn't earn its maintenance overhead.

**Floorp** — Japanese Firefox fork, sidebar features, Stylix target exists. Passed over: niche maintainer surface; the sidebar features aren't earning their keep against Firefox's own vertical-tabs experiment.

**Zen** — Firefox-derived, modern split-view + workspaces UI; gaining notable nixpkgs-community traction in 2025-2026. Trialled on metis as a parallel audit install with its own Stylix target (#127) and retired: its split-view / tab-workspace workflow overlaps with niri's tiling — niri does that job at the WM layer — so it didn't earn displacing Firefox. See [zen.md](./zen.md) for the retirement record.

**Mullvad Browser** — Tor-Browser-derived hardened Firefox built with Mullvad; closer to LibreWolf in stance but without the Tor-network coupling. Passed over for the same reason as LibreWolf — privacy hardening that trades site-compat is operator-tunable in plain Firefox; the fork doesn't earn its maintenance overhead.

**qutebrowser** — Vim-style keyboard-driven, QtWebEngine. Passed over: QtWebEngine is Chromium-derived; the Vim-style UX is a deliberate retraining cost without a clear gain over Firefox's keyboard shortcuts; the operator's macOS workflows would diverge.

**Safari** — macOS-only, not an option on Linux.

**Arc / Vivaldi / Edge** — Chromium-based and closed-source (Arc, Vivaldi) or vendor-locked (Edge). Passed over on those grounds alone.

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

Lives under `home/nixos/` because the desktop registration (`xdg.mimeApps`, the wider niri/foot-spawned `xdg-open` chain) is Linux-only. **Unlike foot/fuzzel/fnott** (which don't build on Darwin at all), `pkgs.firefox` does build on Darwin — placement here is gated by `xdg.mimeApps` being a Linux-only HM module surface, not by package portability. The macOS browser selection (Safari / Arc / Brave / etc.) is a separate decision deferred to the `home/darwin/` tree per epic #11.

The `default` profile is declared with both fields set explicitly for clarity, though both have appropriate defaults (`id` defaults to `0`, `isDefault` defaults to `id == 0`). The stub profile names the settings home for the 1Password policy declared in `home/nixos/firefox.nix`; settings, bookmarks, extensions can land here later.

**Wayland enablement** — none required. Firefox 121+ auto-detects `WAYLAND_DISPLAY` at startup. Niri sets that variable for session-spawned processes; `xdg-open https://example.com` from a foot terminal inside niri launches Firefox in Wayland mode. The verification path is `about:support` → "Window Protocol" = `wayland`. If a future regression forces a downgrade to XWayland, the lever is `MOZ_ENABLE_WAYLAND=0` (forces X11); the historical opt-in `MOZ_ENABLE_WAYLAND=1` is now a no-op.

**Stylix integration — dropped (G6, #825).** Firefox previously carried a `stylix.targets.firefox = { enable = true; profileNames = [ "default" ]; }` block (font prefs only; the `colorTheme`/`firefoxGnomeTheme` chrome-theming opt-ins were never enabled) writing per-profile `font.name.*`/`font.size.*` prefs from `stylix.fonts.*`. None of that survives the G6 Stylix-exit audit: the target is removed outright, not narrowed, per the operator's zero-decision-weight ruling — no fontconfig-generic follow-up replaces it. We still don't write any `programs.firefox.profiles.default.settings` ourselves; every font and colour choice in Firefox is now operator-tunable via the Firefox UI only, and persists into the profile state.

**MIME registration** — `xdg.mimeApps.defaultApplications` writes `$XDG_CONFIG_HOME/mimeapps.list` and ensures `xdg-mime query
default text/html` returns `firefox.desktop`. The six entries above cover the URL paths an `xdg-open` invocation can take: `text/html` + `application/xhtml+xml` for local HTML/XHTML files; `http`/`https` for network URLs; `about` for `about:config`-style URIs Firefox itself emits; `unknown` for `xdg-open something://opaque` cases. Tools downstream (e.g. Cursor's auth-callback flow, mail clients) hand URLs to `xdg-open` which resolves the entry here. We register only the practically-exercised types; the upstream `firefox.desktop` registers a wider list.

## Sharp edges

**(Historical, moot post-G6) `profileNames` used to need to match a real profile, or Stylix warned and wrote nothing.** Stylix's Firefox module documented (in `modules/firefox/meta.nix`) that profile detection was unsolvable inside the module system without infinite recursion, so the profile-name list was operator-declared and had to stay in lockstep with `programs.firefox.profiles.default`. Moot now that the target is dropped (#825); the `default` profile stub in `home/nixos/firefox.nix` remains only as the settings home for the 1Password policy.

**Firefox profile state is not declarative.** Bookmarks, history, cookies, sessions, login DB, extension prefs that aren't explicitly set via Nix — all live in `~/.mozilla/firefox/default/` (the legacy path; see "Profile-config XDG path" below for why we pin this) as a stateful blob. This is by design (Firefox is a stateful application). The declarative HM module writes a small subset of `prefs.js`-equivalents and lays down extension packages; everything else is mutable runtime state. If `default/` is deleted, Firefox recreates it on next launch with its own stock defaults (no Stylix rewrite post-G6); user state (bookmarks, sessions) is lost in that path.

**Profile-config XDG path moved in HM 26.05; we pin legacy.** The default `configPath` in the HM Firefox module migrated from `.mozilla/firefox` to `$XDG_CONFIG_HOME/mozilla/firefox` in HM release 26.05. Our `home.stateVersion` is `"25.11"` (set once, never change, per `modules/nixos/home-manager.nix`), so the legacy path is what HM picks — but HM also emits a per-rebuild warning asking us to choose explicitly. We pin `programs.firefox.configPath = ".mozilla/firefox"` in `home/nixos/firefox.nix` to silence the warning while preserving the current on-disk layout. Same pattern as `stylix-targets.nix`'s `gtk.gtk4.theme` pin. Migrating to the XDG path would require physically moving `~/.mozilla/firefox` → `~/.config/mozilla/firefox` (Firefox profile state is not declarative — see above); that's a deliberate future move, not something to do implicitly via a stateVersion bump.

**(Historical, moot post-G6) Stylix font prefs used to override Firefox's own font picker UI.** The per-profile font.name and font.size prefs Stylix wrote were operator-overridable via the Firefox preferences UI (Settings → Fonts), but the next HM-switch reset them to Stylix's values. Moot now that the target is dropped (#825) — Firefox's font pickers are fully operator-owned, permanently.

## References

- [`home/nixos/firefox.nix`](../../home/nixos/firefox.nix) — the HM module enabling Firefox + `xdg.mimeApps` registration.
- `home/nixos/stylix-targets-desktop.nix` — where the now-dropped `firefox` Stylix target used to live (G6, #825). The file itself was deleted with the rest of the NixOS Stylix wiring (#885, ADR-028 §History).
- [`home/nixos/bundles/desktop-env.nix`](../../home/nixos/bundles/desktop-env.nix) — bundle import.
- [fonts.md](./fonts.md) — the fontconfig conductor Firefox does not follow.
- Firefox upstream — https://www.mozilla.org/firefox
- HM Firefox module — `programs.firefox` options reference at https://nix-community.github.io/home-manager/options.xhtml
- firefox-gnome-theme upstream (never enabled; moot post-G6) — https://github.com/rafaelmardojai/firefox-gnome-theme.
