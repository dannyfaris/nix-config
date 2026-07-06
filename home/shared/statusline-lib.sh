# shellcheck shell=bash
# statusline-lib — the shared rendering core for the agent statuslines
# (home/shared/{claude,cursor}-statusline.sh) and the zjstatus git widget
# (home/shared/multiplexer.nix). Sourced, never executed. Single-sources
# the git-state parser, path shortener, segment/bar renderers, width
# machinery, and glyph tables that were hand-mirrored across those surfaces
# and used to drift (#339 — the session-type.nix lesson applied to git
# state). Colours come from the Nix-generated statusline-colours.sh; this
# file carries no Nix-derived value, so it stays a static, shellcheck-able
# repo file. The starship prompt (home/shared/prompt.nix) mirrors the same
# visual vocabulary but is declarative config and cannot consume this lib —
# its parity stays conventional.
#
# Consumers source colours first, then this lib, then call the functions in
# their own body. Functions read their colour/DIM inputs at call time (late
# binding), so source order between colours and lib is free.

# Style codes (not colours) — shared by every surface.
DIM='' # dim SGR too low-contrast in practice; keep var for one-point reintro
RST=$'\033[0m'
# shellcheck disable=SC2034 # exported to the sourcing scripts, not used within this lib.
SEP=" ${DIM}│${RST} " # line-1 status-bar separator (parallel segments)
CHEV=" ❯ "            # line-2 reading-flow separator (sequential segments)

# Nerd Font glyphs as UTF-8 hex bytes — bash 3.2+ compatible and avoids
# putting raw Nerd Font bytes in the source file.
BRANCH_GLYPH=$'\xee\x82\xa0'  # U+E0A0 Powerline branch
DESKTOP_GLYPH=$'\xef\x84\x88' # U+F108 nf-fa-desktop (local host marker)
SSH_GLYPH=$'\xef\x92\x89'     # U+F489 nf-mdi-console_network (SSH host marker)
# shellcheck disable=SC2034 # CLOCK_GLYPH is Claude-only; exported, not used within this lib.
CLOCK_GLYPH=$'\xef\x80\x97' # U+F017 nf-fa-clock_o (rate-limit marker)
# NIX_GLYPH: picked U+F2DC over Unicode U+2744 to dodge VS16 width
# disagreements in Zellij (emoji-presentation forces width 2, Zellij's grid
# reads U+2744 as width 1) and stay consistent with the Nerd Font glyphs above.
NIX_GLYPH=$'\xef\x8b\x9c' # U+F2DC nf-fa-snowflake (nix-shell marker)

# Presentation-wide glyphs — render as TWO terminal cells in a Nerd Font but
# are single code points, which vw() corrects for (#354). The set: the PUA
# glyphs above, the ✦ model marker, and the │ separator (box-drawing, wide in
# this font). The bar's █/░ are intentionally ABSENT — though also East-Asian-
# ambiguous like │, the renderer counts them as one cell (a doubled bar would
# mis-render), so listing them would over-pad. A standard wcwidth reports all
# of these as width 1 (the bug), so the correction is an explicit per-glyph
# table, not a wcwidth call. CLOCK_GLYPH is Claude-only at the emit site;
# listing it here is inert for surfaces that never emit it (the substitution
# below is a no-op on a string that lacks it). A new wide glyph MUST be added
# here, or its line over-pads and truncates.
WIDE_GLYPHS=("$BRANCH_GLYPH" "$DESKTOP_GLYPH" "$SSH_GLYPH" "$CLOCK_GLYPH" "$NIX_GLYPH" "✦" "│")

# Visible display width: SGR escapes stripped, code points counted, then
# +1 per presentation-wide glyph (WIDE_GLYPHS) — each renders as two cells
# but counts as one code point. The flush-right pad below leaves zero
# slack, so an undercount overflows and the line truncates (#354). The
# scripts emit no other wide chars (no CJK/combining), so code points plus
# this fixed correction equals true display width.
vw() {
  local s stripped g
  s=$(printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g')
  stripped=$s
  for g in "${WIDE_GLYPHS[@]}"; do stripped=${stripped//$g/}; done
  printf '%s' "$((${#s} + ${#s} - ${#stripped}))"
}

# Two-cluster flush-right layout: pad2 <total-width> <left> [<right>]. The
# caller supplies the width model — Claude pads to $COLUMNS-1 (writing the
# final cell auto-wraps on some terminals), Cursor to its payload's
# render_width_chars. Empty right → left only. Gap clamps to ≥1 space: on a
# narrow terminal the right cluster degrades to left-flow (and may soft-wrap
# if content alone exceeds the width — same as pre-cluster behaviour).
pad2() {
  local width=$1 left=$2 right=${3:-} gap
  if [ -z "$right" ]; then
    printf '%s\n' "$left"
    return
  fi
  gap=$((width - $(vw "$left") - $(vw "$right")))
  [ "$gap" -lt 1 ] && gap=1
  printf '%s%*s%s\n' "$left" "$gap" '' "$right"
}

# Host marker — sets HOST_GLYPH + HOST_COLOUR by connection type, via the
# shared `session-type` command (home/shared/session-type.nix). Inside zellij
# it reads the live client's connection, so the marker is correct after a
# detach/reattach across contexts (#270); outside it's $SSH_CONNECTION + who
# -m (survives sudo -i / su -). GREEN/MAUVE map to base0B/base0E via Stylix.
statusline_host_marker() {
  HOST_GLYPH=$DESKTOP_GLYPH
  HOST_COLOUR=$GREEN
  if [ "$(session-type 2>/dev/null)" = ssh ]; then
    HOST_GLYPH=$SSH_GLYPH
    HOST_COLOUR=$MAUVE
  fi
}

# Git state for a working dir → globals TOP PREFIX BRANCH HEAD_REF STAGED
# MODIFIED UNTRACKED CONFLICT. Porcelain XY categorisation: the conflict
# codes, then untracked, else staged (index col) / modified (worktree col).
# The single home for the counter that used to live in three places (#339).
statusline_git_state() {
  local cwd=$1 line
  TOP=""
  PREFIX=""
  BRANCH=""
  HEAD_REF=""
  STAGED=0
  MODIFIED=0
  UNTRACKED=0
  CONFLICT=0
  [ -z "$cwd" ] && return
  {
    read -r TOP
    read -r PREFIX
  } < <(
    git -C "$cwd" rev-parse --show-toplevel --show-prefix 2>/dev/null
  )
  [ -z "$TOP" ] && return
  BRANCH=$(git -C "$cwd" branch --show-current 2>/dev/null)
  [ -z "$BRANCH" ] && HEAD_REF=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  while IFS= read -r line; do
    case "${line:0:2}" in
    DD | AU | UD | UA | DU | AA | UU) CONFLICT=$((CONFLICT + 1)) ;;
    '??') UNTRACKED=$((UNTRACKED + 1)) ;;
    *)
      [ "${line:0:1}" != " " ] && STAGED=$((STAGED + 1))
      [ "${line:1:1}" != " " ] && MODIFIED=$((MODIFIED + 1))
      ;;
    esac
  done < <(git -C "$cwd" status --porcelain 2>/dev/null)
}

# Repo-rooted short path (echoes), needs TOP/PREFIX from statusline_git_state:
# "<repo>" or "<repo>/<prefix>" inside a repo; outside, the last three path
# components of $CWD (~-collapsed) with a ".../" prefix.
statusline_short_cwd() {
  local cwd=$1
  if [ -n "$TOP" ]; then
    local repo_name="${TOP##*/}" prefix="${PREFIX%/}"
    if [ -n "$prefix" ]; then
      printf '%s' "${repo_name}/${prefix}"
    else
      printf '%s' "${repo_name}"
    fi
  elif [ -n "$cwd" ]; then
    local display_cwd="${cwd/#$HOME/~}"
    awk -F/ '{
      n=NF
      if (n<=3) print $0
      else printf ".../%s/%s/%s", $(n-2), $(n-1), $n
    }' <<<"$display_cwd"
  fi
}

# Git segment (echoes): "on <glyph> <branch>" (or "<glyph> @<sha>" detached),
# then the optional worktree tag and the non-zero count clusters — the shared
# symbol/colour/order vocabulary (!conflict +staged ~modified ?untracked).
# Needs the statusline_git_state globals; $1 is the worktree label (may be "").
statusline_git_segment() {
  local worktree=${1:-} seg="" label=""
  [ -z "$TOP" ] && return
  if [ -n "$BRANCH" ]; then
    label="$BRANCH"
  elif [ -n "$HEAD_REF" ]; then
    label="@${HEAD_REF}"
  fi
  [ -z "$label" ] && return
  # On a branch: DIM "on" + TEAL glyph+name. Detached HEAD drops the "on" —
  # "on @sha" reads oddly.
  if [ -n "$BRANCH" ]; then
    seg=" ${DIM}on${RST} ${TEAL}${BRANCH_GLYPH} ${label}${RST}"
  else
    seg=" ${TEAL}${BRANCH_GLYPH} ${label}${RST}"
  fi
  [ -n "$worktree" ] && seg+=" ${DIM}(${worktree})${RST}"
  [ "$CONFLICT" -gt 0 ] && seg+=" ${RED}!${CONFLICT}${RST}"
  [ "$STAGED" -gt 0 ] && seg+=" ${GREEN}+${STAGED}${RST}"
  [ "$MODIFIED" -gt 0 ] && seg+=" ${YELLOW}~${MODIFIED}${RST}"
  [ "$UNTRACKED" -gt 0 ] && seg+=" ${ORANGE}?${UNTRACKED}${RST}"
  printf '%s' "$seg"
}

# Context-window cluster (echoes) "<pct>% <bar>" with a 10-cell █/░ bar and a
# threshold colour (GREEN <60, YELLOW <80, RED ≥80). $1 is the raw percentage.
statusline_context_cluster() {
  local pct=${1%%.*} bc f e bar="" i
  case "$pct" in
  '' | *[!0-9]*) pct=0 ;;
  esac
  [ "$pct" -lt 0 ] && pct=0
  [ "$pct" -gt 100 ] && pct=100
  if [ "$pct" -ge 80 ]; then
    bc="$RED"
  elif [ "$pct" -ge 60 ]; then
    bc="$YELLOW"
  else
    bc="$GREEN"
  fi
  f=$((pct / 10))
  e=$((10 - f))
  for ((i = 0; i < f; i++)); do bar+="█"; done
  for ((i = 0; i < e; i++)); do bar+="░"; done
  printf '%s%% %s%s%s' "$pct" "$bc" "$bar" "$RST"
}

# Nix-shell metadata segment (echoes) — `(❄️)` after the cwd when inside a nix
# shell. $IN_NIX_SHELL is set by nix-direnv and inherited into the subprocess.
statusline_nix_shell_segment() {
  [ -n "${IN_NIX_SHELL:-}" ] && printf ' (%s%s%s)' "$BLUE" "$NIX_GLYPH" "$RST"
}

# Line-2 left cluster (echoes): host marker, then (in a repo/dir) the cwd with
# nix-shell metadata and the git segment. Needs statusline_host_marker to have
# set HOST_GLYPH/HOST_COLOUR. Args: <hostname> <short-cwd> <git-seg>.
statusline_line2_left() {
  local hostname=$1 short_cwd=$2 git_seg=$3 out
  out="${HOST_COLOUR}${HOST_GLYPH}  ${hostname}${RST}"
  [ -n "$short_cwd" ] && out+="${CHEV}${BLUE}${short_cwd}${RST}$(statusline_nix_shell_segment)${git_seg}"
  printf '%s' "$out"
}
