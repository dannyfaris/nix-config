# Agent-CLI selections

Living documents for the AI coding agents the operator runs locally on
every host that imports `home/shared/agent-clis.nix` (Claude Code +
Cursor CLI per ADR-008) — and their per-tool surface choices, where a
surface (statusline, hook, theme integration) carries decisions worth
recording.

This directory complements `docs/decisions/` and `docs/desktop/`:

- **ADRs** capture the load-bearing, decision-shaping framing for a
  whole tool family or capability (e.g. ADR-008 framed the base/extras
  split for agent-CLIs; ADR-024 captured the Claude Code statusline's
  per-host config rationale).
- **`docs/desktop/`** captures per-tool desktop-environment selections.
- **`docs/agents/`** captures per-surface decisions for agent CLIs
  whose framing is *already* set by an ADR but whose execution involves
  selection-level choices worth living-document treatment (model-tier
  colour mapping, signal selection, behavioural conventions).

The shape is the same as `docs/desktop/` per-tool docs: lead with the
selection, justify with rationale, list alternatives considered, name
the sharp edges, cross-link references.

## Index

| Doc | Subject | Landed |
|---|---|---|
| [cursor-statusline.md](./cursor-statusline.md) | Cursor CLI statusline — model-tier mapping, signal selection, asymmetry vs Claude Code | _pending — #58_ |

## See also

- [ADR-008](../decisions/ADR-008-agent-clis.md) — agent-CLI base/extras split.
- [ADR-024](../decisions/ADR-024-claude-code-config.md) — Claude Code's
  config surface and statusline contract; the reference point for any
  cursor-side asymmetry doc.
- [`docs/desktop/`](../desktop/) — the parallel directory for
  desktop-environment selections.
