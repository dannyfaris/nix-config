# Clipboard persistence and history

Clipboard handling for the niri desktop on metis (#99): copied content surviving the source application closing, plus recall of recent copies. metis had no clipboard manager before this — closing the app you copied from lost the clipboard, and there was no history. The primary (highlight/middle-click) selection and a `wl-clip-persist`-style transparent-paste daemon are deliberately out of scope — see Sharp edges.

## Selection

**clipse** (a Go/BubbleTea TUI clipboard manager), wired via the `services.clipse` home-manager module imported through the desktop-env home bundle:

- **One daemon does both jobs.** `clipse -listen` (a systemd user service bound to `graphical-session.target`) watches the regular clipboard and records each change to its on-disk history store, so content is recoverable after the source app closes.
- **Recall is a TUI in a floating foot popup** — `Hyper+C` spawns `foot --app-id=popup.clipse -e clipse`, floated/sized/centered by the shared popup `window-rule` ([popups.md](./popups.md), #308).
- **Version: clipse 1.2.1**, reached via a local `overrideAttrs` until our channel catches up to the merged upstream bump (see Configuration).
- **Regular clipboard only**; **no** `wl-clip-persist`; **no** dedicated wipe keybind (the `clipse -clear` command serves that).

## Rationale

**One tool covers both halves of the issue.** Wayland's clipboard is served by the *source* client, so closing that client loses the live selection (the "persistence" problem), which is distinct from recalling past copies (the "history" problem). The conventional wlroots answer splits these across two daemons — `cliphist` for history and `wl-clip-persist` for persistence — which the field notes can race each other. clipse's single listener records history (so content is always recoverable after close) without a second watcher. One daemon, one config, no dual-watcher race.

**TUI-in-foot fits the posture and avoids GUI theming.** The rest of the desktop's tools are small and Wayland-native; a terminal TUI extends that to the clipboard. Unlike `helix`, `bat`, and `yazi` — each of which has a *dedicated* Stylix target writing a full base16 mapping — clipse has **no** Stylix target, so it does not get full-palette theming for free. What it does get, running in foot, is foot's Stylix-set ANSI colors, which is enough for terminal-level cohesion and sidesteps the libadwaita/GTK theming problem a GUI mixer would pose. The `services.clipse` `theme` option defaults to `useCustomTheme = false` (terminal-inherited ANSI); we keep that default — best-effort cohesion is acceptable for an occasionally-opened popup, and a full base16 map can be added later via the module's `theme` option if it ever feels worth it.

**It applies the popup convention rather than inventing placement.** The recall window is a floating sized-popup, the exact case [popups.md](./popups.md) (#308) was written for — and that doc names #99 as its first consumer. So clipse conforms by adopting the `popup.clipse` app-id; the shared `^popup\.` `window-rule` (which lands with this work, per the convention) floats, focuses, centers, and proportionally sizes it. No bespoke geometry, and clipse's listener-on-disk / stateless-picker split is exactly why spawn-fresh is state-equivalent here (popups.md §Spawn-fresh vs persistent-toggle).

**niri supports the protocols it needs.** Clipboard managers watch the selection via a wlroots-style data-control interface; niri exposes clipboard access over both `wlr-data-control` and the newer `ext-data-control` (documented in niri's own [Security Model](https://niri-wm.github.io/niri/Security-Model.html), which lists "get the user's clipboard contents via wlr-data-control" and links the `ext-data-control-v1` protocol), and the read path was **verified live on metis at niri 25.08** — a manager connects and reads the selection. So clipse functions here without compositor-specific glue.

**Security was analysed but is not a differentiator between managers.** See "Sensitive content" — on niri, neither clipse nor cliphist can exclude by source app, so the choice between them rests on UX + architecture, where clipse's single-daemon TUI wins for this operator. (The mitigation posture *as a whole* is load-bearing, and the GUI-only shape of #112 reshaped it — that analysis is below.)

## Alternatives considered

**cliphist + wl-clip-persist (recalled via `fuzzel --dmenu`).** The de-facto wlroots/niri stack, and both halves have clean home-manager modules. Passed over for clipse on UX and architecture, not correctness: it is two daemons (history + persistence) with a documented race risk, and a dmenu line rather than the TUI this operator prefers. It remains the conventional fallback if clipse's single-daemon persistence proves insufficient (see Sharp edges). It is also currently *more* up-to-date in our channel than clipse — a real cost clipse carries (see Configuration).

**clipman.** The older wl-paste-based manager; the original is archived and it is text-only (no images). Superseded by cliphist/clipse for any forward-looking stack.

**copyq.** A heavy Qt GUI clipboard manager with a persistent tray process — antithetical to the minimal, Wayland-native posture, and it carries its own history-of-secrets issues. Not considered seriously.

## Sensitive content

This is the load-bearing part of the decision, and the #112 re-scope changed it. A clipboard *history* is a plaintext log of everything copied, including passwords. Two findings, verified against the exact pinned versions:

**clipse's `excludedApps` exclusion is inert on niri.** clipse detects the source app by querying the focused window via `wlrctl` or `hyprctl` only; it has no niri-IPC path, so the default 1Password/Bitwarden/KeePassXC exclusion list silently does nothing on niri (confirmed in clipse's source). The Wayland data-control protocol carries no source-app identity, so this is a general limitation — `cliphist` cannot exclude by app either. **clipse is therefore no safer out of the box than cliphist here.** (The `services.clipse` module does not even surface an `excludedApps` option, so it is not reachable declaratively regardless.)

**The only automatic protection is the sensitive-hint chain**, and on our pins it is gated on the clipse version:

| Link | Pin | Status |
|---|---|---|
| 1Password GUI marks copies sensitive (`x-kde-passwordManagerHint`) | GUI 8.12.x | ✅ — Wayland secure-clipboard landed in [8.11.0](https://releases.1password.com/linux/8.11/) (2025-07-08), sensitive-marking "for clipboard daemons and managers" in 8.11.2 (2025-07-22); but the hint is documented as scoped to KDE's data-control path, so delivery over niri's `wlr-data-control` is **unverified** |
| `wl-clipboard` translates it → `CLIPBOARD_STATE=sensitive` | 2.3.0 | ✅ (2.3.0 is the version that added this) |
| clipse honors `CLIPBOARD_STATE=sensitive` | **1.2.1** (pinned) | ✅ — the handler was added in **v1.1.1**; our channel ships 1.1.0, so this rides the override (see Configuration) |

**Mitigation posture (layered) — narrowed by #112's GUI-only delivery:**

1. **Behavioral (reliable, but narrower than first planned):** the 1Password **GUI** (#112) autofills browser and app logins, so those passwords are entered without ever reaching the clipboard. This is the durable protection *for the credentials autofill covers*. It is narrower than the original #99 plan assumed: that plan leaned on the 1Password **SSH agent** + `op run` / `op read` to keep *arbitrary* secrets off the clipboard, but #112 was re-scoped to GUI-only — the SSH agent was **rejected** and the `op` CLI **deferred** (#364), so secret-injection tooling is not part of the posture today ([1password.md](./1password.md) §"NixOS desktop adoption", Decisions 2 + 4). Autofill does not help a token echoed in a terminal, a manually-typed-then-copied password, or any non-1Password app.
2. **Automatic backstop (best-effort, now more load-bearing):** the hint chain above. Because behavioral coverage shrank to autofill-only, this backstop carries more of the weight than the original plan intended. It is contingent on clipse ≥1.1.1 (satisfied by the 1.2.1 pin) **and** the niri-delivery verification passing — and that test needs the 1Password GUI as a password source, which #112 now provides (pending #112's own on-box smoke test).
3. **Manual hygiene:** `clipse -clear` (and `-clear-all`) as a documented panic-wipe **command**, plus a small `maxHistory` cap. No wipe keybind day-1 — the command suffices for a rare action, and a bind would spend a scarce `Hyper`-namespace slot.

**Residual risk we accept (a notch higher than the original plan):** the uncovered surface noted above — anything outside autofill's reach — is stored unless the hint chain catches it, and the hint chain fires only for 1Password GUI copies and only if niri delivery is verified. The durable protection is behavioral (autofill keeps managed logins off the clipboard); the hint chain is the best-effort backstop for GUI copies; everything else relies on `maxHistory` + manual wipe.

## Configuration

**Home — `services.clipse`** (imported via the desktop-env home bundle):

- `services.clipse.enable = true` — wires the `clipse -listen` systemd user service, the generated `config.json`, and `custom_theme.json` (`useCustomTheme = false`, terminal-inherited).
- A small `historySize` (`maxHistory`) cap to bound retention; `theme` left at the terminal-inherited default.

**The clipse 1.2.1 override — a short-lived channel bridge.** The upstream bump **already merged** — nixpkgs PR #528630 (`clipse: 1.1.0 -> 1.2.1`, 2026-06-10) is on `master` and `nixpkgs-unstable` — but our `nixos-unstable` input still ships **1.1.0** (channel-propagation lag; verified 2026-06-16). A `nix flake update` today would not yet deliver 1.2.1. Two equally-honest paths: (a) **time the implementation** to land after `nixos-unstable` advances past the merge, at which point a plain lockfile update delivers 1.2.1 and **no override is needed**; or (b) if implementation runs first, point `services.clipse.package` at a local `clipse.overrideAttrs` bumping `version`/`src`/`vendorHash` to 1.2.1 (hashes lifted from the merged PR), carried with a dated comment and **deleted once the channel catches up**. The override is a *bridge over channel lag*, not an upstreaming task — the upstream work is done. Either way 1.2.1 is required (the `CLIPBOARD_STATE` handler exists only in ≥1.1.1).

**niri popup (via the #308 convention).** The recall popup is `foot --app-id=popup.clipse -e clipse`, bound at the keybind site; the shared `^popup\.` `window-rule` from [popups.md](./popups.md) floats it, focuses it, centers it, and sizes it to the proportional default (0.5 × 0.5, tunable). That rule lands with this work as the convention's first consumer — it is not bespoke to clipse, and niri already carries other `window-rule`s (e.g. the corner-radius rule in `niri.nix`), so this is an application of an established pattern, not a new mechanism.

**The `Hyper+C` recall bind.** `Hyper` is the philosophical home for clipboard commands (keybinds.md names clipboard among the niri-specific `Hyper` binds still to land — §Cross-platform Hyper mapping), and `Hyper+C` is free and mnemonic. keyd realizes the `Hyper` modifier on metis ([keyd.md](./keyd.md), #282, landed), so the chord fires. It lands as a keybinds.md row first (doc-before-code), then as a spawn bind in `niri.nix`. There is no `Super`-side detour to retire: `Mod+C` is reserved for the copy app-command, and Hyper is live, so the bind goes straight to its correct home.

## Sharp edges

**`excludedApps` is false security on niri.** The default list looks protective but does nothing here (no niri focus-detection path), and the `services.clipse` module does not surface it anyway. Do not rely on it; rely on the layered posture above.

**The automatic backstop cannot be trusted until verified on the box — and #112 must be verified first.** The hint chain's load-bearing link (does 1Password's `x-kde-passwordManagerHint` reach niri's `wlr-data-control`?) is unverified, and the test needs the 1Password GUI working on metis. #112 is implemented (PR #367 merged) but **open pending its own on-box smoke test** (polkit unlock + Firefox autofill); until that passes there is no trustworthy password source to test against. Treat the backstop as unproven until both #112 is verified and the test below passes.

**Verify on metis (at implementation, from the physical session):**
- Copy a password from the 1Password GUI, then `wl-paste --list-types` — does `x-kde-passwordManagerHint` appear? If not, 1Password is not delivering the hint over `wlr-data-control` and the automatic backstop does not protect even GUI copies (fall back to layers 1 + 3).
- Copy from an app, close it, and paste *without* opening the TUI — does the live clipboard survive? If yes, clipse's own persistence is sufficient. If no, recall-via-TUI still meets the user story; add `wl-clip-persist` only if transparent paste is wanted.

**Regular clipboard only.** Watching the primary (highlight) selection would log every text selection — noise and a far larger secret surface — so it is deliberately not enabled.

**Channel staleness is a carried cost only if the override is used.** If implementation runs before `nixos-unstable` advances, the override builds clipse locally (no binary cache for it) and must be kept in lockstep until the channel catches up. It is a small Go package, so the build cost is negligible; the maintenance is the real (bounded, short-lived) cost — and timing the work to after the channel advances avoids it entirely.

## References

- [popups.md](./popups.md) (#308) — the floating sized-popup convention this work is the first consumer of; owns the `popup.clipse` app-id + `^popup\.` `window-rule`, the proportional sizing, and the spawn-fresh decision.
- [1password.md](./1password.md) (#112) — the password manager whose GUI-only adoption provides the behavioral mitigation layer and the password source for the backstop test; Decisions 2 (SSH agent rejected) + 4 (`op` deferred) are why that layer is autofill-only.
- [keybinds.md](./keybinds.md) — modifier-namespace philosophy; gains the `Hyper+C` clipboard row (the niri-specific `Hyper` binds).
- [keyd.md](./keyd.md) (#282) — realizes the `Hyper` modifier on metis that the recall bind depends on.
- [screen-lock.md](./screen-lock.md) — the same minimal/native posture applied to another surface; [foot.md](./foot.md) — the terminal clipse runs in.
- clipse (savedra1) — Go/BubbleTea TUI manager; `CLIPBOARD_STATE=sensitive` handler added v1.1.1; `excludedApps` (v1.2.0) detects the focused app via `wlrctl`/`hyprctl` only.
- nixpkgs PR #528630 (`clipse: 1.1.0 -> 1.2.1`, merged 2026-06-10) — the upstream bump; on `master`/`nixpkgs-unstable`, awaiting `nixos-unstable` propagation. The override (if used) is dropped once the channel carries it.
- `wl-clipboard` 2.3.0 — first version translating `x-kde-passwordManagerHint` → `CLIPBOARD_STATE=sensitive`. 1Password's end of the chain: Wayland secure-clipboard added in [8.11.0](https://releases.1password.com/linux/8.11/) (2025-07-08), sensitive-marking for clipboard daemons in 8.11.2 (2025-07-22).
- niri data-control support — `wlr-data-control` + `ext-data-control`, per niri's [Security Model](https://niri-wm.github.io/niri/Security-Model.html); read path verified live on metis (niri 25.08).
- home-manager `services.clipse` (listener + config + theme).
- #364 — GitLab plaintext-token cleanup; the deferred-`op` candidate use, to be served by sops.
- ADR-028 (Stylix as surface source-of-truth), ADR-029 (niri-only desktop).
