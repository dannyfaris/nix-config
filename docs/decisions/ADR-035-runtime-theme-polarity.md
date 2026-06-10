# ADR-035: Runtime theme/polarity selection over the declarative Stylix base (metis)

**Date**: 2026-06-09
**Status**: Proposed

> Introduces the repo's first sanctioned runtime/session-state layer: a [tinty](https://github.com/tinted-theming/tinty)-driven runtime selector for theme and polarity on metis, layered *over* — not replacing — the declarative Stylix base. Stylix stays source-of-truth for palette depth, fonts, the boot default, and a Nix-pinned theme menu; the runtime layer owns the live selection on surfaces that can re-theme without a rebuild. Scoped to metis; headless hosts and mac-mini are excluded. Resolves the design half of #143.

## Context

Theming is fully declarative today (ADR-028, amended by ADR-029): `lib/host-palettes.nix` declares one polarity and a paired dark/light scheme per host, Stylix renders every target's config at activation, and changing the look means editing Nix and running `nh os switch`. The operator wants an *interactive* polarity flip (and, more loosely, a theme switch) — a keybind or command that re-themes the desktop with no perceptible wait and no rebuild (#143, "subjectively-instant" non-functional constraint).

That want sits on a category line. A rebuild-to-retheme model treats the active look as persistent desired state. But "which polarity do I want *right now* because the room is bright" is **session state** — the same category as screen brightness, volume, or the focused workspace, none of which live in a NixOS config. Stylix is structurally build-time (it renders files at activation; it has no runtime API), upstream has no native toggle ([stylix#447](https://github.com/nix-community/stylix/issues/447), open since 2024), and the Nix-native alternative — home-manager specialisations — carries poor operator UX (pre-built generations, a fragile toggle script grepping `home-manager generations`, `mkForce` collision management, a fish re-login footgun). The question this ADR settles is the *shape* of a runtime layer that delivers the interactive flip without becoming a second source of truth that drifts from the declarative base.

## Decision

Adopt a runtime selection layer — tinty — on metis, as a **delta over the Stylix base, not a replacement**. The declarative/runtime split:

- **Declarative (Stylix) owns persistent desired state**: the boot default, palette *depth* (GTK/Qt base16, fonts), and — fed a **Nix-pinned local scheme + template set** via tinty's local-`path` items — the *menu* tinty selects from. The theme content stays reproducible and offline (no runtime git-clone); only the *selection* is runtime.
- **Runtime (tinty) owns the live selection**: ephemeral session state that resets to the declared default on a clean boot and is re-applied at login. A delta over a declarative base does not drift, because the base is authoritative on boot and the delta is transient.

**Scope is metis only.** Headless hosts (mercury, nixos-vm) keep build-time polarity as *host identity* — the per-host hue that signals which box an SSH session is on — which is not a thing to toggle. mac-mini is excluded: tinty reaches only the terminal on macOS, so the layer buys almost nothing there.

**Per-surface application splits by integration class** (mechanisms verified on metis 2026-06-09; the on-screen repaint for foot/helix/waybar is console-pending per #143):

- **Class 1 — IPC / signal / in-memory** (no file dependency, preferred): fish (universal variables — confirmed live), zellij (first-party `zellij action toggle-theme` IPC — machine-verified present), and the GTK/libadwaita/browser surface via the portal `color-scheme` dconf key (proven in `9aea882`); plus foot (`SIGUSR1`/`SIGUSR2` dual-theme + OSC), helix (`SIGUSR1`), and waybar (`SIGUSR2`) — these three mechanism-present, on-screen confirmation console-pending.
- **Class 2 — file-watch** (needs a real, non-symlink file): niri only. Resolved with a *materialise-real-file* activation primitive that reuses the `home/shared/agent-clis.nix` jq-merge pattern (ADR-024 lineage), KDL line-edit variant — which also makes the runtime selection **survive `nh os switch`** by preserving the runtime-owned theme line across rebuilds.
- **Class 3 — ephemeral / next-launch** (free): fuzzel, swaylock, bat, fzf, lazygit, yazi, and starship read their config per invocation, so the next launch is themed. fnott is the lone exception — a long-running daemon that holds its theme in memory but has no visible state between notifications, so a silent `systemctl --user restart fnott` in the hook suffices.

**Polarity is the first-class axis; arbitrary-scheme is a lesser convenience.** A polarity flip reaches the whole *reachable* surface near-instantly (terminal, TUI, GTK/browsers). An arbitrary-scheme swap (e.g. rose-pine → gruvbox) reaches terminal/TUI live but leaves GTK/Qt *depth* on the build-time palette — a split-brain desktop. So the menu is polarity-first; arbitrary-scheme switching is offered as a terminal/TUI convenience, not a whole-desktop guarantee.

## Rationale

**vs home-manager specialisations** — rejected on UX. It shares this ADR's declarative-base/runtime-delta philosophy, but the operator surface of the [documented HM-specialisations approach](https://pltanton.dev/posts/nix-based-dark-light-theme-switch/) (pre-build both generations, a toggle script over `home-manager generations`, `mkForce` collision management, a fish re-login step) is materially worse than `tinty set` / a `toggle-theme` keybind. Kept as the documented fallback if tinty proves unreliable.

**vs pure-Stylix rebuild (status quo)** — rejected. A rebuild is minutes, not interactive, and fails #143's instant-toggle constraint outright.

**vs tinty as a full Stylix replacement** — rejected. tinty is base16-colours-only (no GTK/Qt depth, fonts, or wallpaper), imperative, and has no home-manager module; replacing Stylix with it is a downgrade on every host and an inversion of the declare-first ethos. The hybrid (Stylix base + tinty delta) keeps one source of truth for depth and a reproducible menu while still delivering the runtime flip.

**Why the boundary is not a breach of declare-first.** The concern that a runtime layer competes with `host-palettes.nix` for authority dissolves once polarity is seen as session state: the declarative base owns boot/default/depth, the runtime delta owns the live moment, and the base stays fully reproducible. No deliberate stance (CLAUDE.md §"Deliberate stances — do not relax without asking") is relaxed: the declared `stylix.polarity` in `host-palettes.nix` remains the authoritative boot default and source of truth on every host — the metis runtime delta is additive and metis-scoped, overriding only the *live* surface, never the declared value, and never the headless hosts' identity polarity. This is the same model the repo already runs for mutable app config — `home/shared/agent-clis.nix` merges a declarative key into a file the app writes at runtime (ADR-024) — the same real-file-materialise + preserve-runtime-key *shape* the Class-2 primitive reuses (jq object-merge → KDL line-edit variant).

**Why metis-only.** The runtime need is metis's. On headless hosts polarity is identity, not preference; on macOS tinty's reach is too thin to justify the layer.

## Consequences

- ✓ Near-instant operator polarity flip across the reachable surface (terminal, TUI, GTK/browsers) via keybind or CLI, no rebuild — the #143 goal, for polarity — once the prerequisite wiring below (foot `[colors-light]`, zellij `theme_dark`/`theme_light`) lands.
- ✓ Theme content stays Nix-pinned and reproducible; only the live selection is runtime state. One source of truth for depth and the menu.
- ✓ The Class-2 materialise primitive reuses an existing blessed pattern (ADR-024) and doubles as the survives-`nh os switch` mechanism the issue requires.
- ✓ The repo's runtime/session-state boundary is now explicit and documented — a precedent for future session-state needs (brightness, etc.) rather than an ad-hoc exception.
- ✗ This is the repo's **first sanctioned imperative/runtime-state layer** — a genuine posture shift from declare-everything. It adds a tinty config plus per-surface hooks to maintain, and a small class of state (the live selection) deliberately not captured in git.
- ✗ **Qt does not follow the portal polarity key** under the current `qt5ct` platform theme (qt5ct/qt6ct theme from their own config; only the `gnome` platform theme subscribes). Qt apps won't join a polarity flip unless the platform theme moves to `gnome`/qgnomeplatform — which themes Qt differently and trades base16 *depth* for *polarity*-following. Sub-decision deferred, not made here.
- ✗ **Arbitrary-scheme swaps are terminal/TUI-only live**; GTK/Qt depth stays on the build-time scheme until a rebuild. Polarity is the only whole-(reachable)-desktop-coherent runtime axis.
- ✗ **niri needs the materialise primitive** (no IPC theme action; config is a store symlink). Until niri colours are Stylix-wired (#110) this is latent work, not immediately exercised.
- ✗ **Wiring prerequisites exist before the layer is usable**, all independent of tinty: foot's generated config is `[colors-dark]`-only and needs `[colors-light]`/`[colors2]`; zellij's `config.kdl` defines no `theme_dark`/`theme_light` (and appears to select no Stylix theme at all today — worth confirming separately); and the Qt platform-theme question above.
- ✗ **Runtime-applied schemes bypass the per-host slot corrections** of ADR-028 §History (2026-06-10, #331) — tinty applies upstream scheme files, so a runtime swap on metis would reintroduce the rose-pine `09==0E` collision (and lose mercury's corrections) on rethemed surfaces until the implementation feeds tinty corrected scheme files rather than raw upstream ones.
- ⚠ Migration triggers: (a) Stylix ships a native runtime polarity mechanism (stylix#447 lands) → revisit whether tinty is still warranted; (b) tinty proves unreliable or unmaintained → fall back to home-manager specialisations for polarity only; (c) the operator finds arbitrary-scheme split-brain unacceptable → constrain the menu to polarity pairs and drop arbitrary-scheme switching.

## Implementation

Plan-state; lands after the console-pending verifications in #143 and the prerequisite wiring above.

- **A metis-scoped module** installing tinty with a Nix-rendered `config.toml` whose `[[items]]` use local (Nix store) scheme + per-tool template `path`s, and `default-scheme` set to the host default — so `tinty list`/`set` only ever offer the curated, pinned menu.
- **A `tinty set`/`toggle` hook** that: applies base16 to the terminal/TUI surface; sends the Class-1 signals (foot `SIGUSR`/OSC, helix `USR1`, waybar `SIGUSR2`); calls `zellij action toggle-theme` / `set-{dark,light}-theme`; writes the portal `color-scheme` dconf key for GTK/browsers; silently restarts fnott (`systemctl --user restart fnott`); and (later, per #109) `swww img` for wallpaper.
- **The materialise-real-file primitive** for niri: a `home.activation` step in the `agent-clis.nix` lineage that copies the home-manager-rendered KDL to a real path and preserves the runtime-owned `theme` line across rebuilds (the survives-`nh os switch` guarantee). It inherits the same read-then-rename race agent-clis documents (`agent-clis.nix:109-112`; accepted in ADR-024 / #172): a runtime write landing between the activation read and the atomic rename is lost — tolerable because `nh os switch` is operator-driven and rare.
- **Operator trigger**: a niri keybind → fuzzel theme picker for the menu, and/or a direct `toggle-theme` keybind for the binary polarity flip.
- **Prerequisites to land first**: wire foot `[colors-light]`; add zellij `theme_dark`/`theme_light`; resolve the Qt platform-theme decision.
- **Open verifications** (console-pending, tracked in #143): helix `USR1` visual, foot `SIGUSR`/OSC visual, waybar repaint, Qt visual confirm, niri real-file reload.

Cross-references: ADR-028 / ADR-029 (the Stylix declarative base this layers over); ADR-024 (the activation-merge pattern the materialise primitive reuses); #143 (the issue and its verification record); #109 (wallpaper / swww); #110 (niri chrome colours, still to be Stylix-wired).
