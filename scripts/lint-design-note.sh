#!/usr/bin/env bash
# Structure lint for design notes (docs/design/<slug>.md).
#
# Wired into the pre-commit framework via parts/checks.nix; the framework
# filters tracked files through the configured `files` regex
# (^docs/design/.*\.md$) and passes the matches as positional args. The
# category README and the _template.md are skipped by basename — neither is
# a design note (the template is all-prompts by construction).
#
# This is the *audit* rung of the design loop's enforcement ladder
# (docs/design/design-loop.md): it gates the structural PRESENCE of the
# discipline — that a note carries the template's sections, in order, and
# that none was copied-but-left-unfilled. It deliberately does NOT judge
# QUALITY (is the Motivation actually intent-first? are the alternatives
# genuinely weighed?) — that is a judgment call whose strongest mechanisable
# rung is peer review, not a grep. Keeping the lint to presence-only is what
# keeps it out of the brittleness trap (ADR-032: the lightest mechanism that
# holds the guarantee).
#
# A note derived from _template.md passes by construction; the lint fires
# when a required section is dropped, reordered, left empty, or left as its
# template prompt. Committing a deliberately partial draft mid-design is a
# legitimate use of the escape hatch:
#   git commit --no-verify
#
# Pure bash builtins + grep — no Nix, no awk; the git-hooks.nix `run`
# derivation scrubs PATH, so we lean only on the always-present base. Relies
# on bash-4 builtins (mapfile, ${,,}); the hook invokes `bash` explicitly, so
# that is guaranteed. ATX `##` headings only — setext (underline) headings
# are not recognised, by design (the template is ATX); `## ` lines inside
# fenced ``` or ~~~ blocks are skipped, so code samples don't read as sections.
# See ADR-025 for this framework, ADR-032 for the proportionality stance.

set -euo pipefail

# Canonical required H2 sections, in template order. "Cost" is intentionally
# absent: it is the one optional section (see _template.md), allowed wherever
# it appears but never required.
REQUIRED=(
  "summary"
  "motivation"
  "design"
  "de-risk evidence"
  "drawbacks"
  "rationale & alternatives"
  "prior art"
  "unresolved questions"
  "future possibilities"
)

# Normalise an H2 line to a comparison key: drop the leading `##`, strip a
# trailing markdown-emphasis annotation (e.g. "Cost  *(optional)*"), trim,
# lowercase. Section names contain no `*`, so cutting at the first `*` only
# ever removes an annotation.
normalize() {
  local h="$1"
  h="${h#\#\#}"                  # drop leading ##
  h="${h%%\**}"                  # drop trailing *...* annotation, if any
  h="${h#"${h%%[![:space:]]*}"}" # ltrim
  h="${h%"${h##*[![:space:]]}"}" # rtrim
  printf '%s' "${h,,}"
}

# Lint one file. Appends human-readable problems to the global `errs` array.
lint_file() {
  local file="$1"
  local -a lines=() hnorm=() hidx=()

  if ! grep -qE '^\*\*Status:\*\*' "$file"; then
    errs+=("$file: missing the '**Status:**' header line")
  fi

  mapfile -t lines <"$file"
  local i line in_fence=0
  local fence_re='^[[:space:]]*(```|~~~)' # ``` or ~~~ fence; single-quoted keeps backticks literal
  for i in "${!lines[@]}"; do
    line="${lines[$i]}"
    if [[ $line =~ $fence_re ]]; then
      in_fence=$((1 - in_fence))
      continue
    fi
    [[ $in_fence -eq 1 ]] && continue # `## ` inside a fence is code, not a section
    if [[ $line =~ ^##[[:space:]] ]]; then
      hnorm+=("$(normalize "$line")")
      hidx+=("$i")
    fi
  done

  # Template prompts, for the "left unfilled" check: the italic prompt lines
  # from the sibling _template.md. Matching the *literal* prompt text — not
  # "any italic line" — means an author's own one-line italic prose never
  # false-fails. If the template isn't beside the note, the check is skipped.
  # (The `*…*` capture is deliberately broad; a flag still requires the body
  # to equal a captured line verbatim, so over-capture is harmless.)
  local -a prompts=()
  local tpl pline
  tpl="$(dirname "$file")/_template.md"
  if [[ -r $tpl ]]; then
    while IFS= read -r pline; do
      [[ $pline =~ ^[[:space:]]*\*.*\*[[:space:]]*$ ]] || continue
      pline="${pline#"${pline%%[![:space:]]*}"}"
      pline="${pline%"${pline##*[![:space:]]}"}"
      prompts+=("$pline")
    done <"$tpl"
  fi

  # Presence + order: the observed required-section sequence (Cost filtered
  # out) must equal REQUIRED exactly, in order. Stray headings are reported
  # rather than silently shifting the comparison.
  local -a observed=()
  local h known r
  for h in "${hnorm[@]}"; do
    [[ $h == "cost" ]] && continue
    known=0
    for r in "${REQUIRED[@]}"; do [[ $h == "$r" ]] && known=1 && break; done
    if [[ $known -eq 1 ]]; then
      observed+=("$h")
    else
      errs+=("$file: unexpected section heading '## $h' (not a template section)")
    fi
  done
  if [[ ${observed[*]} != "${REQUIRED[*]}" ]]; then
    errs+=("$file: required sections missing or out of order")
    errs+=("    found:    ${observed[*]:-(none)}")
    errs+=("    expected: ${REQUIRED[*]}")
  fi

  # Non-empty / not-left-as-prompt: each required section's body (up to the
  # next H2) must have real content — not zero lines, and not a single
  # italic-wrapped template prompt.
  local n=${#hidx[@]} j start end k body_count sole req r2 bline
  for ((j = 0; j < n; j++)); do
    h="${hnorm[$j]}"
    req=0
    for r2 in "${REQUIRED[@]}"; do [[ $h == "$r2" ]] && req=1 && break; done
    [[ $req -eq 1 ]] || continue

    start=$((hidx[j] + 1))
    if [[ $((j + 1)) -lt $n ]]; then end=$((hidx[j + 1] - 1)); else end=$((${#lines[@]} - 1)); fi

    body_count=0
    sole=""
    for ((k = start; k <= end; k++)); do
      bline="${lines[$k]}"
      [[ -z ${bline//[[:space:]]/} ]] && continue
      body_count=$((body_count + 1))
      sole="$bline"
    done

    if [[ $body_count -eq 0 ]]; then
      errs+=("$file: section '## $h' is empty")
    elif [[ $body_count -eq 1 ]]; then
      # Single-line body: flag only if it is verbatim a template prompt.
      local strim p
      strim="${sole#"${sole%%[![:space:]]*}"}"
      strim="${strim%"${strim##*[![:space:]]}"}"
      for p in ${prompts[@]+"${prompts[@]}"}; do
        if [[ $strim == "$p" ]]; then
          errs+=("$file: section '## $h' still holds its template prompt (unfilled)")
          break
        fi
      done
    fi
  done
}

errs=()
for file in "$@"; do
  case "$(basename "$file")" in
  README.md | _template.md) continue ;; # not design notes
  esac
  lint_file "$file"
done

if [[ ${#errs[@]} -gt 0 ]]; then
  echo "ERROR: design note structure check failed:" >&2
  printf '  %s\n' "${errs[@]}" >&2
  echo >&2
  echo "The template (docs/design/_template.md) yields a passing skeleton." >&2
  echo "Committing a partial draft mid-design: git commit --no-verify" >&2
  exit 1
fi
exit 0
