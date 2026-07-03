# Cursor CLI statusline

Cursor CLI (`cursor-agent`) exposes a `statusLine` hook with a
Claude-compatible shape — captured here as the selection-level
record for the cursor-side statusline implementation.

Implementation lives at `home/shared/cursor-statusline.sh` (pending —
issue #58 Phase 2a). Wiring of the `.statusLine` key into
`~/.cursor/cli-config.json` is handled by the same `home.activation`
mechanism as the Claude side (issue #172). Upstream version pinned
in this doc: nixpkgs `cursor-cli 0-unstable-2026-05-16` (the rev
landed on `main` via #165, lockfile date 2026-05-23). Cursor's own
docs at `cursor.com/docs/cli/reference/configuration` do not yet
document the `statusLine` field; the bundle's validation schema is
the canonical reference until upstream catches up.

## Selection

A second per-cli statusline script — **duplicate first, abstract on
the third occurrence** (rule-of-two; first Cursor, then Codex /
Antigravity CLI if they ever grow comparable hooks would be the trigger to
extract a shared helper).

Line layout mirrors Claude's:

- **Line 1** — `model [max] │ effort  ···  ctx% bar` (two-cluster, flush-right)
- **Line 2** — `host │ repo-rooted path on branch (worktree) !conflicts +staged ~modified ?untracked`

Two structural differences from Claude land deliberately:

- **No 5h rate-limit segment.** Cursor's payload has no
  `rate_limits.*`. Cursor's billing model is per-prompt / per-token,
  not a rolling 5-hour window like Claude's, so the segment isn't
  just missing data — it's a different shape entirely. Dropped.
- **Effort is derived from the model id**, not from a dedicated JSON
  field. Cursor encodes effort as a suffix on the model id
  (`gpt-5.3-codex-low`, `-high`, `-xhigh`) rather than exposing
  `.effort.level` like Claude.

## Rationale

**Palette coherence across agent-CLIs is the goal.** Sourcing the same
`statusline-colours.sh` from both scripts means the per-host Stylix palette
is the single source of truth — host glyph + colour, branch colour, and
git-state counters all match across the two CLIs on the same host.

**Layout converges too**, to the extent each payload allows (#354): both
scripts use the two-cluster flush-right composition and an identical glyph
display-width model, diverging only where the payloads genuinely differ —
cursor-only max-mode, and Claude-only account label and rate-limit segment.

**Duplicate first.** Cursor is the second statusline consumer.
Most of `claude-statusline.sh` is vendor-neutral — palette / glyph
bindings, SSH detection, git state, path shortening, line 2
composition all transfer unchanged. The divergent surface is small
and concentrated: stdin field names (different JSON shape per CLI),
the model-tier `case` block (different lineups), the EFFORT segment
(different source — JSON field on Claude, model-id substring on
cursor), and the rate-limit segment (Claude-only). A single
duplication doesn't earn the abstraction overhead; ADR-024's
reference is the load-bearing implementation guide for both scripts.

**Model-tier colour mapping** is the largest cursor-specific decision.
Cursor's lineup as of `cursor-cli 0-unstable-2026-05-16` spans five
families — Anthropic (Opus + Sonnet), OpenAI codex, OpenAI gpt-non-
codex, Cursor-native composer, and Google Gemini — plus an `auto`
selector. Effort is encoded as a model-id suffix (`-low` / `-medium`
/ `-high` / `-xhigh` / `-max`). Most variants additionally have a
`-fast` modifier (latency-optimised) and many Anthropic variants
have a `-thinking` modifier (extended-thinking mode), both
orthogonal to family and effort. Representative sample:

```
auto - Auto
claude-4.6-opus-max-thinking - Opus 4.6 1M Max Thinking
claude-4.6-sonnet-medium - Sonnet 4.6 1M
claude-opus-4-7-thinking-high - Opus 4.7 1M High Thinking
claude-opus-4-8-xhigh - Opus 4.8 1M Extra High
composer-2.5 - Composer 2.5
composer-2.5-fast - Composer 2.5 Fast (current, default)
gemini-3.1-pro - Gemini 3.1 Pro
gemini-3.5-flash - Gemini 3.5 Flash
gpt-5.1-codex-max-xhigh - Codex 5.1 Max Extra High
gpt-5.2-codex - Codex 5.2
gpt-5.3-codex-xhigh-fast - Codex 5.3 Extra High Fast
gpt-5.5-high - GPT-5.5 1M High
```

Mapping:

| Pattern (in lowercase `model.id`) | Family | Colour | Rationale |
|---|---|---|---|
| `*fable*` | Anthropic Fable (frontier) | RED | tier above Opus on the warmth ladder; matches Claude convention (line-1 RED = Fable). No fable id ships in the pinned cursor-cli yet — future-proofing. See ADR-024 §Implementation (2026-06-10) |
| `*sonnet*` | Anthropic Sonnet | TEAL | matches Claude convention (line-1 TEAL = Sonnet) |
| `*opus*` | Anthropic Opus | ORANGE | matches Claude convention (line-1 ORANGE = Opus) |
| `*composer*` | Cursor native | BLUE | Cursor's house model; deserves a colour distinct from OpenAI / Anthropic variants. BLUE is the line-2 path + nix-shell colour today; adopting it for the model slot on line 1 mirrors the existing dual-role pattern (ORANGE: untracked+Opus, TEAL: branch+Sonnet) |
| `*codex*` (any GPT codex variant) | OpenAI code-specialised | YELLOW | code-specialised = "attention" hue; covers `gpt-5.3-codex`, `gpt-5.2-codex`, `gpt-5.1-codex-max`, all effort + `-fast` suffix variants |
| `*gpt-5*` non-codex | OpenAI general | ORANGE | Opus's tier-mate — generalist models are coloured by tier, not vendor identity (ADR-024 §Implementation, 2026-06-10). Was MAUVE; reassigned so MAUVE returns to SSH-host-only across both agent-CLI surfaces |
| `*gemini*` | Google | default fg | day-1 deferral. The seven-colour palette is fully spoken-for after the assignments above; the only remaining slot (GREEN) clashes on line 1 with the low-context bar. Gemini is marginal in the operator's current usage (default model is `composer-2.5-fast`); leave on default fg until either Gemini becomes a daily driver or the palette grows |
| `auto` / unknown | no explicit choice | default fg | silence-as-signal — matches Claude's Haiku/unknown fall-through |

Match order matters and is non-obvious: `*fable*`, `*sonnet*` and `*opus*` first (so a hypothetical `*-opus-codex-*` would colour as Opus, not Codex — Anthropic-family identity dominates); then `*codex*` (so `gpt-5.3-codex-*` colours as YELLOW not ORANGE); then `*composer*`, `*gpt-5*`; `*gemini*` and `auto` and unknown all fall through to default fg.

**Effort derivation.** Cursor's effort lives in the model id as a
`-low` / `-medium` / `-high` / `-xhigh` / `-max` suffix; the
*absence* of any effort suffix means the vendor's default tier.
`-fast` (latency-optimised) and `-thinking` (extended thinking) are
orthogonal modifiers and not effort. The segment derives from a
second `case` over the model id, parallel to Claude's `.effort.level`
case in `claude-statusline.sh:175-183`:

| Substring in `model.id` | Effort segment | Colour |
|---|---|---|
| `*-low*` | `▽ low` | DIM |
| `*-medium*` | `◆ med` | YELLOW |
| no effort suffix | (none rendered) | — |
| `*-high*` | `▲ high` | YELLOW |
| `*-xhigh*` | `▲ xhigh` | RED |

Match order: `-xhigh` before `-high` (substring containment);
`-low` is unambiguous.

**`-max` left unmapped.** Surfaced during implementation: `-max`
appears in cursor's lineup as a quality-tier modifier, not as an
effort level — `claude-opus-4-7-max`, `claude-opus-4-7-max-fast`,
`claude-opus-4-7-thinking-max` are "Max tier" variants of Opus 4.7;
`gpt-5.1-codex-max-low` / `-max-medium` / `-max-high` / `-max-xhigh`
are "Codex 5.1 Max" with explicit effort suffixes. Mapping `*-max*`
to effort would mis-categorise the tier as effort and clobber the
real effort suffix on the 5.1-codex Max variants. Left unmapped
until the semantic separation between tier and effort is clearer in
upstream conventions.

`-fast` and `-thinking` modifiers are not surfaced on day 1 — both
are real signals (latency tier and extended thinking) but neither
has an obvious glyph and the visual budget of line 1 is already
dense. Revisit if the operator finds themselves wanting them.

**Sharp edges around the model-id parse.** Both family-tier and
effort-tier come from the same string (`gpt-5.3-codex-xhigh`), so
the `case` blocks have to be ordered carefully (see match-order
notes in each table above). Both match against `model.id`, not
`display_name`, since the id schema is more stable across Cursor's
display renames.

**Cursor-specific signals — surface decision per signal.**

| Signal | Source | Surface? | Rationale |
|---|---|---|---|
| `vim.mode` | top-level optional | **No** | the operator does not run cursor in vim mode (`editor.vimMode: false` in `cli-config.json`); rendering an empty / always-default mode glyph adds visual noise without signal |
| `output_style.name` | top-level | **No** | `compact` vs `default` is a render hint to cursor itself, not operator-relevant context |
| `autorun` | top-level boolean | **No** | autorun toggle is operator-aware (they enabled it); no need to mirror state they already know |
| `model.max_mode` | optional within `.model` | **Yes** | max-mode = expanded context window for the same model; a clear signal worth surfacing. Render as a small `↑` glyph next to the model name when present |
| `model.param_summary` | optional within `.model` | **No** day 1 | cursor's parameter summary is freeform string ("thinking enabled", "fast variant", etc.); valuable but unstable. Revisit if a stable convention emerges |
| `worktree.name` | top-level optional object | **Yes** | render as `(worktree-name)` suffix after the branch label, matching Claude's worktree treatment in `claude-statusline.sh:167`. Note Cursor's `worktree` is a *top-level object* with `{name, path}` fields (not a string under `.workspace.git_worktree` like Claude); a direct port of the jq query would either silently drop the value or render as raw JSON. Read `.worktree.name` |
| `session_name` | top-level optional | **No** | session naming is for cursor's own resume-picker UX, not a per-render signal |
| `context_window.used_percentage` | within `.context_window` | **Yes** | matches Claude's context bar exactly; reuse the same threshold colours (GREEN < 60% < YELLOW < 80% < RED) |
| `context_window.{total_input_tokens, total_output_tokens, context_window_size, remaining_percentage, current_usage}` | within `.context_window` | **No** day 1 | the bar already carries the headline number; raw counts and absolute usage are operator-toggle territory if ever wanted |
| `transcript_path` | top-level | **No** | implementation hook for `/resume` and tooling; not a per-render signal |
| `render_width_chars` | top-level int | **No** | render hint to the script (truncation budget). Use internally if truncation logic is added later; do not render |

## Alternatives considered

**Single shared `agent-statusline.sh` with vendor branching on
argv[0] or an env var.** Passed over — the divergence is too
structural (different stdin field names, different effort sources,
different available signals) for branching inside one script to be
cleaner than two scripts. Revisit at the third occurrence (Codex or
Antigravity CLI gain comparable hooks).

**Mirror Claude's mapping unchanged (`*Sonnet*` / `*Opus*` /
`*GPT-5*` only).** Passed over — collapses cursor's three OpenAI
families (codex vs gpt non-codex vs composer) into one colour,
losing the day-to-day tier signal that's the whole point of the
mapping.

**Skip the cursor statusline entirely; document the asymmetry in
ADR-024 (#58 Phase 2b).** Passed over now that Phase 1 confirmed
the hook exists with a Claude-compatible schema. The asymmetry that
*would* deserve documentation is the no-rate-limit + effort-in-id
divergence; both land in this doc rather than ADR-024, so the
"asymmetry note" lives next to the implementing surface, not next
to Claude's.

**Use a community statusline script (e.g. `agent-status-pills`).**
Passed over — that project is a useful reference for confirming the
schema is Claude-compatible (it ships both Claude and Cursor
support against the same shape), but its output style (pill-shaped
badges, different glyph set) wouldn't match the existing host
prompt + Claude statusline visual language on these hosts.

## Configuration

**Script location.** `home/shared/cursor-statusline.sh`, deployed
to `~/.cursor/statusline.sh` via `home.file` alongside the existing
Claude entry in `home/shared/agent-clis.nix`. The same
`statusline-colours.sh` derivation is sourced — no second palette
source.

**Config file wiring.** `~/.cursor/cli-config.json` `.statusLine`
key set via the same `home.activation` jq-merge mechanism that
handles Claude's `~/.claude/settings.json` (issue #172). The
minimum required block is:

```json
{
  "type": "command",
  "command": "~/.cursor/statusline.sh"
}
```

**Optional config-block fields settled in Phase 2a.** The schema
additionally supports `padding` (int, line spacing), `updateIntervalMs`
(refresh cadence — Claude defaults to 300ms; cursor's default is in
the bundle), and `timeoutMs` (script execution bound). The right
values depend on observed render output and are settled when the
script lands; documented here as known knobs.

**Hosts.** `agent-clis.nix` is imported by every host (base
agent-CLI set). The script lands on neptune, metis, mercury,
nixos-vm uniformly — but `cursor-cli` is only on hosts whitelisted
in `modules/shared/nix-daemon.nix`'s `allowUnfreePredicate`.
Verification of the rendered statusline requires `cursor-agent` on
PATH; mercury is the verification gap (work-only host, no cursor in
base for that host's posture).

## Sharp edges

**Effort encoding in model id is fragile.** Cursor renames its
display names every few releases. The model-id `case` blocks
substring-match on stable id fragments (`*codex*`, `*-xhigh*`)
rather than display strings — that's deliberate. If cursor changes
the id schema (e.g., flattens `-codex-xhigh` to `-xhigh-codex` or
introduces a new effort token), the effort case needs an update.
Pin the upstream-version checked in this doc when the case block
last reviewed: **`cursor-cli 0-unstable-2026-05-16`** as of writing.

**Cross-line BLUE collision.** BLUE is currently the line-2 path
colour and the nix-shell glyph colour. Adopting it for `composer`
on line 1 adds a third role. Two existing slots (ORANGE for
untracked + Opus; TEAL for branch + Sonnet) already carry
cross-line dual roles per the convention in
`home/shared/agent-clis.nix:42-49`. Composer-on-line-1 + path-on-
line-2 is a *cross-line* not *cross-segment* reuse — same semantic
weight as the existing dual-role slots.

**`max_mode` glyph TBD.** The selection commits to surfacing it but
the rendering detail (which glyph, where it sits next to the model
name) is settled during Phase 2a authoring. Captured here so the
choice surfaces in the implementing PR's diff rather than being
quietly added.

**Schema drift.** Cursor's CLI moves faster than Claude's. The
upstream-docs gap is noted in the lead; when upstream adds
`statusLine` to the reference page, add the link to §References and
verify the schema matches what's pinned here.

**Worktree placement and shape asymmetry.** Cursor's payload puts
`worktree` at the top level as an *object* (`{name, path}`); Claude's
puts a *string* at `.workspace.git_worktree`. A direct port of
Claude's jq query (`.workspace.git_worktree`) would silently lose
worktree info on cursor, and reading `.worktree` directly would
emit raw JSON. The implementing script must read `.worktree.name`.

**No cost/spend field in the statusline payload.** Cursor computes billing
internally (`total_cost_cents`, `total_request_cost`, `percent_of_burst_used`)
but those live in a server-side usage message, *not* the statusline stdin
payload — which exposes only `context_window` token fields (`total_input_tokens`
is derived from `used_percentage`; `total_output_tokens` is frequently null;
`current_usage` is last-call only). So a token/cost segment is deferred until
cursor surfaces cost, and is the real reason line 2's right cluster stays empty
(#354). Verified against `cursor-cli 0-unstable-2026-05-24`.

**Width signal is `render_width_chars`, not `$COLUMNS`.** Cursor's payload
carries `render_width_chars` ("usable terminal columns minus built-in padding")
and a `statusLine.padding` config (default 0). That is the authoritative pad
target for the flush-right layout; the script pads to it rather than `$COLUMNS`,
which cursor does not set (Claude has no equivalent and pads to `COLUMNS-1`). A
standard `wcwidth` (libc, perl, python) is *not* a usable substitute for the
glyph-width half: it reports the Nerd Font PUA glyphs, `✦`, and the `│`
separator as width 1, reproducing the truncation bug — so the display-width
correction is an explicit per-glyph table (`WIDE_GLYPHS`) consumed by an
identical `vw()` in both scripts; the tables differ only in that cursor's omits
the rate-limit clock glyph it never renders (#354). The bar's `█`/`░` are
deliberately excluded: though also
East-Asian-ambiguous like `│`, the renderer counts them as one cell, so a
naive "ambiguous = wide" rule would over-pad and mangle the bar.

## References

- **#58** — the issue this doc closes Phase 1 of and authors Phase 2a's
  selection-level decisions.
- **#172** — wires `~/.cursor/cli-config.json`'s `.statusLine` key
  via `home.activation` jq-merge.
- **#165** — landed the nixpkgs bump (cursor-cli `2026-04-08` →
  `2026-05-16`) that unblocked this work.
- [ADR-008](../decisions/ADR-008-agent-clis.md) — base/extras split
  for agent-CLIs.
- [ADR-024](../decisions/ADR-024-claude-code-config.md) — Claude
  Code statusline contract; the load-bearing reference for both
  scripts' shared sections.
- [Cursor CLI changelog — `/statusline` introduced 2026-04-14](https://cursor.com/changelog/page/4).
- [Forum: Configurable Status Lines in Cursor Agent — implementation update 2026-04-09](https://forum.cursor.com/t/configurable-status-lines-in-cursor-agent/152287).
- [Cursor CLI configuration docs (does NOT yet document `statusLine`)](https://cursor.com/docs/cli/reference/configuration) — track here until upstream catches up.
- [`agent-status-pills`](https://github.com/mvfsillva/agent-status-pills) — community statusline supporting both Claude and Cursor with the same schema; schema-confirmation reference.
