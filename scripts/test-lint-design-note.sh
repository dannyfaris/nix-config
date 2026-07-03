#!/usr/bin/env bash
# Smoke-test for scripts/lint-design-note.sh: a well-formed note (with and
# without the optional Cost section) must pass; every structural defect the
# linter exists to catch — missing section, wrong order, empty body, an
# unfilled template prompt, a missing Status header, a stray heading — must
# be flagged. The README/_template skip is asserted too, since a regression
# there would either lint the all-prompts template (false fail) or, worse,
# stop linting real notes.
#
# Wired via parts/checks.nix as `test-design-note-structure`, gated on edits
# to lint-design-note.sh; runs in `nix flake check`/CI and at commit-time
# when the linter changes. Also runnable standalone:
#   bash scripts/test-lint-design-note.sh
#
# Mirrors test-lint-shared-purity.sh (#193): a linter that gates a guarantee
# needs its own negative-path coverage, or a change that quietly made it
# pass everything would evaporate the guarantee unnoticed (ADR-032).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LINT="${LINT_SCRIPT:-$SCRIPT_DIR/lint-design-note.sh}"
[[ -r $LINT ]] || {
  echo "ERROR: $LINT not found or not readable" >&2
  exit 2
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failures=0

# The nine required sections, in order, each with real one-line bodies.
valid_note() {
  cat <<'EOF'
# A title

**Status:** Proposed — design note. Not yet built.

## Summary
Real summary prose.

## Motivation
The problem, and the forces.

## Design
The mechanism.

## De-risk evidence
What was verified.

## Drawbacks
Reasons against.

## Rationale & alternatives
Why this beats the options.

## Prior art
What others did.

## Unresolved questions
Open items.

## Future possibilities
Later ideas.
EOF
}

# check <pass|fail> <label> <file> — assert the linter's verdict on a file.
check() {
  local expect=$1 label=$2 f=$3 got
  if bash "$LINT" "$f" >/dev/null 2>&1; then got=pass; else got=fail; fi
  if [[ $got == "$expect" ]]; then
    echo "OK   $expect: $label"
  else
    echo "FAIL want=$expect got=$got: $label" >&2
    failures=$((failures + 1))
  fi
}

# A sibling _template.md beside the fixtures: the linter reads it as the
# prompt source for the "left unfilled" check, and (named _template.md) it is
# itself skipped by basename — both behaviours exercised by one file.
PROMPT_LINE='*One paragraph: what this proposes, before any why.*'
printf '# Template\n\n## Summary\n%s\n' "$PROMPT_LINE" >"$tmp/_template.md"
printf 'not a note\n' >"$tmp/README.md"

# Positive: a clean, template-shaped note.
valid_note >"$tmp/valid.md"
check pass "well-formed note" "$tmp/valid.md"

# Positive: optional Cost section present (between Drawbacks and Rationale).
sed 's/^## Rationale & alternatives$/## Cost\nA standing price.\n\n## Rationale \& alternatives/' \
  "$tmp/valid.md" >"$tmp/cost.md"
check pass "Cost section present (optional)" "$tmp/cost.md"

# Positive: _template.md and README.md are skipped by basename.
check pass "_template.md skipped" "$tmp/_template.md"
check pass "README.md skipped" "$tmp/README.md"

# Negative: a required section dropped.
grep -v '^## Prior art$' "$tmp/valid.md" | grep -v '^What others did\.$' >"$tmp/missing.md"
check fail "missing a required section" "$tmp/missing.md"

# Negative: two sections swapped out of order (Summary and Motivation).
{
  printf '# T\n\n**Status:** Proposed.\n\n'
  printf '## Motivation\nx\n\n## Summary\nx\n\n'
  printf '## Design\nx\n\n## De-risk evidence\nx\n\n## Drawbacks\nx\n\n'
  printf '## Rationale & alternatives\nx\n\n## Prior art\nx\n\n'
  printf '## Unresolved questions\nx\n\n## Future possibilities\nx\n'
} >"$tmp/disordered.md"
check fail "sections out of order" "$tmp/disordered.md"

# Negative: a section left empty.
{
  printf '# T\n\n**Status:** Proposed.\n\n'
  printf '## Summary\n\n## Motivation\nx\n\n## Design\nx\n\n'
  printf '## De-risk evidence\nx\n\n## Drawbacks\nx\n\n'
  printf '## Rationale & alternatives\nx\n\n## Prior art\nx\n\n'
  printf '## Unresolved questions\nx\n\n## Future possibilities\nx\n'
} >"$tmp/empty.md"
check fail "empty section body" "$tmp/empty.md"

# Negative: a section still holding its verbatim template prompt — matched
# against the sibling _template.md, not "any italic line".
sed "s|^Real summary prose\.\$|$PROMPT_LINE|" "$tmp/valid.md" >"$tmp/prompt.md"
check fail "unfilled template prompt" "$tmp/prompt.md"

# Positive: a single-line *italic* body that is NOT a template prompt. Real
# authored prose must not be mistaken for an unfilled prompt — the false
# positive the literal-match fix removes.
sed "s|^Real summary prose\.\$|*A deliberately italic one-line summary — real content.*|" \
  "$tmp/valid.md" >"$tmp/italicok.md"
check pass "single italic line that isn't a template prompt" "$tmp/italicok.md"

# Negative: no Status header.
grep -v '^\*\*Status:\*\*' "$tmp/valid.md" >"$tmp/nostatus.md"
check fail "missing Status header" "$tmp/nostatus.md"

# Negative: a stray (non-template) H2 heading.
sed '/^## Future possibilities$/i ## Appendix\nstray\n' "$tmp/valid.md" >"$tmp/stray.md"
check fail "stray non-template heading" "$tmp/stray.md"

# Positive: a fenced code block containing a `## ` line must NOT be read as a
# heading (the fence-awareness fix). Without it the fenced "##" reads as a
# stray/duplicate heading and a legitimate note false-fails. Quoted heredoc
# keeps the fence literal.
cat >"$tmp/fenced.md" <<'EOF'
# T

**Status:** Proposed.

## Summary
x

## Motivation
x

## Design
Example config:

```
## Motivation
key = value
```

## De-risk evidence
x

## Drawbacks
x

## Rationale & alternatives
x

## Prior art
x

## Unresolved questions
x

## Future possibilities
x
EOF
check pass "fenced code block with ## inside" "$tmp/fenced.md"

# Positive: a tilde-fenced (~~~) block with a `## ` line — same fence-skip as
# ```, the natural fence when the sample itself contains backticks.
cat >"$tmp/tilde.md" <<'EOF'
# T

**Status:** Proposed.

## Summary
x

## Motivation
x

## Design
Example:

~~~
## Motivation
code
~~~

## De-risk evidence
x

## Drawbacks
x

## Rationale & alternatives
x

## Prior art
x

## Unresolved questions
x

## Future possibilities
x
EOF
check pass "tilde-fenced block with ## inside" "$tmp/tilde.md"

# Positive: with no sibling _template.md, the unfilled-prompt check skips
# gracefully — a single-line italic body passes (nothing to match against).
mkdir -p "$tmp/notpl"
sed "s|^Real summary prose\.\$|*An italic one-liner, no template beside it.*|" \
  "$tmp/valid.md" >"$tmp/notpl/note.md"
check pass "no sibling template — prompt check skipped" "$tmp/notpl/note.md"

echo
if ((failures > 0)); then
  echo "$failures test(s) failed." >&2
  exit 1
fi
echo "All design-note structure lint tests passed."
