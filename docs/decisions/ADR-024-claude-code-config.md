# ADR-024: Claude Code config deployment via home.file

**Date**: 2026-05-25
**Status**: Accepted

> **Revision (2026-06-05):** stale module paths in this ADR were swept to the
> current flat layout (`home/core/…` → `home/…`, `modules/core/…` → `modules/…`)
> per [ADR-026](./ADR-026-drop-core-tier-prefix.md), which dropped the `core/`
> tier prefix. Navigability fix only — the decision recorded here is unchanged.

## Context

ADR-008 installs the Claude Code CLI on every host via the base
`home/shared/agent-clis.nix`. Beyond the binary, Claude Code keeps
configuration and runtime state co-located in `~/.claude/`. Some of
that tree is *configuration* (settings.json, CLAUDE.md, agents/,
commands/, hooks/, skills/, statusline scripts) and is a good
candidate for declarative sync across hosts. Most of it is *runtime
state* (e.g. projects/, sessions/, history.jsonl, cache/, telemetry/,
plans/, tasks/, plugins/, credentials) that Nix must not touch.

The immediate trigger is a hand-written statusline script the user
wants present on every host that runs Claude Code. The broader
question is what pattern to use so future Claude Code config
artifacts have an established place to land.

The upstream `programs.claude-code` home-manager module exists and
covers settings, CLAUDE.md, agents, commands, hooks, skills, MCP
servers, etc. Adopting it now would also pull `settings.json` under
Nix ownership, which conflicts with Claude Code's runtime writes
to that file. For a two-key settings.json today, that override
surface isn't worth taking on.

## Decision

Deploy stable Claude Code config artifacts from this repo via
`home.file`. Leave `~/.claude/settings.json` mutable on each host;
reference deployed artifacts from settings.json with a one-time
per-host edit.

First artifact under this pattern: the statusline script at
`home/shared/claude-statusline.sh`, deployed to
`~/.claude/statusline.sh`.

## Rationale

- **Config / state split.** `home.file` lets us declaratively manage
  the specific files we name and leaves the rest of `~/.claude/`
  alone. Runtime state is preserved across rebuilds.
- **settings.json mutability.** Claude Code's `/config` slash command
  and the `update-config` skill both write `settings.json` at
  runtime. Nix-managing the file would either fail on write (symlink
  into the store is read-only) or have interactive changes clobbered
  on the next `nh os switch`. The override workflow needed to make
  it tolerable (custom skills, harness redirection) is more code
  than a two-key file justifies today.
- **Right-sized solution.** A three-line `home.file` block matches
  the size of the problem. Adopting the full `programs.claude-code`
  module is a future option if shared config grows past five-or-so
  artifacts; revisit then.
- **Per-host edit is bounded.** The settings.json reference is
  `"command": "~/.claude/statusline.sh"` — the same string on every
  host. One-time cost per machine, never revisited.
- **Reach matches ADR-008.** `agent-clis.nix` ships on every host,
  so the statusline is automatically available everywhere Claude
  Code runs.

## Consequences

- ✓ Statusline script edits happen in one place (this repo); sync
  across hosts is automatic on `nh os switch`.
- ✓ `~/.claude/` runtime state is untouched — no risk of clobbering
  history, sessions, caches, or telemetry.
- ✓ Pattern scales: each new declarative artifact (CLAUDE.md,
  agents/foo.md, commands/bar.md) adds one `home.file` entry under
  the same wiring.
- ✓ Every host that ships the base agent set (including Mercury) gets
  the statusline automatically.
- ✗ `settings.json` remains a per-host edit (one line, one time per
  machine) — not declarative. Re-bootstrapping a host means
  re-adding the `statusLine` block by hand.
- ✗ `home.file` deploys files as symlinks into the Nix store. The
  statusline script is *executed* (not read as config) so symlink
  semantics don't bite. If a later artifact is read as config (e.g.
  CLAUDE.md, settings.json, agent files), verify Claude Code reads
  it correctly through a symlink before relying on the same wiring;
  the fallback is a copy-via-activation-script.
- ⚠ Migration trigger: shared Claude Code config grows past ~5
  artifacts. At that point, reconsider adopting the upstream
  `programs.claude-code` module wholesale, accepting the
  settings.json conflict and designing the override layer.
- ⚠ Migration trigger: Claude Code adopts a convention that locates
  the statusline script without an explicit settings.json reference
  (e.g. an env var like `CLAUDE_STATUSLINE_COMMAND`, or a default
  `~/.claude/statusline.{sh,py,js}` lookup). At that point, the
  per-host settings.json edit can be dropped.
- ⚠ Migration trigger: the multi-host rebuild (PRD + ADRs 013–016)
  lands and `home/shared/` exists. At that point the script
  relocates from `home/nixos/` into `shared/` so darwin hosts
  pick it up too.

## Implementation

Script lives at `home/shared/claude-statusline.sh` (bash;
cross-platform; requires `jq`). Wired alongside the existing
`home.packages` list in `home/shared/agent-clis.nix`:

```nix
# Custom statusline — see ADR-024.
home.file.".claude/statusline.sh" = {
  source = ./claude-statusline.sh;
  executable = true;
};
```

Per-host one-time edit to `~/.claude/settings.json` (not Nix-managed):

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  }
}
```

Companion changes:

- `home/shared/cli-utils.nix` gains `jq` in its `home.packages`
  list. ADR-006's locked list and rationale are amended to add jq
  (moved from the deferred tier to installed; statusline is the
  immediate driver, jq is broadly useful).
- `docs/decisions/README.md` index table gains a row for this ADR.

**Palette-driven colours (added per ADR-028 slice 6, 2026-05-28).** The
six colour bindings in `claude-statusline.sh` (BLUE / GREEN / YELLOW /
RED / MAUVE / TEAL) are no longer hardcoded ANSI 256-colour escapes.
`home/shared/agent-clis.nix` emits a `~/.claude/statusline-colours.sh`
derivation at activation time using `pkgs.writeText` +
`config.lib.stylix.colors`, and the main script `source`s it at
startup. The colour escapes are now truecolor (`38;2;R;G;B`) rather
than 256-colour (`38;5;N`), and the palette tracks each host's Stylix
scheme — completing the SSH-context signal stack at the statusline
layer (alongside helix, prompt, zellij, and the macchina banner per
ADR-028 slice 2). `DIM` and `RST` are SGR style codes (not colours)
and remain hardcoded in the script. Role → base16 slot mapping
mostly follows the standard base16 semantic convention with one
deliberate divergence: `BLUE`/path → `base0D`, `TEAL`/branch →
`base0C`, `GREEN`/staged → `base0B`, `YELLOW`/modified → `base0A`,
`ORANGE`/untracked → `base09`, `RED`/danger → `base08`, `MAUVE`/SSH-
host → `base0E`. `MAUVE` originally mapped to untracked per base16
convention; untracked moved to `ORANGE` (base09) so the SSH host
marker (added later — see ADR-002 History) is the only purple
element on line 2. The seven-binding mapping above is the current
canonical list.

**Model name colour by tier (2026-05-28).** Line 1's leading `✦ <model
name>` segment is coloured per Anthropic model tier so the active
model is identifiable at a glance:

- `*Sonnet*` → `TEAL` — calm "label" hue, pairs with branch on line 2.
- `*Opus*`   → `ORANGE` — top of the visual tier ladder, warmest hue.
- **Haiku** → default foreground (intentional). Absence of styling
  is itself a signal — the lightweight tier is the "workhorse with no
  flourish." Reducing visual chrome for the most common use case is
  the design goal.
- **Unknown / future tiers** → default foreground (by fallthrough).
  *Review this mapping when Anthropic ships a new tier name* (e.g. a
  "Pro" or "Lite" between Sonnet and Opus, or a successor naming
  scheme entirely) — the current case statement won't recognise it.

Substring match (not exact) so future variants ("Claude 5 Opus",
"Sonnet 4.7", etc.) inherit their tier's colour without an update.
Sonnet is checked before Opus so a hypothetical "Sonnet (Opus-tuned)"
hybrid renders as Sonnet — see the case-statement comment.

The Opus=ORANGE and Sonnet=TEAL choices each share a hue with one
line-2 role (untracked counter and branch respectively). The dual
roles are deliberate — both pair "label / attention" semantics across
the two lines at distinct positions. **ORANGE and TEAL are at
capacity** for line-1 categorical pairing — if a future line-1 slot
needs colour, prefer MAUVE or default-fg rather than triple-loading
either of these.

The originally-used `MAUVE`/Opus was dropped because MAUVE is now the
SSH host marker, and both elements are leftmost-line-anchors —
colouring both purple collapsed them into a single apparent signal
when SSH'd.

**Line-2 layout (2026-05-28).** The statusline's line 2 mirrors the
starship prompt's signal stack so the two surfaces read the same way:

- Host segment (glyph + hostname) on the left, coloured by SSH state —
  green local, purple SSH. ADR-002 History documents the prompt-side
  detail and the host-glyph swap rationale.
- `(…)`-as-metadata convention applies — `(❄️)` lands on **both** the
  prompt and the statusline (inserted between the path and the git
  block); `(worktree)` lands on the **statusline only** (starship has
  no worktree module wired). The canonical convention statement lives
  in ADR-002 History.
