# Desktop environment selections

Living documents for the Wayland desktop environment on metis (and any
future Linux desktop host). Each per-tool document captures a
selection, the rationale, alternatives considered, configuration
choices, sharp edges, and references.

This directory complements `docs/decisions/` (Architecture Decision
Records). Where ADRs record *decisions at a moment in time* (immutable
except for §History amendments), the documents here are *living
selections + rationale*: they update as the desktop evolves. A new
binding, a new font, a new sharp edge — those amend the doc in-place
rather than creating a new artifact.

## Index

| Doc | Subject | Landed |
|---|---|---|
| [keybinds.md](./keybinds.md) | Niri keybindings + three-namespace philosophy | #80 |
| [fonts.md](./fonts.md) | Stylix-driven font selections + two-wires install model | #81 + #82 |
| [niri.md](./niri.md) | Niri compositor selection rationale | #71 |
| [foot.md](./foot.md) | Foot terminal selection (Linux); Ghostty retained on macOS clients | #72 |
| [fuzzel.md](./fuzzel.md) | Fuzzel application launcher (Mod+Space) | #73 |

Per-tool docs to come as their issues land: notification daemon
(#74), status bar (#75), browser (#76), Cursor IDE (#77).

## Document structure

Two shapes have emerged so far:

**Per-tool selection docs** (e.g., `niri.md`, `foot.md`):

- **Selection** — what we chose, in one line.
- **Rationale** — why this over the alternatives.
- **Alternatives considered** — short, each with the reason it was passed over.
- **Configuration** — key choices made and where they live in the code.
- **Sharp edges** — known gotchas, version skews, things to revisit.
- **References** — ADRs, GitHub issues, upstream docs.

**Cross-cutting docs** (e.g., `keybinds.md`, `fonts.md`) don't fit the
per-tool shape because they span tools. They're structured around the
topic — for keybinds, that's modifier-namespace philosophy + bind
tables; for fonts, that's selections + installation model + sharp edges.

Both shapes share:
- Lead with selections/decisions, not background.
- Honest sharp-edges section with rationale.
- See-also or References at the end with cross-links.

## Conventions for evolution

**Doc precedes implementation.** Every selection (tool, font,
application, bind) lands its rationale here BEFORE the implementing
commit. The doc captures *why* at the moment of decision; future
readers follow the trail from doc → implementation.

**Commit-count cadence per PR:**
- Doc-only changes: 1 commit.
- Selection landing with implementation: 2 commits (doc, then code).
- Selection landing with a keybind: 3 commits (doc, code, bind manifest update).

The doc commit is always first regardless of count.

**Living documents — small, regular updates.** Add one bind / font /
configuration toggle at a time. Don't batch up large doc-rewrites — a
small targeted addition is easier to review than multi-week accretion.

**No silent additions.** If the codebase has a binding/font/tool not
represented in the relevant doc here, that's a cadence bug — fix the
doc.

## ADR or `docs/desktop/`?

Both kinds of artifact live in `docs/`. They serve different purposes:

- **ADR** — load-bearing project-level decisions with explicit
  consequences and migration triggers. Immutable historical record.
  Example: "DMS retracted; niri-only direction"
  ([ADR-029](../decisions/ADR-029-niri-only-desktop.md)).
- **`docs/desktop/`** — selection-level decisions for the desktop env.
  Living, updateable. Example: "niri's scrollable-tiling over
  sway/river/Hyprland" (see [niri.md](./niri.md)).

When in doubt, ADR for direction-shaping decisions; `docs/desktop/`
for tool-level selections. Cross-link freely between them.

## See also

- [`docs/decisions/`](../decisions/) — Architecture Decision Records
  (the immutable history). ADR-028 + ADR-029 frame the desktop's
  overall posture.
- [`docs/README.md`](../README.md) — top-level reference-documentation
  entry point.
- [`CLAUDE.md`](../../CLAUDE.md) — the AI-entry-point; the desktop-env
  section references this directory's documents.
