<!--
PR conventions — see docs/workflow.md:
https://github.com/dannyfaris/nix-config/blob/main/docs/workflow.md
After `gh pr create`, enable squash auto-merge:
  gh pr merge <num> --auto --squash
(docs/workflow.md §"PRs land via squash auto-merge")
-->

## Summary

<!-- What this PR does and why. -->

## Driving issue

<!-- Use "Closes #N" so the merge closes the issue; add a "Depends on #N" line for any unmet dependency. -->

Closes #

## Checklist

- [ ] Staged diff peer-reviewed by an independent reviewer before commit (docs/workflow.md §"Peer-review staged diffs before commit").
- [ ] For selections: rationale doc landed before the implementing commit (doc-before-code cadence).
- [ ] Pre-commit gate passed (`nix build .#checks.<system>.pre-commit`).
- [ ] New and amended markdown authored soft-wrapped (#266).
