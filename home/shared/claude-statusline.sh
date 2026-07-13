#!/usr/bin/env bash
# ~/.claude/statusline.sh
# Two-line, two-cluster statusline for Claude Code. Left clusters hold
# identity/config, right clusters (flush right, padded to $COLUMNS) hold
# the live meters. Layout rationale: ADR-024 §Implementation.
# Line 1: account │ model │ effort          ···   <ctx%> <bar>
# Line 2: host ❯ path on branch counts      ···   <clock> <5h%> <countdown>
#
# Cross-platform: works on macOS and Linux. Requires jq and a Nerd Font.
# Schema reference: https://code.claude.com/docs/en/statusline
#
# Shared rendering core — glyphs, width machinery (vw/pad2), git-state
# parser, path shortener, segment/bar renderers — lives in
# ~/.claude/statusline-lib.sh (home/shared/statusline-lib.sh), sourced
# below; this script owns only Claude's payload schema and its unique
# segments (account, model tier, effort, rate limit). See #339.

input=$(cat)
NOW=$(date +%s)
hostname=$(hostname -s)

# Palette-driven colour bindings (BLUE/GREEN/YELLOW/RED/MAUVE/ORANGE/TEAL/
# MUTED, classic ANSI-16 SGR following the terminal palette) and the account →
# label map, both Nix-generated — mappings live in home/shared/agent-clis.nix.
# The shared rendering lib is static. See ADR-024 §Implementation, ADR-028
# slice 6, and #339.
# shellcheck source=/dev/null
source ~/.claude/statusline-colours.sh
# shellcheck source=/dev/null
source ~/.claude/statusline-identities.sh
# shellcheck source=/dev/null
source ~/.claude/statusline-lib.sh

# Host marker (HOST_GLYPH/HOST_COLOUR) + git state — shared lib. The marker
# reads the live connection so it's correct after a zellij detach/reattach
# across contexts (#270); one of four surfaces sharing that detector.
statusline_host_marker

# ─── Account label — leading line-1 segment ───────────────────────
# The statusline stdin JSON carries no account info; the address
# /status shows lives in ~/.claude.json (.oauthAccount.emailAddress).
# The email→label map is single-sourced from lib/operator.nix's identities
# (generated into statusline-identities.sh, #339). Unknown address → raw
# email (visibly unmapped, never silently wrong); unreadable/absent →
# segment and its separator are omitted entirely.
ACCOUNT_SEG=""
ACCOUNT_EMAIL=$(jq -r '.oauthAccount.emailAddress // empty' "$HOME/.claude.json" 2>/dev/null)
if [ -n "$ACCOUNT_EMAIL" ]; then
  ACCOUNT_LABEL=$(statusline_account_label "$ACCOUNT_EMAIL")
  ACCOUNT_SEG="${MUTED}${ACCOUNT_LABEL}${RST}${SEP}"
fi

{
  read -r MODEL
  read -r CWD
  read -r WORKTREE
  read -r PCT_RAW
  read -r EFFORT
  read -r FIVE_PCT
  read -r FIVE_RESET
} < <(jq -r '
  (.model.display_name // "—"),
  (.workspace.current_dir // ""),
  (.workspace.git_worktree // ""),
  (.context_window.used_percentage // 0),
  (.effort.level // ""),
  (.rate_limits.five_hour.used_percentage // ""),
  (.rate_limits.five_hour.resets_at // "")
' <<<"$input")

# Model name colour — per-tier so the active model is identifiable at a
# glance. Substring match so future variants ("Claude 5 Opus", "Sonnet
# 4.7", etc.) inherit their tier's colour. Fable (frontier, above Opus)
# wears RED — the warmth ladder's top rung. Order encodes precedence:
# the first pattern to match wins, so an Opus-tuned Sonnet (hypothetical
# `Sonnet (Opus-tuned)`) would match `*Sonnet*` first — keep Sonnet
# before Opus if you need that. Haiku and unknown models hit the `*)`
# fall-through and render in default foreground. See ADR-024
# §Implementation.
case "$MODEL" in
*Fable*) MODEL_COL="$RED" ;;
*Sonnet*) MODEL_COL="$TEAL" ;;
*Opus*) MODEL_COL="$ORANGE" ;;
*) MODEL_COL="" ;;
esac

# Git state + repo-rooted path + segment — shared lib (queried fresh each
# render, no cache: renders are debounced/event-driven, so three git
# invocations is fine; caching was Slice 1's bug source). WORKTREE feeds
# the segment's `(worktree)` tag.
statusline_git_state "$CWD"
SHORT_CWD=$(statusline_short_cwd "$CWD")
GIT_SEG=$(statusline_git_segment "$WORKTREE")

# ─── Effort indicator ─────────────────────────────────────────────
EFFORT_SEG=""
case "$EFFORT" in
low) EFFORT_SEG="${SEP}${DIM}▽ low${RST}" ;;
medium) EFFORT_SEG="${SEP}${YELLOW}◆ med${RST}" ;;
high) EFFORT_SEG="${SEP}${YELLOW}▲ high${RST}" ;;
xhigh) EFFORT_SEG="${SEP}${RED}▲ xhigh${RST}" ;;
max) EFFORT_SEG="${SEP}${RED}⬆ max${RST}" ;;
esac

# ─── 5h rate limit with reset countdown ───────────────────────────
# Line 2's right cluster. The clock glyph stays load-bearing here: it
# disambiguates this percentage from the context % stacked directly
# above it at the right edge.
RLIM=""
if [ -n "$FIVE_PCT" ]; then
  FI=$(printf '%.0f' "$FIVE_PCT" 2>/dev/null || echo 0)
  RLIM="${CLOCK_GLYPH}  ${FI}%"
  case "$FIVE_RESET" in
  '' | *[!0-9]*) ;;
  *)
    REM=$((FIVE_RESET - NOW))
    if [ "$REM" -gt 0 ]; then
      RLIM+=" ${DIM}$((REM / 3600))h$(((REM % 3600) / 60))m${RST}"
    fi
    ;;
  esac
fi

# ═══ LINE 1: account │ model │ effort ··· ctx% bar ════════════════
# Right cluster is <pct%> <bar> — number BEFORE bar, so the fixed-width
# bar is the flush-right anchor and only the digits float in the gap.
# Bar-first would wobble the whole cluster as the % gains digits. Claude
# Code sets $COLUMNS to the live terminal width before each render and
# re-renders on resize, so the flush-right pad stays correct; pad to
# COLUMNS−1 because writing the final cell triggers auto-wrap on some
# terminals.
pad2 "$((${COLUMNS:-80} - 1))" \
  "${ACCOUNT_SEG}${MODEL_COL}✦ ${MODEL}${RST}${EFFORT_SEG}" \
  "$(statusline_context_cluster "$PCT_RAW")"

# ═══ LINE 2: host ❯ path on branch ··· 5h% countdown ══════════════
# Nix-shell metadata `(❄️)` folds into the shared line-2 left cluster.
# $IN_NIX_SHELL is set by nix-direnv on flake-env activation and inherited
# into the Claude Code subprocess (same env-at-spawn caveat as
# $SSH_CONNECTION). See ADR-002's `(…)`-as-metadata convention.
pad2 "$((${COLUMNS:-80} - 1))" \
  "$(statusline_line2_left "$hostname" "$SHORT_CWD" "$GIT_SEG")" \
  "$RLIM"
