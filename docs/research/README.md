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

## Index

- **[prior-art.md](./prior-art.md)** — repos worth mining for the niri +
  Stylix + Noctalia desktop: design, dotfiles, launcher strategy, live
  theme-switching, Stylix tricks, cross-app visual consistency. Feeds
  [`../desktop/visual-identity.md`](../desktop/visual-identity.md) and
  the runtime-theming issues.

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
