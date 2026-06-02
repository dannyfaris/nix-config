#!/usr/bin/env bash
# ~/.cursor/statusline.sh
# Two-line statusline for Cursor CLI (cursor-agent).
# Line 1: model [max-mode] │ effort │ context bar %
# Line 2: host │ repo-rooted path on branch (worktree) !conflicts +staged ~modified ?untracked
#
# Cross-platform: works on macOS and Linux. Requires jq and a Nerd Font.
# Selection rationale: docs/agents/cursor-statusline.md.
# Schema reference: bundle-extracted; cursor's docs do not yet cover
# .statusLine. Pinned upstream: cursor-cli 0-unstable-2026-05-16.

input=$(cat)
hostname=$(hostname -s)

# Palette-driven colour bindings — sourced from a Nix-generated file at
# startup; mapping lives in home/shared/agent-clis.nix. The file defines
# BLUE / GREEN / YELLOW / RED / MAUVE / ORANGE / TEAL as truecolor SGR
# escapes derived from config.lib.stylix.colors. Same derivation as
# Claude's; no second palette source.
# shellcheck source=/dev/null
source ~/.cursor/statusline-colours.sh
DIM='' # dim SGR too low-contrast in practice; keep var for one-point reintro
RST=$'\033[0m'
SEP=" ${DIM}│${RST} "
CHEV=" ❯ "
BRANCH_GLYPH=$'\xee\x82\xa0'
DESKTOP_GLYPH=$'\xef\x84\x88'
SSH_GLYPH=$'\xef\x92\x89'
NIX_GLYPH=$'\xef\x8b\x9c'

# SSH detection identical to Claude's — survives sudo -i / su -. See
# claude-statusline.sh:43-49 for the rationale and the GH #45 reference.
is_ssh() {
  [ -n "$SSH_CONNECTION" ] && return 0
  case "$(who -m 2>/dev/null)" in
  *\(*\)*) return 0 ;;
  *) return 1 ;;
  esac
}

HOST_GLYPH=$DESKTOP_GLYPH
HOST_COLOUR=$GREEN
if is_ssh; then
  HOST_GLYPH=$SSH_GLYPH
  HOST_COLOUR=$MAUVE
fi

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
} < <(jq -r '
  (.model.display_name // "—"),
  (.model.id // ""),
  (.model.max_mode // false),
  (.workspace.current_dir // ""),
  (.worktree.name // ""),
  (.context_window.used_percentage // 0)
' <<<"$input")

# ─── Model-tier colour ────────────────────────────────────────────
# Match order per docs/agents/cursor-statusline.md: Anthropic-family
# identity dominates (sonnet/opus first); then codex (before gpt-5
# so codex variants colour as YELLOW not MAUVE); then composer, gpt-5;
# gemini / auto / unknown fall through to default fg.
case "$MODEL_ID" in
*sonnet*) MODEL_COL="$TEAL" ;;
*opus*) MODEL_COL="$ORANGE" ;;
*codex*) MODEL_COL="$YELLOW" ;;
*composer*) MODEL_COL="$BLUE" ;;
*gpt-5*) MODEL_COL="$MAUVE" ;;
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

# ─── Git state — identical to Claude's, vendor-neutral ────────────
TOP=""
PREFIX=""
BRANCH=""
HEAD_REF=""
STAGED=0
MODIFIED=0
UNTRACKED=0
CONFLICT=0
if [ -n "$CWD" ]; then
  {
    read -r TOP
    read -r PREFIX
  } < <(
    git -C "$CWD" rev-parse --show-toplevel --show-prefix 2>/dev/null
  )
  if [ -n "$TOP" ]; then
    BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
    [ -z "$BRANCH" ] && HEAD_REF=$(git -C "$CWD" rev-parse --short HEAD 2>/dev/null)
    while IFS= read -r line; do
      case "${line:0:2}" in
      DD | AU | UD | UA | DU | AA | UU) CONFLICT=$((CONFLICT + 1)) ;;
      '??') UNTRACKED=$((UNTRACKED + 1)) ;;
      *)
        [ "${line:0:1}" != " " ] && STAGED=$((STAGED + 1))
        [ "${line:1:1}" != " " ] && MODIFIED=$((MODIFIED + 1))
        ;;
      esac
    done < <(git -C "$CWD" status --porcelain 2>/dev/null)
  fi
fi

# ─── Path: repo-rooted, with non-git fallback ─────────────────────
SHORT_CWD=""
if [ -n "$TOP" ]; then
  repo_name="${TOP##*/}"
  PREFIX="${PREFIX%/}"
  if [ -n "$PREFIX" ]; then
    SHORT_CWD="${repo_name}/${PREFIX}"
  else
    SHORT_CWD="${repo_name}"
  fi
elif [ -n "$CWD" ]; then
  display_cwd="${CWD/#$HOME/~}"
  SHORT_CWD=$(awk -F/ '{
    n=NF
    if (n<=3) print $0
    else printf ".../%s/%s/%s", $(n-2), $(n-1), $n
  }' <<<"$display_cwd")
fi

# ─── Git segment — identical to Claude's ──────────────────────────
GIT_SEG=""
if [ -n "$TOP" ]; then
  GIT_LABEL=""
  if [ -n "$BRANCH" ]; then
    GIT_LABEL="$BRANCH"
  elif [ -n "$HEAD_REF" ]; then
    GIT_LABEL="@${HEAD_REF}"
  fi
  if [ -n "$GIT_LABEL" ]; then
    if [ -n "$BRANCH" ]; then
      GIT_SEG=" ${DIM}on${RST} ${TEAL}${BRANCH_GLYPH} ${GIT_LABEL}${RST}"
    else
      GIT_SEG=" ${TEAL}${BRANCH_GLYPH} ${GIT_LABEL}${RST}"
    fi
    [ -n "$WORKTREE" ] && GIT_SEG+=" ${DIM}(${WORKTREE})${RST}"
    [ "$CONFLICT" -gt 0 ] && GIT_SEG+=" ${RED}!${CONFLICT}${RST}"
    [ "$STAGED" -gt 0 ] && GIT_SEG+=" ${GREEN}+${STAGED}${RST}"
    [ "$MODIFIED" -gt 0 ] && GIT_SEG+=" ${YELLOW}~${MODIFIED}${RST}"
    [ "$UNTRACKED" -gt 0 ] && GIT_SEG+=" ${ORANGE}?${UNTRACKED}${RST}"
  fi
fi

# ─── Context bar with threshold colours ───────────────────────────
PCT=${PCT_RAW%%.*}
case "$PCT" in
'' | *[!0-9]*) PCT=0 ;;
esac
[ "$PCT" -lt 0 ] && PCT=0
[ "$PCT" -gt 100 ] && PCT=100
if [ "$PCT" -ge 80 ]; then
  BC="$RED"
elif [ "$PCT" -ge 60 ]; then
  BC="$YELLOW"
else
  BC="$GREEN"
fi
F=$((PCT / 10))
E=$((10 - F))
BAR=""
for ((i = 0; i < F; i++)); do BAR+="█"; done
for ((i = 0; i < E; i++)); do BAR+="░"; done

# ═══ LINE 1: model [max] │ effort │ context ═══════════════════════
# No rate-limit segment — cursor's billing model has no rolling-window
# analogue to Claude's .rate_limits.five_hour.*. See
# docs/agents/cursor-statusline.md §Selection.
printf '%s✦ %s%s%s%s%s %s%s%s %d%%\n' \
  "$MODEL_COL" "$MODEL" "$MAX_MODE_SUFFIX" "$RST" \
  "$EFFORT_SEG" "$SEP" \
  "$BC" "$BAR" "$RST" \
  "$PCT"

# ═══ LINE 2: host │ path on branch ════════════════════════════════
NIX_SHELL_SEG=""
[ -n "$IN_NIX_SHELL" ] && NIX_SHELL_SEG=" (${BLUE}${NIX_GLYPH}${RST})"

LINE2="${HOST_COLOUR}${HOST_GLYPH}  ${hostname}${RST}"
[ -n "$SHORT_CWD" ] && LINE2+="${CHEV}${BLUE}${SHORT_CWD}${RST}${NIX_SHELL_SEG}${GIT_SEG}"
printf '%s\n' "$LINE2"
