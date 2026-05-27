# ADR-024: Claude Code config deployment via home.file

**Date**: 2026-05-25
**Status**: Accepted

## Context

ADR-008 installs the Claude Code CLI on every host via the base
`home/core/shared/agent-clis.nix`. Beyond the binary, Claude Code keeps
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
`home/core/shared/claude-statusline.sh`, deployed to
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
  lands and `home/core/shared/` exists. At that point the script
  relocates from `home/core/nixos/` into `shared/` so darwin hosts
  pick it up too.

## Implementation

Script lives at `home/core/shared/claude-statusline.sh` (bash;
cross-platform; requires `jq`). Wired alongside the existing
`home.packages` list in `home/core/shared/agent-clis.nix`:

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

- `home/core/shared/cli-utils.nix` gains `jq` in its `home.packages`
  list. ADR-006's locked list and rationale are amended to add jq
  (moved from the deferred tier to installed; statusline is the
  immediate driver, jq is broadly useful).
- `docs/decisions/README.md` index table gains a row for this ADR.
