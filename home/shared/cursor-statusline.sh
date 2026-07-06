#!/usr/bin/env bash
# ~/.cursor/statusline.sh
# Two-line statusline for Cursor CLI (cursor-agent).
# Line 1: model [max] │ effort          ···   <ctx%> <bar>
# Line 2: host ❯ path on branch counts   (no right cluster — no rate-limit analogue)
#
# Cross-platform: works on macOS and Linux. Requires jq and a Nerd Font.
# Selection rationale: docs/agents/cursor-statusline.md.
# Schema reference: bundle-extracted; cursor's docs do not yet cover
# .statusLine. Pinned upstream: cursor-cli 0-unstable-2026-05-16.
#
# Shared rendering core — glyphs, width machinery (vw/pad2), git-state
# parser, path shortener, segment/bar renderers — lives in
# ~/.cursor/statusline-lib.sh (home/shared/statusline-lib.sh), sourced
# below; this script owns only Cursor's payload schema and its unique
# segments (model tier, max-mode, effort-from-id). Cursor has no account
# segment, so it sources no identities map. See #339.

input=$(cat)
hostname=$(hostname -s)

# Palette-driven colour bindings — Nix-generated (same derivation as
# Claude's; mapping in home/shared/agent-clis.nix). The shared rendering lib
# is static. See docs/agents/cursor-statusline.md and #339.
# shellcheck source=/dev/null
source ~/.cursor/statusline-colours.sh
# shellcheck source=/dev/null
source ~/.cursor/statusline-lib.sh

# Host marker (HOST_GLYPH/HOST_COLOUR) — shared lib; identical to Claude's.
# Correct after a zellij detach/reattach across contexts (#270).
statusline_host_marker

# ─── Stdin parse — cursor's payload shape ─────────────────────────
# Schema diverges from Claude's: no .effort.level (effort encoded in
# model.id), no .rate_limits.*, worktree is a top-level OBJECT
# {name, path} not a string under .workspace.git_worktree. See
# docs/agents/cursor-statusline.md §"Cursor-specific signals".
{
  read -r MODEL
  read -r MODEL_ID
  read -r MAX_MODE
  read -r CWD
  read -r WORKTREE
  read -r PCT_RAW
  read -r RENDER_WIDTH
} < <(jq -r '
  (.model.display_name // "—"),
  (.model.id // ""),
  (.model.max_mode // false),
  (.workspace.current_dir // ""),
  (.worktree.name // ""),
  (.context_window.used_percentage // 0),
  (.render_width_chars // 80)
' <<<"$input")

# ─── Model-tier colour ────────────────────────────────────────────
# Match order per docs/agents/cursor-statusline.md: Anthropic-family
# identity dominates (fable/sonnet/opus first); then codex (before
# gpt-5 so codex variants colour as YELLOW not ORANGE); then composer,
# gpt-5 (ORANGE — Opus's tier-mate, coloured by tier not vendor; see
# ADR-024 §Implementation 2026-06-10); gemini / auto / unknown fall
# through to default fg.
case "$MODEL_ID" in
*fable*) MODEL_COL="$RED" ;;
*sonnet*) MODEL_COL="$TEAL" ;;
*opus*) MODEL_COL="$ORANGE" ;;
*codex*) MODEL_COL="$YELLOW" ;;
*composer*) MODEL_COL="$BLUE" ;;
*gpt-5*) MODEL_COL="$ORANGE" ;;
*) MODEL_COL="" ;;
esac

# max-mode marker — expanded context for the same model. Render as a
# small upward arrow immediately after the model name when set.
MAX_MODE_SUFFIX=""
[ "$MAX_MODE" = "true" ] && MAX_MODE_SUFFIX=" ↑"

# ─── Effort — derived from model.id suffix ────────────────────────
# Cursor encodes effort in the id (-low / -medium / -high / -xhigh)
# rather than exposing .effort.level like Claude. Match order: xhigh
# before high (substring containment); -low and -medium are
# unambiguous and order doesn't matter relative to them. The -max
# suffix is a quality tier in some families (gpt-5.1-codex-max-*,
# claude-opus-*-max), not an effort level — left unmapped per the
# spec note in docs/agents/cursor-statusline.md §Effort derivation.
EFFORT_SEG=""
case "$MODEL_ID" in
*-xhigh*) EFFORT_SEG="${SEP}${RED}▲ xhigh${RST}" ;;
*-high*) EFFORT_SEG="${SEP}${YELLOW}▲ high${RST}" ;;
*-medium*) EFFORT_SEG="${SEP}${YELLOW}◆ med${RST}" ;;
*-low*) EFFORT_SEG="${SEP}${DIM}▽ low${RST}" ;;
esac

# Git state + repo-rooted path + segment — shared lib. WORKTREE (cursor's
# .worktree.name) feeds the segment's `(worktree)` tag.
statusline_git_state "$CWD"
SHORT_CWD=$(statusline_short_cwd "$CWD")
GIT_SEG=$(statusline_git_segment "$WORKTREE")

# ═══ LINE 1: model [max] │ effort ··· ctx% bar ════════════════════
# Right cluster is <pct%> <bar> — number BEFORE bar so the fixed-width bar
# anchors flush-right (mirrors Claude's line 1). No rate-limit segment —
# cursor's billing has no rolling-window analogue to Claude's
# .rate_limits.five_hour.*. Pads to render_width_chars (the payload's own
# usable-width signal, net of statusLine.padding) — cursor does not set
# $COLUMNS. See docs/agents/cursor-statusline.md §Selection.
pad2 "${RENDER_WIDTH:-80}" \
  "${MODEL_COL}✦ ${MODEL}${MAX_MODE_SUFFIX}${RST}${EFFORT_SEG}" \
  "$(statusline_context_cluster "$PCT_RAW")"

# ═══ LINE 2: host ❯ path on branch ════════════════════════════════
# Structural pad2 with an EMPTY right cluster — cursor has no rate-limit
# segment, so output is left-flow today, but the layout call stays aligned
# with Claude's and gains a right cluster for free if cursor ever exposes a
# rolling-window signal (#354). Nix-shell metadata folds into the shared
# line-2 left cluster.
pad2 "${RENDER_WIDTH:-80}" \
  "$(statusline_line2_left "$hostname" "$SHORT_CWD" "$GIT_SEG")" \
  ""
