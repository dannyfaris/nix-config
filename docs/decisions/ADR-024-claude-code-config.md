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
element on line 2. The seven-binding mapping above was the canonical
list until 2026-06-10, when an eighth binding (`MUTED`/base04) was
added — see the account-label entry below.

**Model name colour by tier (2026-05-28).** Line 1's leading `✦ <model
name>` segment is coloured per Anthropic model tier so the active
model is identifiable at a glance:

- `*Sonnet*` → `TEAL` — calm "label" hue, pairs with branch on line 2.
- `*Opus*`   → `ORANGE` — warmest hue and top of the visual tier
  ladder until Fable 5 took `RED` above it (2026-06-10 — see below).
- **Haiku** → default foreground (intentional). Absence of styling
  is itself a signal — the lightweight tier is the "workhorse with no
  flourish." Reducing visual chrome for the most common use case is
  the design goal.
- **Unknown / future tiers** → default foreground (by fallthrough).
  *Review this mapping when Anthropic ships a new tier name* (e.g. a
  "Pro" or "Lite" between Sonnet and Opus, or a successor naming
  scheme entirely) — the current case statement won't recognise it.
  (Exercised 2026-06-10: Fable 5 landed as the tier above Opus — see
  the Fable entry below.)

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
either of these. (2026-06-10: the next slot went to RED instead —
Fable; MAUVE was re-examined and rejected as the now-most-loaded
identity slot. Future line-1 slots: default-fg. See the Fable entry
below.)

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

**Account label + two-cluster layout (2026-06-10).** Line 1 gains a leading account label — `Personal` / `Grey St.` per the identity split in [docs/identities.md](../identities.md) — and both lines move to a left-cluster / right-cluster layout with the right cluster flush against the terminal edge.

*Account label.* The statusline stdin JSON carries no account info; the address `/status` reports lives in `~/.claude.json` at `.oauthAccount.emailAddress` (the same single-identity store documented in docs/identities.md §"Tools that opted out"), so the script reads it with one extra `jq` per render. Mapping: `daniel@faris.co.nz` → `Personal`, `daniel.faris@gotaxi.co.nz` → `Grey St.`; an unmapped address renders as the raw email (visibly unmapped, never silently wrong); an unreadable or absent file omits the segment and its separator entirely. Both labels render in a single muted tone — the words do the distinguishing. Claude-side only; the Cursor statusline is untouched (its JSON/config has no equivalent account surface wired).

*`MUTED` colour role (base04).* All seven accent bindings already carry roles the label would echo — GREEN mirrors the adjacent context bar, TEAL/ORANGE read as model tiers, MAUVE is the SSH host marker, RED/YELLOW are alarm/effort — and ORANGE and TEAL are at capacity per the dual-role note above. base0F was rejected: it has no stable base16 semantic and lands on red (tokyo-night), orange (gruvbox), or a near-invisible dark (rose-pine) across the fleet's schemes. base04 is the base16 *"Dark Foreground (Used for status bars)"* slot — the one non-accent option, consistent and legible across every fleet scheme and polarity — so the label reads as static metadata rather than a live signal. Per-account *distinct* colours were considered and dropped: distinguishing two accounts needs two slots, and there is only one free.

*Two-cluster layout.* Line 1 is `account │ ✦ model │ effort` left and `<ctx%> <bar>` flush right; line 2 is `host ❯ path on branch <counts>` left and `<clock> <5h%> <countdown>` flush right. The grouping reads identity/config on the left and live meters on the right, and stacks the two budget percentages (context window above 5-hour window) in one right-edge meters column; the clock glyph on the 5h segment is load-bearing — it disambiguates the two stacked percentages. The context-bar cluster is ordered *number before bar* deliberately: the bar is fixed-width, so anchoring it flush right keeps both bar edges pinned while only the percentage digits float in the gap — bar-first would wobble the whole cluster as the percentage gains digits.

*Width mechanics.* Claude Code ≥ 2.1.153 sets `$COLUMNS`/`$LINES` to the live terminal size before each render and re-renders on resize (the stdin JSON has no width field; `tput cols` cannot see the terminal from inside the captured script). The fleet's flake pin satisfies the floor. Padding targets `COLUMNS − 1` because writing the final cell triggers auto-wrap on some terminals. Visible width is measured by stripping SGR escapes and counting code points — Nerd Font glyphs are assumed width 1, so a double-width rendering would drift the right edge by one column, cosmetic only. The gap clamps to ≥ 1 space: on narrow terminals the right cluster degrades to left-flow (and may soft-wrap if content alone exceeds the width, matching pre-cluster behaviour).

**Fable tier colour — RED; cursor mapping moves tier-based (2026-06-10).** Fable 5 (the frontier tier, above Opus) wears `RED`/base08 in both statuslines: `*Fable*` on `.model.display_name` in `claude-statusline.sh`, `*fable*` on `.model.id` in `cursor-statusline.sh` (future-proofing — no fable id ships in the pinned cursor-cli yet).

*Why RED.* It extends the recorded warmth-ladder grammar — teal → orange → red — and the choice was deliberately deferred (#330, #331) until the ADR-028 slot corrections (2026-06-10) made base08 render distinctly from base09 on all four hosts; before them, mercury's 08/09 were both foreground-adjacent. Accepted cost: the badge shares base08 with the conditional alarm signals (conflict counter, ≥ 80 % context bar, xhigh/max effort) — they remain shape- and position-distinct, and the badge is the only *permanent* red on screen.

*Why not MAUVE.* base0E is now the most-loaded identity slot: the SSH host marker fleet-wide, deliberately sharing with the path on metis (ADR-028 §History 2026-06-10). And in the Cursor statusline — which has no account label offsetting line 1 — a 0E model badge at column 0 stacks directly above the 0E SSH marker at line 2 column 0, the geometry that originally killed MAUVE/Opus (see above).

*Cursor goes tier-based for the Anthropic-comparable generalists.* `*gpt-5*` non-codex moves MAUVE → ORANGE: models are coloured by tier, not vendor identity, and GPT-5.5 is Opus's tier-mate. MAUVE thereby returns to SSH-host-only across both agent-CLI surfaces. The codex (YELLOW) and composer (BLUE) family colours are deliberately retained — tier-binning them was considered and deferred because their bins are genuinely fuzzy; revisit if the half-tier/half-family mapping grates. `docs/agents/cursor-statusline.md`'s mapping table is updated to match.
