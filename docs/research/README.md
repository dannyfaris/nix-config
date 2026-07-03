# Research notes

Point-in-time research outputs — surveys, prior-art scans, and option
analyses — that *feed* decisions and living documents but are neither.

Where `docs/decisions/` records immutable ADRs and `docs/desktop/`
holds living per-tool selections, the notes here capture the *evidence
gathering* behind those: a deep-research run, a comparative survey, a
landscape scan. They are dated, cited, and explicitly **not decisions**
— a note may recommend a direction, but the decision lands in an ADR or
a living doc, decided against rendered reality per the repo's
principles.

Notes update as the landscape moves (repos go dormant, new tools
appear), so they are living in that narrow sense, but each carries its
capture date and run provenance so a reader can judge staleness.

**Every deep-research run lands here.** A deep-research run's output report is saved as a note in this directory — never left only in its per-run workflow transcript (per-host, never synced, invisible to the fleet). Persist it as `docs/research/<slug>.md` with the dated status/provenance header, add an Index entry below, and land it Refs-not-Closes; then fold its verdicts onward into the design or decision note it feeds.

## Index

- **[prior-art.md](./prior-art.md)** — repos worth mining for the niri +
  Stylix + Noctalia desktop: design, dotfiles, launcher strategy, live
  theme-switching, Stylix tricks, cross-app visual consistency. Feeds
  [`../desktop/visual-identity.md`](../desktop/visual-identity.md) and
  the runtime-theming issues.

- **[omarchy-theme-switching.md](./omarchy-theme-switching.md)** — a dissection of how Omarchy defines and switches themes (`colors.toml` + `sed` templates, the `current/theme` `mv`-swap, the per-app reload-signal map, the foot live-OSC repaint, GTK/Firefox/Chromium live-vs-restart), compared to the colour-conductor design and mined for what transfers. Verdict: mine it as a *palette upstream* and a *live-repaint cookbook*, not a mechanism. Feeds [`../design/colour-conductor.md`](../design/colour-conductor.md) and the runtime-theming issues (#411 / Epic E #427).

- **[omarchy-theme-switching-validation.md](./omarchy-theme-switching-validation.md)** — independent validation of the [omarchy-theme-switching.md](./omarchy-theme-switching.md) *transfer* claims against each tool's own docs/source: foot OSC live-set (CONFIRMED), niri `load-config-file` (CONFIRMED, with a NixOS inotify-on-symlink gotcha), fnott reload (**REFUTED** — no reload, only a destructive restart), waybar live reload (PARTIALLY — overstated), and the OSC-4 slot-repaint corollary (PARTIALLY). GTK3 named-theme lever and base16 mapping fidelity returned UNVERIFIED. Feeds [`../design/colour-conductor.md`](../design/colour-conductor.md) (#411 / Epic E #427).

- **[visual-identity-research.md](./visual-identity-research.md)** — the
  design-token framework comparison (M3 / Carbon / Fluent / Open Props /
  DTCG / libadwaita) behind `theme-tokens.nix` (#369). Feeds
  [`../desktop/visual-identity.md`](../desktop/visual-identity.md).

- **[launcher-strategy.md](./launcher-strategy.md)** — Omarchy's
  three-pillar UX (launcher / action menu / hotkey cheatsheet) mapped onto
  niri + Noctalia + Nix: candidate comparison (Noctalia / fuzzel / Walker /
  anyrun) and the `fuzzel --dmenu` + Nix-single-sourced action-menu
  recommendation. Feeds [`../desktop/keybinds.md`](../desktop/keybinds.md)
  and #384.

- **[noctalia-plugin-system.md](./noctalia-plugin-system.md)** — verified
  findings on Noctalia's v4 (QML, ~150 plugins) vs v5 (Luau + `plugin.toml`,
  experimental, near-empty) plugin systems: entry types, the launcher-provider
  API, host capabilities, and ecosystem maturity. Relevant to the pillar-2
  question and #406.

- **[cross-platform-action-menu.md](./cross-platform-action-menu.md)** — an
  architecture exploration (not a decision) for running the action menu on
  both NixOS (niri + fuzzel/Noctalia) and macOS (Hammerspoon `hs.chooser`)
  from one shared semantic capability registry. Ties to #384, #406, #411.

- **[hyper-layer-redesign.md](./hyper-layer-redesign.md)** — modifier strategy
  for the cross-platform keybind layer: redefining Hyper from the all-four
  terminal-leaf chord to a `Ctrl+Alt` base (Shift + platform-meta as
  escalators), parity-not-identity across platforms, ISO_Level3 padding, and
  the spare-key/leader strategy. Feeds #384.

- **[keymap-single-sourcing-prior-art.md](./keymap-single-sourcing-prior-art.md)**
  — does any tool single-source keybindings to multiple consumers across
  Linux *and* macOS with collision/availability linting? Verdict: the
  integrated concept is genuinely open (the two halves exist in disjoint
  tools — HotkeyClash lints, home-manager/xremap codegen). Feeds #384, #428.

- **[design-loop-prior-art.md](./design-loop-prior-art.md)** — does an integrated, hypothesis-driven software *design loop* — especially an AI-collaboration one — exist as prior art? Verdict: most of the eight rungs map to named antecedents (risk-driven design, ADRs, Diátaxis, Lean Startup/MVP), but the *separation* of frozen-record vs living-reference and the *integration* into one human+agent loop are genuinely open. Feeds RFC-001 (the design-loop hypothesis).
