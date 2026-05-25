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

BLUE=$'\033[38;5;75m'
GREEN=$'\033[38;5;114m'
YELLOW=$'\033[38;5;179m'
RED=$'\033[38;5;167m'
MAUVE=$'\033[38;5;141m'
TEAL=$'\033[38;5;73m'
DIM=$'\033[2m'
RST=$'\033[0m'
SEP=" ${DIM}│${RST} "
# Nerd Font glyphs as UTF-8 hex bytes — bash 3.2+ compatible and avoids
# putting raw Nerd Font bytes in the source file.
BRANCH_GLYPH=$'\xee\x82\xa0'   # U+E0A0 Powerline branch
DESKTOP_GLYPH=$'\xef\x84\x88'  # U+F108 nf-fa-desktop (host marker)
CLOCK_GLYPH=$'\xef\x80\x97'    # U+F017 nf-fa-clock_o (rate-limit marker)

{
  read -r MODEL
  read -r CWD
  read -r WORKTREE
  read -r PCT_RAW
  read -r EFFORT
  read -r FIVE_PCT
  read -r FIVE_RESET
  read -r SESSION_ID
} < <(jq -r '
  (.model.display_name // "—"),
  (.workspace.current_dir // ""),
  (.workspace.git_worktree // ""),
  (.context_window.used_percentage // 0),
  (.effort.level // ""),
  (.rate_limits.five_hour.used_percentage // ""),
  (.rate_limits.five_hour.resets_at // ""),
  (.session_id // "")
' <<<"$input")

# ─── Unified cache: path resolution + git status (5s TTL) ─────────
# Keyed on session_id + CWD so cd-between-repos within a session
# doesn't show wrong (cross-repo) data. Bash 3.2-safe truncation
# keeps the filename under typical filesystem limits.
CACHE_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
SAFE_CWD="${CWD//\//_}"
if [ ${#SAFE_CWD} -gt 200 ]; then
  SAFE_CWD="${SAFE_CWD:${#SAFE_CWD}-200}"
fi
CF="${CACHE_DIR%/}/cc-statusline-${SESSION_ID}-${SAFE_CWD}"
CACHE_MAX_AGE=5
# Cache field separator: ASCII Unit Separator (\x1f). Tab can't be used —
# bash's `read` with whitespace-only IFS collapses consecutive delimiters,
# destroying empty fields (PREFIX is empty at repo root, HEAD_REF is empty
# on attached HEAD), which silently misaligned every subsequent field.
US=$'\x1f'

stat_mtime() {
  # GNU stat (Linux) first; BSD stat (macOS) as fallback.
  # On GNU stat, "-f" means filesystem-info mode and would corrupt the
  # output — putting -c first picks GNU's correct mtime format on Linux
  # and falls through cleanly to BSD's "-f %m" on macOS.
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}
cache_fresh() {
  [ -f "$CF" ] && [ $((NOW - $(stat_mtime "$CF"))) -lt "$CACHE_MAX_AGE" ]
}

IS_REPO=0; TOP=""; PREFIX=""; BRANCH=""; HEAD_REF=""
STAGED=0; MODIFIED=0; UNTRACKED=0; CONFLICT=0

if [ -n "$CWD" ]; then
  if cache_fresh; then
    IFS="$US" read -r IS_REPO TOP PREFIX BRANCH HEAD_REF \
                       STAGED MODIFIED UNTRACKED CONFLICT < "$CF"
  else
    { read -r TOP; read -r PREFIX; } < <(
      git -C "$CWD" rev-parse --show-toplevel --show-prefix 2>/dev/null
    )
    if [ -n "$TOP" ]; then
      IS_REPO=1
      BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
      [ -z "$BRANCH" ] && HEAD_REF=$(git -C "$CWD" rev-parse --short HEAD 2>/dev/null)
      while IFS= read -r line; do
        case "${line:0:2}" in
          DD|AU|UD|UA|DU|AA|UU) CONFLICT=$((CONFLICT + 1)) ;;
          '??')                 UNTRACKED=$((UNTRACKED + 1)) ;;
          *)
            [ "${line:0:1}" != " " ] && STAGED=$((STAGED + 1))
            [ "${line:1:1}" != " " ] && MODIFIED=$((MODIFIED + 1))
            ;;
        esac
      done < <(git -C "$CWD" status --porcelain 2>/dev/null)
    fi
    TMP="${CF}.$$.tmp"
    printf "%s${US}%s${US}%s${US}%s${US}%s${US}%s${US}%s${US}%s${US}%s\n" \
      "$IS_REPO" "$TOP" "$PREFIX" "$BRANCH" "$HEAD_REF" \
      "$STAGED" "$MODIFIED" "$UNTRACKED" "$CONFLICT" > "$TMP" \
      && mv -f "$TMP" "$CF"
  fi
fi

SHORT_CWD=""
if [ "$IS_REPO" = "1" ] && [ -n "$TOP" ]; then
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

GIT_SEG=""
if [ "$IS_REPO" = "1" ]; then
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
    [ -n "$WORKTREE" ]           && GIT_SEG+=" ${DIM}(${WORKTREE})${RST}"
    [ "${CONFLICT:-0}"  -gt 0 ]  && GIT_SEG+=" ${RED}!${CONFLICT}${RST}"
    [ "${STAGED:-0}"    -gt 0 ]  && GIT_SEG+=" ${GREEN}+${STAGED}${RST}"
    [ "${MODIFIED:-0}"  -gt 0 ]  && GIT_SEG+=" ${YELLOW}~${MODIFIED}${RST}"
    [ "${UNTRACKED:-0}" -gt 0 ]  && GIT_SEG+=" ${MAUVE}?${UNTRACKED}${RST}"
  fi
fi

EFFORT_SEG=""
case "$EFFORT" in
  low)    EFFORT_SEG="${SEP}${DIM}▽ low${RST}" ;;
  medium) EFFORT_SEG="${SEP}${YELLOW}◆ med${RST}" ;;
  high)   EFFORT_SEG="${SEP}${YELLOW}▲ high${RST}" ;;
  xhigh)  EFFORT_SEG="${SEP}${RED}▲ xhigh${RST}" ;;
  max)    EFFORT_SEG="${SEP}${RED}⬆ max${RST}" ;;
esac

PCT=${PCT_RAW%%.*}
case "$PCT" in
  ''|*[!0-9]*) PCT=0 ;;
esac
[ "$PCT" -lt 0 ]   && PCT=0
[ "$PCT" -gt 100 ] && PCT=100
if   [ "$PCT" -ge 80 ]; then BC="$RED"
elif [ "$PCT" -ge 60 ]; then BC="$YELLOW"
else                         BC="$GREEN"
fi
F=$((PCT / 10)); E=$((10 - F))
BAR=""
for ((i=0; i<F; i++)); do BAR+="█"; done
for ((i=0; i<E; i++)); do BAR+="░"; done

RLIM=""
if [ -n "$FIVE_PCT" ]; then
  FI=$(printf '%.0f' "$FIVE_PCT" 2>/dev/null || echo 0)
  RLIM="${SEP}${CLOCK_GLYPH}  ${FI}%"
  case "$FIVE_RESET" in
    ''|*[!0-9]*) ;;
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
LINE2="${DIM}${DESKTOP_GLYPH}  ${hostname}${RST}"
[ -n "$SHORT_CWD" ] && LINE2+="${SEP}${BLUE}${SHORT_CWD}${RST}${GIT_SEG}"
printf '%s\n' "$LINE2"
