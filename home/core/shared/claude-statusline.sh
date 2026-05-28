#!/usr/bin/env bash
# ~/.claude/statusline.sh
# Two-line statusline for Claude Code.
# Line 1: model │ effort │ context bar % │ 5h-window clock + countdown
# Line 2: host │ repo-rooted path on branch (worktree) !conflicts +staged ~modified ?untracked
#
# Cross-platform: works on macOS and Linux. Requires jq and a Nerd Font.
# Schema reference: https://code.claude.com/docs/en/statusline

input=$(cat)
NOW=$(date +%s)
hostname=$(hostname -s)

# Palette-driven colour bindings — sourced from a Nix-generated file at
# startup; mapping lives in home/core/shared/agent-clis.nix. The file
# defines BLUE / GREEN / YELLOW / RED / MAUVE / TEAL as truecolor SGR
# escapes derived from config.lib.stylix.colors. See ADR-024
# §Implementation and ADR-028 slice 6 for the migration rationale.
# shellcheck source=/dev/null
source ~/.claude/statusline-colours.sh
DIM='' # dim SGR too low-contrast in practice; keep var for one-point reintro
RST=$'\033[0m'
SEP=" ${DIM}│${RST} " # line 1 status-bar separator (parallel segments)
CHEV=" ❯ "            # line 2 reading-flow separator (sequential segments)
# Nerd Font glyphs as UTF-8 hex bytes — bash 3.2+ compatible and avoids
# putting raw Nerd Font bytes in the source file.
BRANCH_GLYPH=$'\xee\x82\xa0'  # U+E0A0 Powerline branch
DESKTOP_GLYPH=$'\xef\x84\x88' # U+F108 nf-fa-desktop (local host marker)
SSH_GLYPH=$'\xef\x92\x89'     # U+F489 nf-mdi-console_network (SSH host marker)
CLOCK_GLYPH=$'\xef\x80\x97'   # U+F017 nf-fa-clock_o (rate-limit marker)

# Host marker — swaps based on SSH state to mirror the starship prompt
# (ADR-002 history). $SSH_CONNECTION is set by sshd on login and inherited
# into the Claude Code subprocess; same env-at-spawn caveat applies for
# detached zellij sessions reattached from a different context.
HOST_GLYPH=$DESKTOP_GLYPH
[ -n "$SSH_CONNECTION" ] && HOST_GLYPH=$SSH_GLYPH

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

# ─── Git state — queried fresh each render, no cache ──────────────
# Statusline renders are debounced (~300ms) and event-driven, not a hot
# loop, so three git invocations per render is fine. Caching this was
# the source of all of Slice 1's platform-specific bugs; not worth it.
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

# ─── Git segment ──────────────────────────────────────────────────
GIT_SEG=""
if [ -n "$TOP" ]; then
  GIT_LABEL=""
  if [ -n "$BRANCH" ]; then
    GIT_LABEL="$BRANCH"
  elif [ -n "$HEAD_REF" ]; then
    GIT_LABEL="@${HEAD_REF}"
  fi
  if [ -n "$GIT_LABEL" ]; then
    # On a branch: "<path> on <glyph> <branch>" (DIM "on", TEAL glyph+name).
    # Detached HEAD: "<path> <glyph> @<sha>" — "on" reads oddly with a SHA.
    if [ -n "$BRANCH" ]; then
      GIT_SEG=" ${DIM}on${RST} ${TEAL}${BRANCH_GLYPH} ${GIT_LABEL}${RST}"
    else
      GIT_SEG=" ${TEAL}${BRANCH_GLYPH} ${GIT_LABEL}${RST}"
    fi
    [ -n "$WORKTREE" ] && GIT_SEG+=" ${DIM}(${WORKTREE})${RST}"
    [ "$CONFLICT" -gt 0 ] && GIT_SEG+=" ${RED}!${CONFLICT}${RST}"
    [ "$STAGED" -gt 0 ] && GIT_SEG+=" ${GREEN}+${STAGED}${RST}"
    [ "$MODIFIED" -gt 0 ] && GIT_SEG+=" ${YELLOW}~${MODIFIED}${RST}"
    [ "$UNTRACKED" -gt 0 ] && GIT_SEG+=" ${MAUVE}?${UNTRACKED}${RST}"
  fi
fi

# ─── Effort indicator ─────────────────────────────────────────────
EFFORT_SEG=""
case "$EFFORT" in
low) EFFORT_SEG="${SEP}${DIM}▽ low${RST}" ;;
medium) EFFORT_SEG="${SEP}${YELLOW}◆ med${RST}" ;;
high) EFFORT_SEG="${SEP}${YELLOW}▲ high${RST}" ;;
xhigh) EFFORT_SEG="${SEP}${RED}▲ xhigh${RST}" ;;
max) EFFORT_SEG="${SEP}${RED}⬆ max${RST}" ;;
esac

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

# ─── 5h rate limit with reset countdown ───────────────────────────
RLIM=""
if [ -n "$FIVE_PCT" ]; then
  FI=$(printf '%.0f' "$FIVE_PCT" 2>/dev/null || echo 0)
  RLIM="${SEP}${CLOCK_GLYPH}  ${FI}%"
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

# ═══ LINE 1: model │ effort │ context │ rate-limit ═══════════════
printf '%s✦ %s%s%s%s%s%s%s %d%%%s\n' \
  "$MAUVE" "$MODEL" "$RST" \
  "$EFFORT_SEG" "$SEP" \
  "$BC" "$BAR" "$RST" \
  "$PCT" "$RLIM"

# ═══ LINE 2: host │ path on branch ════════════════════════════════
LINE2="${DIM}${HOST_GLYPH}  ${hostname}${RST}"
[ -n "$SHORT_CWD" ] && LINE2+="${CHEV}${BLUE}${SHORT_CWD}${RST}${GIT_SEG}"
printf '%s\n' "$LINE2"
