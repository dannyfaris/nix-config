# Claude Code statusline

Claude Code exposes a `statusLine` command hook fed a JSON payload on stdin per render. This is the living current-state record for the Claude-side statusline; the design's dated evolution lives in [ADR-024](../decisions/ADR-024-claude-code-config.md) §Implementation as history. The cursor-side parallel is [cursor-statusline.md](./cursor-statusline.md); the two scripts share most of their structure (palette, glyphs, SSH detection, git state, path shortening) and diverge only where the payloads differ.

Implementation lives at `home/shared/claude-statusline.sh` (bash; cross-platform; requires `jq`), deployed to `~/.claude/statusline.sh` via `home.file` in `home/shared/agent-clis.nix`. The `.statusLine` key in `~/.claude/settings.json` is wired by the `agentStatuslineSettings` activation step in the same module — a non-destructive `jq` merge that sets `.statusLine` to the command block on each switch while preserving every other key in the runtime-owned file (with a corrupt-JSON warn-and-skip guard, #342).

## Layout

Two lines, each a left cluster and a right cluster flush against the terminal edge:

- **Line 1** — `account │ ✦ model │ effort` left, `ctx% bar` flush right
- **Line 2** — `host ❯ repo-rooted path (❄) on branch (worktree) !conflicts +staged ~modified ?untracked` left, `clock 5h% countdown` flush right

The grouping reads identity/config on the left and live meters on the right. The right cluster stacks the two budget percentages — context window above the 5-hour window — in one right-edge column; the clock glyph on the 5h segment is load-bearing, disambiguating the two stacked percentages. The context cluster is ordered *number before bar*: the bar is fixed-width, so pinning it flush right keeps both bar edges anchored while only the percentage digits float in the gap.

## Colours — palette-driven, per host

The script sources `~/.claude/statusline-colours.sh`, a derivation `home/shared/agent-clis.nix` emits at activation time via `pkgs.writeText` + `config.lib.stylix.colors`. Escapes are truecolor (`38;2;R;G;B`) and track each host's Stylix scheme, so the statusline is one of the SSH-context signal layers — the same palette also drives the prompt, the Zellij frame, helix, and the macchina banner (ADR-028 slice 2). `DIM` and `RST` are SGR style codes, not colours, and stay hardcoded.

Role → base16 slot mapping — mostly the standard base16 semantic convention, with untracked moved off MAUVE so the SSH host marker is the only purple element on line 2:

| Binding | Role | base16 slot |
|---|---|---|
| `BLUE` | path | `base0D` |
| `TEAL` | branch | `base0C` |
| `GREEN` | staged | `base0B` |
| `YELLOW` | modified | `base0A` |
| `ORANGE` | untracked | `base09` |
| `RED` | danger / alarm | `base08` |
| `MAUVE` | SSH host marker | `base0E` |
| `MUTED` | account label | `base04` |

## Model-tier colour on line 1

Line 1's leading `✦ <model name>` segment is coloured by Anthropic model tier so the active model is identifiable at a glance. Substring match on `.model.display_name` (not exact) so future variants inherit their tier's colour without a script change; Sonnet is checked before Opus so a hypothetical "Sonnet (Opus-tuned)" hybrid renders as Sonnet:

| Pattern | Tier | Colour | Rationale |
|---|---|---|---|
| `*Fable*` | Fable (frontier) | RED | top of the warmth ladder (teal → orange → red); above Opus |
| `*Opus*` | Opus | ORANGE | warmest accent below Fable |
| `*Sonnet*` | Sonnet | TEAL | calm "label" hue; pairs with branch on line 2 |
| Haiku | lightweight | default fg | absence of styling *is* the signal — "workhorse with no flourish" |
| unknown / future | — | default fg | by fall-through |

**Review this mapping when Anthropic ships a new tier name** — a "Pro" / "Lite" between Sonnet and Opus, or a successor scheme — the case statement won't recognise it. (Exercised when Fable 5 landed as the tier above Opus.)

The Opus=ORANGE and Sonnet=TEAL choices each share a hue with a line-2 role (untracked counter and branch). The dual roles are deliberate — both pair "label / attention" semantics across the two lines at distinct positions. **ORANGE and TEAL are at capacity** for line-1 categorical pairing: a future line-1 slot should take default-fg rather than triple-loading either. MAUVE is unavailable — it is the most-loaded identity slot (SSH host marker fleet-wide, deliberately sharing with the path on metis per ADR-028).

## Account label

Line 1 leads with an account label — `Personal` / `Grey St.` per the identity split in [docs/identities.md](../identities.md). The statusline stdin JSON carries no account info, so the script reads `~/.claude.json` at `.oauthAccount.emailAddress` with one extra `jq` per render. Mapping: `daniel@faris.co.nz` → `Personal`, `daniel.faris@gotaxi.co.nz` → `Grey St.`. An unmapped address renders as the raw email (visibly unmapped, never silently wrong); an unreadable or absent file omits the segment and its separator entirely. The label renders in the single `MUTED` tone (base04, the base16 "status-bar foreground" slot) so it reads as static metadata, not a live signal — the words do the distinguishing. Claude-side only; the Cursor statusline has no equivalent account surface.

## Line-2 host + metadata

The host segment (glyph + hostname) sits left, coloured by SSH state — green local, purple SSH — mirroring the starship prompt's signal stack so the two surfaces read the same way (ADR-002 History documents the prompt-side detail and the host-glyph swap). The `(…)`-as-metadata convention applies: the nix-shell marker (`❄`, a Nerd Font glyph) lands on both the prompt and the statusline, inserted between the path and the git block; `(worktree)` lands on the statusline only, since starship has no worktree module wired.

## Sharp edges

**Width mechanics.** Claude Code ≥ 2.1.153 sets `$COLUMNS` / `$LINES` to the live terminal size before each render and re-renders on resize (the stdin JSON has no width field; `tput cols` can't see the terminal from inside the captured script). The fleet's flake pin satisfies the floor. Padding targets `COLUMNS − 1` because writing the final cell triggers auto-wrap on some terminals. Visible width is measured by stripping SGR escapes and counting code points — Nerd Font glyphs are assumed width 1, so a double-width rendering would drift the right edge by one column (cosmetic). The gap clamps to ≥ 1 space: on narrow terminals the right cluster degrades to left-flow.

**RED is shared.** The Fable badge shares base08 with the conditional alarm signals — the conflict counter, the ≥ 80 % context bar, and xhigh/max effort. They stay shape- and position-distinct, and the badge is the only *permanent* red on screen.

**Account label costs a read.** The label adds one `jq` per render over `~/.claude.json` — a file outside the stdin payload. Absent/unreadable degrades cleanly (segment omitted).

## References

- [ADR-024](../decisions/ADR-024-claude-code-config.md) — the framing decision (Claude config via `home.file`) and the dated design-log history this doc supersedes for current state.
- [ADR-028](../decisions/ADR-028-stylix-foundation-and-desktop-env.md) — the Stylix palette source and the base16 slot corrections that let base08 render distinctly from base09 fleet-wide (the precondition for the Fable=RED choice).
- [ADR-002](../decisions/ADR-002-prompt.md) — prompt-side SSH host glyph + the `(…)`-as-metadata convention the statusline mirrors.
- [docs/identities.md](../identities.md) — the personal / work account split the line-1 label surfaces.
- [cursor-statusline.md](./cursor-statusline.md) — the sibling Cursor statusline; shared structure, payload-driven divergences.
- **#331** — the base16 slot corrections (ADR-028, 2026-06-10) that made base08 render distinctly from base09 fleet-wide; the precondition the Fable=RED choice waited on.
