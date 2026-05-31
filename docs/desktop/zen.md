# Zen

Firefox-derived browser. Sidebar-first chrome; workspaces, essentials,
and split-view as native primitives. Gecko engine; native Wayland
inherited. **Under audit on metis alongside Firefox per #127** —
firefox.md remains the source of truth for the current default URL
handler.

## Selection

Zen is wired alongside Firefox on metis as a parallel installation so
the operator can evaluate whether the Stylix-Zen target's chrome
theming and Zen's intra-browser context model (workspaces /
essentials / sidebar / pinned tabs / split-view) displace Firefox.
See #127 for the revisit context.

Enabled via `home/core/nixos/zen-browser.nix` (HM module
`programs.zen-browser.enable = true` + a `default` profile so Stylix
has somewhere to write its prefs). The home-manager module ships
from a community flake input (chosen during the wiring PR per #127).
Stylix integration via `stylix.targets.zen-browser.enable = true` +
`stylix.targets.zen-browser.profileNames = [ "default" ]` in
`home/core/shared/stylix-targets.nix` — `enableCss = true` is
upstream-default so chrome + content theming run from day 1, unlike
Firefox's stock-chrome posture.

`xdg.mimeApps` is not modified during the audit. Firefox stays the
default URL handler so `xdg-open` behaviour is predictable; Zen is
launched manually from fuzzel for evaluation. The default flips at
decision time if the audit concludes in Zen's favour.

## Rationale

Deferred until #127's decision lands. See #127 for evaluation
context; this section is revised post-decision with the settled
rationale.

## Alternatives considered

The alternatives ruled out at `docs/desktop/firefox.md`
§"Alternatives considered" are ruled out for Zen for the same
reasons — engine, ecosystem, and project-posture arguments that
don't change between Firefox and Zen:

- **Brave** — Chromium engine; no engine-diversity contribution;
  BAT/crypto ad-network defaults.
- **Chromium** — largest closure; Chromium-engine; uBlock Origin's
  MV3 future worse than on Firefox.
- **LibreWolf** — Firefox-derived; privacy hardening
  operator-tunable in vanilla Firefox.
- **Floorp** — niche maintainer surface; sidebar features don't
  earn maintenance overhead.
- **Mullvad Browser** — Tor-Browser-derived hardening
  operator-tunable in vanilla Firefox.
- **qutebrowser** — Chromium-derived QtWebEngine; retraining cost
  without clear gain.
- **Safari** — macOS-only; not an option on Linux.
- **Arc / Vivaldi / Edge** — Chromium-based and closed-source or
  vendor-locked.

**Firefox** is the live alternative under this audit. See
firefox.md for its rationale; the audit at #127 decides whether
Zen's distinguishing characteristics (Stylix target coverage,
intra-browser context model) justify replacing Firefox.

## Configuration

**Flake input** — `flake.nix` carries the community-flake input for
Zen. Concrete flake selection deferred to the wiring PR per #127.
The eventual shape:

```nix
inputs.zen-browser = {
  url = "github:OWNER/zen-browser-flake";  # owner settled per #127
  inputs.nixpkgs.follows = "nixpkgs";
};
```

The flake's home-manager module reaches the HM scope via the
project's home-manager wiring (likely
`modules/core/nixos/home-manager.nix`'s `sharedModules` surface);
exact shape lands per #127.

**HM module** — `home/core/nixos/zen-browser.nix`:

```nix
_: {
  programs.zen-browser = {
    enable = true;
    profiles.default = {
      id = 0;
      isDefault = true;
    };
  };
}
```

Lives under `home/core/nixos/` because the audit is metis-only.
firefox.md's "gated by `xdg.mimeApps` being Linux-only, not package
portability" framing doesn't apply here because zen-browser.nix
doesn't register `xdg.mimeApps` during the audit; the placement is
gated by metis-only scope. If Zen displaces Firefox and earns a
multi-host footprint, the placement decision can be revisited then.

The `default` profile is the stub-profile pattern from firefox.nix —
both fields set explicitly for clarity (`id` defaults to `0`,
`isDefault` defaults to `id == 0`). The stub exists primarily so
Stylix has a profile name to target; settings, bookmarks, extensions,
workspaces, essentials can land here later (though most of Zen's
distinguishing state is non-declarative — see Sharp edges).

The HM submodule shape above (`id`, `isDefault`) assumes the chosen
flake exposes `programs.zen-browser.profiles.<name>` with keys
identical to home-manager's `programs.firefox.profiles.<name>`. This
is the structure Stylix's Zen target writes into (via
`programs.zen-browser.profiles.<name>.{settings,userChrome,userContent}`),
so the chosen flake must expose at least those keys; verify against
the flake at the wiring PR.

**Wayland enablement** — none required, expected. Zen is expected to
inherit Firefox's runtime `WAYLAND_DISPLAY` auto-detection given the
shared Gecko lineage; the wrapper-script shape from the chosen flake
confirms this at wiring time. Niri sets `WAYLAND_DISPLAY` for
session-spawned processes; launching Zen from fuzzel inside niri
should run Zen in Wayland mode. The verification path is
`about:support` → "Window Protocol" row reads `wayland`; no XWayland
fallback needed. If a future regression forces a downgrade to
XWayland, the same lever Firefox uses — `MOZ_ENABLE_WAYLAND=0` — is
expected to work for Zen given the shared Gecko/wrapper lineage; not
verified for Zen specifically at this writing.

**Stylix integration** — `home/core/shared/stylix-targets.nix`:

```nix
stylix.targets.zen-browser = {
  enable = true;
  profileNames = [ "default" ];
  # enableCss defaults to true upstream — left implicit; see below.
};
```

`enableCss = true` is the upstream Stylix-target default and is
intentionally not restated above. Setting it false would defeat the
audit (we'd be evaluating un-themed Zen). The two explicit lines are
both required: foundation sets `stylix.autoEnable = false` (the
whitelist stance from [CLAUDE.md](../../CLAUDE.md)), so every Stylix
target defaults to disabled and must be opted into explicitly —
matching the `foot.enable`, `fuzzel.enable`, `fnott.enable`,
`waybar.enable`, `firefox.enable` pattern. The `profileNames` field
is the operator-required input that Stylix's Zen target cannot
auto-detect (same module-system limitation as Firefox's target).

Stylix writes the following into the profile named `default`:

- **Font name prefs** — `font.name.{monospace,sans-serif,serif}.x-western`
  from `stylix.fonts.{monospace,sansSerif,serif}.name`. Unlike
  Firefox's Stylix target, Zen's target does not write `font.size.*`
  — Zen falls back to its built-in font sizing. Audit-relevant
  divergence: font *size* will not follow
  `stylix.fonts.sizes.applications` on Zen as it does on Firefox
  (see Sharp edges).
- **Reader-mode colours** — `reader.color_scheme = "custom"` plus
  five `reader.custom_colors.*` prefs (background, foreground,
  selection-highlight, unvisited-links, visited-links). Identical to
  Firefox's coverage; literally imports the same
  `../firefox/reader-mode.nix` Stylix module.
- **`userChrome.css`** — a comprehensive set of CSS variables
  covering toolbar, sidebar, urlbar, tab states, identity-tab colours
  (per-Firefox-container colour mapped to a base16 slot), workspace
  button, and swipe-nav arrows. Example variables from across those
  categories:
  ```css
  :root {
    --zen-main-browser-background: #${base00-hex} !important;
    --toolbar-bgcolor: #${base02-hex} !important;
    --lwt-sidebar-background-color: #${base00-hex} !important;
    /* …toolbar, sidebar, urlbar… */
  }
  .identity-color-blue {
    --identity-tab-color: #${base0D-hex} !important;
  }
  #historySwipeAnimationPreviousArrow {
    --swipe-nav-icon-primary-color: #${base0D-hex} !important;
  }
  ```
  Full mapping in the
  [Stylix Zen target source](https://github.com/nix-community/stylix/tree/master/modules/zen-browser).
- **`userContent.css`** — base16 mapping for Zen's `about:`-page
  chrome plus global `::selection` styling. Coverage that no Stylix
  Firefox path provides today. See the
  [Stylix Zen target source](https://github.com/nix-community/stylix/tree/master/modules/zen-browser)
  for the specific pages styled.
- **`toolkit.legacyUserProfileCustomizations.stylesheets = true`** —
  set by Stylix as part of `enableCss`; required for `userChrome.css`
  and `userContent.css` above to load at all.

Unlike Firefox's Stylix target (which has `colorTheme` /
`firefoxGnomeTheme` opt-ins plus deliberate non-enables documented in
firefox.md), Zen's Stylix target has only `profileNames` and
`enableCss` as knobs. Both are set above (the latter implicitly via
upstream default). No deliberate non-enables list — there are no
further knobs to deliberate over.

**MIME registration** — explicitly not touched during the audit.
firefox.md's `xdg.mimeApps.defaultApplications` continues to register
`firefox.desktop` as the default URL handler. If Zen displaces
Firefox at #127's decision point, the practical move is to migrate
the `xdg.mimeApps.defaultApplications` block from
`home/core/nixos/firefox.nix` into `home/core/nixos/zen-browser.nix`
(replacing `firefox.desktop` with the chosen flake's Zen desktop
entry) alongside removing `firefox.nix` — not a rename in place.

**Runtime state surface** — Zen's intra-browser context model lives
in runtime state, not Nix. The operator builds and maintains these
manually during the audit:

- **Workspaces** — named persistent contexts (e.g., Work / Personal /
  Project-X) each containing their own tab sets. Optionally bound to
  Firefox Containers for cookie isolation per workspace.
- **Essentials** — small set of cross-workspace pinned sites always
  reachable.
- **Pinned tabs** — workspace-scoped equivalent of essentials.
- **Split-view layouts** — multi-pane page arrangements within a
  single Zen window.
- **Tab unloading** — automatic on idle; thresholds operator-tunable
  in the Zen UI.
- **Zen Mods** — Zen's chrome-customization extension ecosystem,
  separate from Stylix-written userChrome.css (see Sharp edges for
  the interaction concern).

This list is the surface under evaluation by the audit, not
declaratively configured. Whether the operator finds enough use for
these primitives to justify replacing Firefox is the central audit
question.

## Sharp edges

**`profileNames` MUST match a real profile, or Stylix warns and
writes nothing.** Same shape as Firefox's target — profile detection
is unsolvable inside the module system without infinite recursion
(Stylix's `modules/zen-browser/meta.nix`). The two surfaces
(`programs.zen-browser.profiles.default` in this doc's HM module and
`stylix.targets.zen-browser.profileNames = [ "default" ]`) must stay
in lockstep.

**Zen profile state is not declarative.** Same baseline story as
Firefox — bookmarks, history, cookies, sessions, login DB live in
the Zen profile directory as a stateful blob. All of Zen's
distinguishing runtime state — workspaces, essentials, pinned tabs,
split-view layouts, Zen Mods — also lives there. The non-declarative
surface is larger and more UX-central than Firefox's because the
workspace/essentials state *is* the Zen-distinguishing workflow.
Deleting the profile directory loses every workspace and essential
alongside the usual bookmark/session loss.

**Stylix Zen target does not write `font.size.*`.** Unlike Firefox's
Stylix target (which writes both `font.name.*` and `font.size.*`
derived from `stylix.fonts.sizes.{terminal,applications}` with a 4/3
pt→px factor), Zen's target writes only `font.name.*`. Zen's font
*size* falls back to the browser's built-in defaults and does not
track host-wide `stylix.fonts.sizes.*`. This is an audit-relevant
asymmetry — Firefox-vs-Zen visual comparison won't be apples-to-apples
on font size unless the audit holds `stylix.fonts.sizes.applications`
constant against Zen's default.

**Zen ships from a community flake (binaries), not nixpkgs.** Zen
has had multiple nixpkgs packaging attempts — an early init at
[NixOS/nixpkgs#347222](https://github.com/NixOS/nixpkgs/pull/347222)
was merged then reverted at
[#360291](https://github.com/NixOS/nixpkgs/pull/360291) when channel
builds hit Firefox-class build cost (memory, build time, and a
non-nixpkgs build tool — Surfer — per the original PR's discussion).
A current re-init at
[#496647](https://github.com/NixOS/nixpkgs/pull/496647) is in flight
at this writing; follow the PR for current state. Community flakes
package the prebuilt binaries from Zen's GitHub releases — same
posture as VS Code, Discord, and many "ships binaries" projects. The
path is reversible: if/when a nixpkgs PR lands, the flake input can
be swapped for `pkgs.zen-browser` with a one-line config change.

**Release cadence matters more than push date for the chosen
flake.** Zen releases frequently and ships security updates. The
chosen flake input must be tracking that cadence. Verify the
candidate flake by recent commit *content*, not push date alone —
a `docs: maintainer wanted` commit registers identically to a real
update in raw timestamps.

**Stylix CSS vs Zen Mods interaction is an open question.** Zen
Mods is Zen's official chrome-customization extension ecosystem.
Stylix's Zen target writes `userChrome.css` and `userContent.css`
directly into the profile, bypassing the Mods system. Whether the
two coexist (Mods leaves the base userChrome.css alone) or conflict
(Mods rewrites userChrome.css at runtime, blowing away Stylix's
colours) is not verified at this writing. The audit should resolve
this. If they conflict, the audit-honest resolution is to avoid
installing Mods that touch userChrome during the audit window —
using Mods *instead of* Stylix's `enableCss` would defeat the audit
(we'd no longer be evaluating Stylix-themed Zen).

**Stylix font prefs override the in-browser font picker UI.** Same
behaviour as Firefox — the per-profile `font.name` prefs Stylix
writes are operator-overridable via the Zen preferences UI, but the
next HM-switch resets them. See
[firefox.md](./firefox.md) §"Sharp edges" for the resolution
posture.

**`default` profile name is reused across Firefox and Zen modules
but the profiles are independent on disk.** `programs.firefox.profiles.default`
and `programs.zen-browser.profiles.default` share only the *name* —
Firefox writes to `$XDG_CONFIG_HOME/mozilla/firefox/`, Zen writes to
its own directory tree (per the chosen flake's expectations; commonly
`$XDG_CONFIG_HOME/zen/` or `~/.zen/`). No state leaks between the
two browsers; the shared name is a Stylix-target-readability
convenience, not a coupling.

## References

- [`home/core/nixos/zen-browser.nix`](../../home/core/nixos/zen-browser.nix)
  — the HM module enabling Zen + stub profile.
- [`home/core/shared/stylix-targets.nix`](../../home/core/shared/stylix-targets.nix)
  — `stylix.targets.zen-browser.profileNames`.
- [`home/core/nixos/bundles/desktop-env.nix`](../../home/core/nixos/bundles/desktop-env.nix)
  — bundle import.
- [`flake.nix`](../../flake.nix) — community flake input for Zen.
- [firefox.md](./firefox.md) — sibling selection doc; live alternative
  under this audit.
- [fonts.md](./fonts.md) — `stylix.fonts.*` selections that flow into
  Zen's per-profile font name prefs (size prefs are not written; see
  Sharp edges).
- Zen upstream — https://zen-browser.app.
- Zen releases — https://github.com/zen-browser/desktop/releases.
- Stylix Zen target source —
  https://github.com/nix-community/stylix/tree/master/modules/zen-browser.
- nixpkgs Zen re-init PR (in-flight) —
  https://github.com/NixOS/nixpkgs/pull/496647.
