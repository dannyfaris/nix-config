# ADR-012: Module taxonomy — most-communicative term

**Date**: 2026-05-06
**Status**: Accepted

## Context

`modules/home/` and `modules/system/` are decomposed into multiple thematic
files (one concern per file). The naming convention applied to those files
is itself a load-bearing decision — a reader's first interaction with the
codebase is the file tree.

Three positions were on the table:

1. **All-role naming**: every file named after the role it fills (e.g.,
   `shell.nix`, `prompt.nix`, `editor.nix`, `secure-shell.nix`,
   `version-control.nix`, `project-envs.nix`).
2. **All-tool naming**: every file named after its primary tool (e.g.,
   `fish.nix`, `starship.nix`, `helix.nix`, `ssh.nix`, `git.nix`,
   `direnv.nix`).
3. **Mixed**: case-by-case, picking whichever name reads best.

This ADR captures the meta-decision: **what naming rule should apply across
the codebase?**

## Decision

**Name each file by whichever term is most communicative to a reader.**

In practice this resolves to one of three sources:

- **Role names** when the role is more universally recognised than any one
  implementing tool (e.g., `shell.nix`, `prompt.nix`, `multiplexer.nix`,
  `editor.nix`).
- **Tool/protocol names** when the tool's name *is* its role (e.g.,
  `git.nix`, `ssh.nix`, `direnv.nix`).
- **Collective category names** when a file groups multiple tools serving
  one role with no umbrella tool (e.g., `cli-utils.nix`, `nix-tooling.nix`,
  `agent-clis.nix`).

The applied principle and worked examples live in
[`docs/taxonomy.md`](../taxonomy.md). This ADR records the decision itself.

## Rationale

The "all-role" position was attractive on grounds of formal consistency
(one rule, applied uniformly), and was the initial preferred direction.
It produced names like `secure-shell.nix` (for SSH) and `project-envs.nix`
(for direnv) that, on closer examination, were *less* communicative than
the tool names they replaced. `secure-shell.nix` reads ambiguously — could
mean "the SSH protocol" or "tools used during a remote shell session".
`project-envs.nix` is an invented term, less recognised than "direnv".

The "all-tool" position was symmetrical: name everything after the tool.
But it's not even achievable — collective files like `cli-utils.nix`
contain ten parallel tools with no umbrella tool to name them after.
Picking one (e.g., `ripgrep.nix`) would be misleading; any truthful name
would be a category name.

The mixed approach, framed as a single criterion ("most-communicative
term"), turned out to be the cleanest answer. It's a single rule
(consistency at the rule level), but it produces three name shapes
(diversity at the application level). The diversity is honest about the
fact that some concepts have stronger role-names, some have stronger
tool-names, and some need category names.

The rule's value is best tested by reading the tree: every filename answers
the same kind of question to a reader, namely "what does this file
configure?" — using whichever vocabulary is most direct for that
particular subject.

## Consequences

- ✓ Reading the tree is fast: each name is the most direct vocabulary for
  what it configures.
- ✓ Single rule is easy to remember and apply consistently to new modules.
- ✓ Doesn't force role-naming into places where it adds ambiguity (SSH,
  git, direnv) or tool-naming into places where there's no umbrella tool
  (collective files).
- ✗ Inconsistent at the surface level — some files are role-named, some
  tool-named, some category-named. Worth living with because the
  "consistency" of an all-role or all-tool rule produced strictly worse
  names in places.
- ⚠ Migration trigger: if the user later prefers strict consistency
  (e.g., for a future configuration generator that pattern-matches on
  filenames), the all-role or all-tool position remains adoptable as a
  full-tree refactor. Cost is non-trivial but bounded.

## Implementation

Applied across:

- `modules/home/{shell, prompt, multiplexer, editor, direnv, git, ssh,
  cli-utils, nix-tooling, agent-clis}.nix` plus `default.nix`.
- `modules/system/{boot, networking, locale, nix, ssh, sops, users,
  packages, mosh}.nix` plus `default.nix`.

The rule's primary surface is `docs/taxonomy.md`, which is what a reader
or editor of the codebase consults when deciding what to name a new file.
This ADR is the formal decision record; the prose document is the working
guide.

When adding a new module file in the future:

1. Identify what concern it serves.
2. Try the role-name. If the role name is universally recognised AND more
   communicative than the tool name, use it.
3. If the role name is invented or ambiguous, use the tool/protocol name.
4. If the file aggregates multiple tools with no umbrella, use a
   collective category name.
5. Update `docs/taxonomy.md` if the new name introduces a new pattern not
   already documented.
