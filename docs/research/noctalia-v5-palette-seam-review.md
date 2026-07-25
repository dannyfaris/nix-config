# Noctalia v5 palette seam — adversarial review of the delivery-mechanism candidates

Status: **research note, not a decision.** Captured 2026-07-25 from an adversarial design-review pass (AI subagent; source-read against `noctalia-dev/noctalia` @ tag `v5.0.0-beta.4` = commit `4c2dcd0995f9c570c0ced95561bf5e4685e2ad1b`, cross-checked with `home/nixos/theme-menu.nix` and ADR-044) during the #644 design loop. The review adjudicates two candidate architectures for re-wiring ADR-044's themed-by-Nix seam against v5 (v4's watched `colors.json` has no v5 read path) and surfaces the hybrid that the design adopted. The decision lands in [`../design/noctalia-v5-migration.md`](../design/noctalia-v5-migration.md) §Design/§Rationale; this note freezes the full argument. **Candidate A** was the catalogue-as-`customPalettes` + IPC-name-switching design; **Candidate B** the conservative mutable-file port; the recommendation is the constant-name symlink hybrid.

---

## Key source findings that drive the verdict

1. **IPC theme writes persist unconditionally.** `setThemeMode`/`setThemeColorScheme` (`src/config/config_overrides.cpp:884–960`) do `insert_or_assign` into the overrides table → write settings.toml → `loadAll()` → fire callbacks. There is **no pruning** on this path: `overridePathEffectiveInTable`/`clearOverride` exist but are only invoked from GUI reset paths. Once the first IPC switch lands, `config.toml [theme]` is permanently shadowed.
2. **`config-reload` is unconditional.** `forceReload()` (config_service.cpp) → `loadAll` + `fireReloadCallbacks` with no changed-check → `ThemeService::onConfigReload` → `resolveAndSet(animate=true)`, which **re-reads the custom palette file from disk every resolve** (theme_service.cpp:461–466, plain `std::filesystem::exists` + ifstream parse — symlink chains are transparent). Missing/invalid palette → log-warn + builtin fallback.
3. **Watcher scope confirmed:** inotify covers config-dir `*.toml`, symlink-target parents, and the state-dir settings.toml (config_service.cpp:1104–1165). `palettes/*.json` never fire events (non-recursive, non-toml).
4. **IPC socket fallback is a footgun:** with `WAYLAND_DISPLAY` unset (SSH), the client guesses `wayland-0` (ipc_client.cpp:24–28) — it may silently hit the **live** socket or a dead one depending on niri's display number. "IPC no-ops over SSH" is an unverified assumption.
5. A `started` hook kind exists (`[hooks] started`, config_types.h:1259) — a possible reconcile seam.

## (1) Candidate A — strongest failure modes

**A1. The boot-default claim is false after the first ever switch.** *Severity: high. Likelihood: certain.* Every `color-scheme-set`/`theme-mode-set` persists to settings.toml, which wins over config.toml forever. "Fresh provision boots into the right palette from config.toml" holds only on virgin installs. From switch #1 onward, Noctalia's effective family is *its own last-persisted copy* of the conductor's state — a permanent authoritative duplicate.

**A2. Shell-down switch → durable split-brain.** *Severity: high. Likelihood: routine* (theme switch after shell crash, from SSH, or pre-spawn). Pointer moves, foot/niri/gtk repaint; IPC fails; Noctalia restarts on the stale settings.toml family and *keeps re-persisting it*. Nothing self-heals until the next successful `theme` run inside a session. This is not an edge case — it is A's normal degradation mode, because A *duplicates the family axis into state the conductor doesn't own*.

**A3. GUI picker becomes an attractive nuisance.** *Severity: medium. Likelihood: medium.* `customPalettes` populates the v5 picker with the whole catalogue; picking one now *works*, repaints Noctalia only, and persists — visible cross-surface split-brain (foot/niri/gtk stay put). ADR-044's "inert-by-convention" stance was tenable when the picker did nothing; in A it half-works, which is worse than either extreme. Mitigation: none technical; convention only.

**A4. Family removal/rename → builtin-theme surprise.** *Severity: medium. Likelihood: low.* A stale `custom_palette` name in settings.toml (which Nix cannot reach) → silent builtin fallback with only a log warning. Recovery needs a runtime IPC/GUI action, not a rebuild — the one state Nix can't repair.

**A5. Largest beta surface.** Four upstream seams: palette schema, two theme IPC verbs + their persistence semantics, settings.toml override behaviour, `[theme]` config keys.

Mitigation for A1/A2 exists — a reconcile at shell spawn (wrapper or `started` hook) re-issuing IPC from the pointer + dconf — but it adds a moving part to paper over state duplication that B and the hybrid simply don't create.

## (2) Candidate B — strongest failure modes

**B1. Polarity axis still drifts shell-down** (if using `theme-mode-set`): `theme light` while shell is down → dconf flips, `theme.mode` override stale → shell restarts dark. *Severity: medium, likelihood: low-medium.* Baking polarity into the file instead corrupts Noctalia's `m_isLightMode` (icon colorization/contrast logic reads the resolved mode) — reject that variant. So B needs one small IPC-persisted key after all, or a mode-only startup reconcile.

**B2. Runtime file mutation + copy machinery retained** — tmp+mv, seed handling, a mutable regular file in `~/.config/noctalia/palettes/`. *Severity: low.* Note the GUI's own palette-save writer targets the same directory; a name collision on "theme-menu" would clobber (unlikely).

**B3. GUI drift still possible:** a GUI scheme pick writes `theme.source` override and B's file+reload becomes inert until the override is cleared. *Same exposure as A3 in kind*, but the picker shows only one drab "theme-menu" entry — much less attractive, and B's constant reference means recovery is a single override-clear, after which everything is instantly correct.

**B4. Rebuild-staleness slightly worse than A:** after a colours-only rebuild, B's on-disk file is stale until the next `theme` run, and even `config-reload` won't help. In A, `config-reload` suffices. *Severity: cosmetic.*

Crucially, B survives attack #2 cleanly: shell-down switch leaves a correct file on disk; startup reads it; `config-reload` failing is harmless. B's mutable file is a *cache of conductor state with no authority*; A's settings.toml entry is an *authoritative duplicate*. Duplicated authority is the drift engine.

## (3) A hybrid that dominates both

**Symlink-delivered constant-name palette.** Seed creates `~/.config/noctalia/palettes/theme-menu.json` → `$stateDir/noctalia.json` → a per-family artefact (`dark`+`light`+`terminal`, real colours for both). `config.toml` pins `source="custom"`, `custom_palette="theme-menu"`, `mode="<boot polarity>"`. `theme` CLI: repoint (already happens for every other target) + `noctalia msg config-reload` + `theme-mode-set <p>` on polarity change. Do **not** declare the catalogue via `customPalettes` (avoids A3's nuisance picker).

Why this is now possible: v4's copy-into-place existed *only* because the colors.json watcher couldn't see symlink swaps. v5 has **no palette watcher at all** — an explicit trigger is required regardless (finding 3), so the symlink-invisibility problem is moot, and finding 2 confirms `config-reload` unconditionally re-reads the file through any symlink chain. The palette joins the per-target resolved-symlink pattern foot.ini/niri.kdl/gtk*.css already use. No mutable regular file, no copy step, store-content artefacts, shell-down safe on the family axis, conductor never writes settings.toml, one 400 ms animation per switch (`resolveAndSet(animate=true)` fires once).

Residual: the polarity axis (B1) — `theme-mode-set` persists a benign single-key override that can go stale shell-down. Acceptable as-is (self-heals on any next switch), or closed with a one-line mode-only reconcile in the spawn wrapper reading dconf. Upstream seams: palette schema, `[theme]` keys, `config-reload`, `theme-mode-set` — smallest surface of the three (and `config-reload` is the most churn-proof IPC verb imaginable).

## (4) Recommendation

**Reject A; adopt the hybrid (B's constant-reference shape, symlink-delivered).** Deciding argument: A re-creates, at the Noctalia seam, exactly the pathology ADR-044 was written to kill — the live selection duplicated into GUI-managed, non-git, Nix-unreachable state (settings.toml is v5's settings.json). Every A failure mode (A1, A2, A4) is a corollary of that duplication; the hybrid stores the family selection in precisely one place (the conductor's pointer) and hands Noctalia only a dereference.

**Mandatory on-metis probes before calling it done** (per the set≠enforced convention):

1. **Symlink-chain read:** create `palettes/theme-menu.json` → chain → store artefact; set config.toml `[theme]`; start shell → correct palette, no `falling back to builtin` in logs.
2. **Explicit trigger:** `theme <other-family>` (repoint + `noctalia msg config-reload`) with shell up → single ~400ms repaint; confirm **no** repaint occurs on repoint alone (validates no-hot-reload).
3. **Shell-down switch:** kill noctalia; `theme <family-2>`; relaunch via niri spawn → shell comes up on family-2; check `~/.local/state/noctalia/settings.toml` → confirm no `source`/`custom_palette` keys were ever persisted.
4. **Polarity:** `theme light` → `theme-mode-set` observed in settings.toml (`mode` key only); restart shell → mode survives; then shell-down `theme dark` → document the stale-mode window and whether the wrapper reconcile is warranted.
5. **Socket fallback:** from SSH (`set -e WAYLAND_DISPLAY` in fish), run `noctalia msg config-reload`; `ls $XDG_RUNTIME_DIR/noctalia-*.sock` to learn niri's actual display name — determine whether the `wayland-0` guess hits the live socket (if yes, SSH switches work for free; if no, confirm clean non-fatal error).
6. **Fallback visibility:** point `custom_palette` at a missing name once → confirm builtin fallback + log warning, so the failure signature is recognisable.
7. **Reload side-effects:** watch bars/OSD during `config-reload` for layout flicker; if disruptive, note it as the cost vs A's targeted IPC (the one dimension A genuinely wins).

*(Post-review notes, recorded at freeze time: probe 6 as phrased was later found impossible — `color-scheme-set` validates palette existence and refuses missing names; the design note's V6 reformulates it as a broken-symlink + `config-reload` probe. The design adopted the `started`-hook variant of the mode reconcile, and a single polarity-independent per-family artefact rather than per-polarity variants. See the design note §De-risk and the [de-risk audit](./noctalia-v5-derisk-audit.md).)*
