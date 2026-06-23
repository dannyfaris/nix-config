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
| [claude-statusline.md](./claude-statusline.md) | Claude Code statusline — current-state living record (layout, palette-driven colours, model-tier mapping, account label, width mechanics); ADR-024 holds the dated history | ADR-024 |
| [cursor-statusline.md](./cursor-statusline.md) | Cursor CLI statusline — model-tier mapping, signal selection, asymmetry vs Claude Code | #185 + #186 |

## Project skills

Beyond the per-surface selection docs above, this repo checks in **project Agent Skills** under [`.claude/skills/<name>/SKILL.md`](../../.claude/skills/). Claude Code auto-discovers a skill and loads it when a task matches its `description`; skills are git-tracked (via `.gitignore`'s deliberate `.claude/` carve-out) so they sync across every host — consistent with this repo's "agent knowledge lives in git, not per-host local state" principle.

- [`selecting-tooling`](../../.claude/skills/selecting-tooling/SKILL.md) — the process for assessing and choosing a tool/package/service to adopt, swap, or keep (first-principles + prior-art + verification against the actual flake pins). First project skill; distilled from the #96/#99/#103/#105 selection work.

## See also

- [ADR-008](../decisions/ADR-008-agent-clis.md) — agent-CLI base/extras split.
- [ADR-024](../decisions/ADR-024-claude-code-config.md) — Claude Code's
  config surface and statusline contract; the reference point for any
  cursor-side asymmetry doc.
- [`docs/desktop/`](../desktop/) — the parallel directory for
  desktop-environment selections.
