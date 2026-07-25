# Noctalia

Cohesive Wayland desktop shell — since v5, a native C++ binary (`noctalia`), no Quickshell, no Qt. One project owns the bar, launcher, notifications, lock, OSD, control-centre, clipboard history, tray, dock, wallpaper, desktop widgets, session menu, and idle — replacing the per-tool waybar + fuzzel + fnott + swaylock stack on the Linux desktop.

> **Status: selected, implemented; v5 as of #644** (adopted at v4 in #385/ADR-036, demoted from theming authority by ADR-044/#609, migrated to the v5 native rewrite per [docs/design/noctalia-v5-migration.md](../design/noctalia-v5-migration.md)). This doc is the living selection record for the v5 integration; the v4-era record it replaces survives in git history (`git log -- docs/desktop/noctalia.md`). Behavioural claims below marked *(probe …)* are runtime-verified against the design note's on-metis probe plan; until #644's validation completes they describe the declared, source-verified design.

## Selection

**Noctalia v5** (`noctalia-dev/noctalia`, pinned to the release tag — `v5.0.0-beta.4` at adoption; never `main`, which moves daily), consumed via its own flake input with `nixpkgs.follows` per repo convention. The ground-up rewrite drops the entire v4 runtime story: no Quickshell, no co-locked `noctalia-qs` fork, no Qt in the closure — the skew class ADR-036 accepted as a conscious cost is gone, and the "v5 leaves alpha" migration trigger it recorded has been taken (early, at beta, for Alcyone's sake — the tradeoff is argued in the design note §Drawbacks). No binary cache exists; the meson/C++ build is local and materially lighter than v4's Qt closure.

The shell is spawned from niri (`spawn-at-startup` via `getExe` — no PATH reliance), not the HM module's opt-in systemd unit. IPC is `noctalia msg <verb>` over `$XDG_RUNTIME_DIR/noctalia-<display>.sock`. The launcher keybind is `noctalia msg panel-toggle launcher`.

## Configuration model — declared core, mutable skin

v5 layers its config: a read-only, Nix-written `~/.config/noctalia/config.toml` (validated at build time by the binary's own `noctalia config validate` — `validateConfig`, default on) under a runtime overrides file `~/.local/state/noctalia/settings.toml`, where **all** GUI and IPC writes land. This dissolves v4's GUI-managed-XOR-Nix-pinned either/or: the repo declares a **minimal baseline** (`home/nixos/noctalia.nix`) — theming wiring, idle behaviours, posture toggles — while bar layout, launcher preferences, and cosmetics stay legitimate runtime state, configured in the control centre and deliberately not reproducible from the flake (the ADR-036 posture, re-signed knowingly).

Declared baseline, in brief: setup wizard off (its guided writes would persist theme overrides on day one); `theme.source = "custom"` + `custom_palette = "theme-menu"` + boot-polarity `mode`; the template engine off on both axes (ADR-044 — Nix owns every external surface); a `[hooks] started` polarity reconcile; and the `[idle.behavior]` set below.

**There is no v4→v5 importer.** v4's `settings.json`/`colors.json` are ignored; the shell's look is reconstructed once in the control centre at cutover, and stale v4 files (`colors.json`, `*.pre-609`) are inert leftovers.

## Theming — themed-by-Nix through the constant-name palette

ADR-044 stands: Nix is the sole theming authority; Noctalia is a themed-by-Nix shell. The v5 seam (ADR-044's recorded migration trigger, fired on all three axes — path, format, trigger):

- The theme-menu conductor renders one `noctalia.json` per family — `dark` + `light` objects, each the 16 `m*` M3-role keys plus the v5-mandatory `terminal` block (base16→ANSI mapping mirrors the foot artefact; the parser hard-falls-back to the builtin theme if a mode lacks its terminal block).
- Noctalia reads it as the **constant-name custom palette**: `~/.config/noctalia/palettes/theme-menu.json` → `$XDG_STATE_HOME/theme-menu/noctalia.json` → `current/noctalia.json`. The family selection lives in exactly one place — the conductor's pointer; Noctalia holds a name that never changes and dereferences the chain at every theme resolve. Its `settings.toml` never learns a family name *(probe V3)*.
- **No palette watcher exists in v5** — activation is one explicit IPC call per switch from the `theme` CLI: `theme-mode-set` on polarity changes (which re-resolves and subsumes a simultaneous family change), else `config-reload` *(probes V2, V4)*. The CLI discovers the socket by glob — the client's `WAYLAND_DISPLAY` fallback guesses `wayland-0` and would silently miss metis's `wayland-1` over SSH *(probe V5)*.
- The polarity axis stays on dconf (v5 does not read the portal color-scheme). `theme-mode-set` persists a benign `theme.mode` echo into the overrides file; the declared `started` hook re-converges Noctalia to dconf on every shell start (compare-first via `theme-mode-get`), so the echo can never go stale — at the cost of one visible flip at startup when they disagree.

**Must-not-touch:** the control centre's theme/scheme pickers remain inert-by-convention — in v5 they *would* work and would persist `theme.source` overrides that shadow the declared config until manually cleared (the overrides layer wins wherever it holds a key, and Nix cannot reach it). The conductor owns the selection; recovery from an accidental GUI pick is a one-time override clear (GUI reset, or editing `~/.local/state/noctalia/settings.toml`).

## Idle, sleep, caffeine

Declared in the baseline (`[idle]`, fade overlay off — nobody is at the desk when these fire): **lock** at 600 s, **screen-off** at 660 s, and **suspend** at 1800 s — a deliberate stance change (#644) retiring the recorded "no auto-suspend on a desktop". Suspend is a per-host `hostContext.idleSuspend` flag: on for metis (and Alcyone), one line to disable at the #387 re-role.

Suspend is guarded, not bare — `[idle.behavior.suspend]` runs `noctalia-idle-guard`, which stays awake if any of: **the caffeine switch is on** (see below), a live inbound SSH session exists, or detached agent workloads are running (linger is on; SSH teardown does not imply idle). Otherwise it delegates to Noctalia's own `session lock-and-suspend` — race-free, queued on the compositor's `locked` event. Failure direction is always "stays awake" *(probe S3)*. A skipped fire does not re-arm until input resets the idle timer.

**Caffeine natively gates all idle behaviours — runtime-verified (probe S4, 2026-07-25).** With caffeine on, every idle firing is suppressed at fire time (`idle behavior … suppressed (screensaver inhibit locks=1)` in the log); disabling caffeine let the next firing through within its timeout. This *refuted* the pre-migration source-read (three review passes concluded caffeine's logind idle inhibitor gated nothing — individually true facts, wrong composition: caffeine also holds the screensaver inhibit lock the idle manager consults). So the caffeine switch (the bar's `caffeine` widget — not in v5's default widget set, added via the control centre — or `noctalia msg caffeine-{enable,disable,toggle}`) carries full keep-awake semantics: no lock, no blank, no suspend. The suspend guard *also* reads caffeine's logind fingerprint (`who=noctalia, why=Caffeine`) as documented defence-in-depth. Caffeine state is session-scoped (dropped on shell restart). **Bump ritual:** on every Noctalia bump, re-probe that caffeine still suppresses idle behaviours and the fingerprint is still readable.

**Lock-before-any-sleep is restored** (the v4 accepted gap is closed): `services.systemd-lock-handler` (system side, `modules/nixos/lock-before-sleep.nix`) holds a logind sleep delay-inhibitor and bridges to a user-level `sleep.target`; the `noctalia-lock-on-sleep` oneshot engages the lock before any suspend proceeds — idle-fired, `systemctl suspend`, or a future power-key *(probe S5: journal ordering + user sleep.target activation)*. v5 honours `loginctl lock-session` (the logind session Lock signal), which v4 did not. Residual: if the shell is dead nothing locks — but nothing idle-suspends either.

**Wake-from-suspend needs physical presence until the WoL follow-up lands.** Magic packets are L2 (tailscale can't deliver them); enablement waits on the planned always-on LAN peer. Until then the caffeine switch and the guard are the reachability protections. NIC capability is recorded at validation *(probe S1)*.

## Sharp edges

- **Beta seams, re-verified per bump.** Four upstream-facing seams — palette schema, `[theme]` keys, the IPC verbs, override semantics — are facts of the pinned tag, not upstream commitments. The per-bump ritual (caffeine probe pair + seam re-check + a `nix build` of the package against the pin) is part of any bump, and C0 re-runs on nixpkgs moves too.
- **The overrides layer is a standing foot-gun.** `settings.toml` beats `config.toml` wherever it holds a key and is Nix-unreachable by design. The seam keeps the family axis out of it entirely and reconciles the one echoed key; GUI theme picks re-open the channel until cleared (see Must-not-touch above).
- **`action` strings in `[idle.behavior]` are not schema-validated** — a typo silently becomes command mode; `validateConfig` will not catch it.
- **Notifications**: v5 claims `org.freedesktop.Notifications` by default and throws if another daemon owns the name (fnott is long decommissioned; nothing competes).
- **Clipboard**: native wlr-data-control implementation — no cliphist, no wl-clipboard in v5's tree. `pkgs.wl-clipboard` stays on the session PATH purely for CLI consumers (gh-dash's `y`, scripts; docs/desktop/clipboard.md #360). History is encrypted at rest against the Secret Service (gnome-keyring on metis) *(probe C3)*.
- **Lock PAM**: hardcoded to the `login` service (`NOCTALIA_PAM_SERVICE` is gone). Fine on NixOS — `/etc/pam.d/login` exists; fingerprint is native fprintd D-Bus, not PAM-stack swapping.
- **Polkit**: v5 ships a built-in agent, default **off** — metis keeps mate-polkit; don't enable both.
- **Fonts**: v5's chrome resolves through the fontconfig `sans-serif` generic (`shell.font_family` default) — the `set-font` conductor reaches it, runtime-verified (probe C6: a generic remap rendered in the bar after a shell restart). Faces are cached at process start — no live follow; `set-font`'s hint + `--reload-shell` restart (`home/nixos/set-font.nix`) is the apply path. One open observation: a restart spawned by `set-font` itself once missed a just-written remap that a compositor spawn then picked up — low-stakes follow-up, the restart machinery itself is proven.
- **Single instance**: a second `noctalia` spawn aborts on the instance lock — benign with compositor-spawn.
- **PipeWire + WirePlumber** are hard runtime companions (upstream-documented; both active on metis).

## References

- [docs/design/noctalia-v5-migration.md](../design/noctalia-v5-migration.md) — the accepted design note: mechanism, forces, De-risk evidence, probe plan; its §De-risk links the three frozen adversarial reviews in `docs/research/`.
- [ADR-036](../decisions/ADR-036-noctalia-shell-linux-desktop.md) — the shell adoption (v4-era mechanics superseded; the shell role stands). [ADR-044](../decisions/ADR-044-linux-runtime-theme-menu.md) — Nix as theming authority; its v5 amendment records the palette-seam change.
- `home/nixos/noctalia.nix` (module + baseline + guard + hook + lock-on-sleep unit) · `home/nixos/theme-menu.nix` (the conductor + `theme` CLI) · `modules/nixos/lock-before-sleep.nix` (system half).
- [waybar.md](./waybar.md) / [fuzzel.md](./fuzzel.md) / [fnott.md](./fnott.md) / [screen-lock.md](./screen-lock.md) / [power-session.md](./power-session.md) — the per-tool stack subsumed on the Linux desktop; historical records and the non-Noctalia fallback.
- Noctalia upstream — https://github.com/noctalia-dev/noctalia (v5; `legacy-v4` holds the retired v4 line).
