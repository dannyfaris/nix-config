# Taxonomy: how files and modules are named

This document captures the naming convention applied across the
home-manager module tree (`home/core/nixos/`) and the system module
tree (`modules/core/nixos/`), and by extension any future module
trees. The decision itself is recorded in
[ADR-012](./decisions/ADR-012-taxonomy.md); this document is the
applied principle with examples.

> **Note:** the historical examples below reference the pre-refactor
> directories `modules/home/` and `modules/system/` because the rule
> was articulated against that tree. The current tree is
> `home/core/nixos/` and `modules/core/nixos/` per the PRD §5 role/host
> layout (introduced post-ADR-013 through ADR-016). The naming rule
> itself applies unchanged; only the directories moved.

## The rule

**Name each file by whichever term is most communicative to a reader.**

That's the whole rule. Everything below is its application.

In practice, "most communicative" resolves to one of three name sources:

1. **Role-based names** when the role is a more universally recognised term
   than any one implementing tool.
2. **Tool/protocol names** when the tool's name *is* its role — the tool is
   the universally recognised term and abstracting away from it adds
   ambiguity rather than clarity.
3. **Collective category names** when a file groups multiple tools serving
   one role and there's no obvious single-tool umbrella.

## Examples and reasoning

### `modules/home/` (role-based)

| File | Why role-based |
|------|----------------|
| `shell.nix` | "Shell" is more universal than "fish". A reader knows what a shell is without needing to know which one. |
| `prompt.nix` | "Prompt" is the role; starship is one implementation. |
| `multiplexer.nix` | "Multiplexer" is the role; zellij is one implementation. |
| `editor.nix` | "Editor" is the role; helix is one implementation. |

### `modules/home/` (tool/protocol-named)

| File | Why tool-named |
|------|----------------|
| `git.nix` | "Git" is the universally recognised term — calling it `version-control.nix` would be more abstract but no clearer to any reader. The file contains git + gh + glab, but git is unambiguously the umbrella. |
| `ssh.nix` | "SSH" is short for "Secure Shell Protocol" — the acronym IS the role. Calling it `secure-shell.nix` is the same name, longhand. Calling it `remote-shell.nix` introduces ambiguity (could mean SSH-the-tool or remote-shell-as-a-context). |
| `direnv.nix` | "direnv" is the recognised term in nix circles. "project-envs" was considered but is less communicative than the actual tool name. |

### `modules/home/` (collective category)

| File | What it contains |
|------|------------------|
| `cli-utils.nix` | rg, fd, fzf, bat, eza, zoxide, lazygit, yazi, htop, dust — modern Unix replacements. No single tool is the umbrella; the category is. |
| `nix-tooling.nix` | nh, nom, nixd, nixfmt, statix, deadnix — six tools improving the nix dev experience. Same pattern. |
| `agent-clis.nix` | Claude Code + Cursor CLI — the always-on base. Codex + Gemini CLI live in the sibling `agent-clis-extras.nix`, imported per-host (ADR-008, ADR-020). |

### `modules/system/` (mixed, all communicative)

| File | Naming class |
|------|--------------|
| `boot.nix`, `networking.nix`, `locale.nix` | Role names — these are universal terms for what they configure. |
| `nix.nix` | Tool name — "nix" is the universally recognised term for nix daemon settings. |
| `ssh.nix` | Protocol acronym (same reasoning as in `modules/home/`). |
| `sops.nix`, `mosh.nix` | Tool names. |
| `users.nix`, `packages.nix` | Role/category names. |

## Rejected alternatives

### "All-role with forced names"

This was the first proposal: rename everything to a role name, even where the
role name was wordier than the tool name (e.g., `secure-shell.nix` for SSH,
`project-envs.nix` for direnv, `version-control.nix` for git).

**Why rejected.** Some of these names were genuinely more confusing than
their tool-name alternatives. `secure-shell.nix` reads as a context (a
collection of tools used during remote shell sessions) rather than a role (the
SSH protocol itself). `project-envs.nix` is an invented term, less recognised
than "direnv". The pursuit of consistency-for-its-own-sake produced names that
were strictly worse on the criterion that actually matters: how fast a reader
parses the name into understanding.

### "All-tool with no abstractions"

Mirror image of the above: name every file after its primary tool —
`fish.nix`, `starship.nix`, `zellij.nix`, etc.

**Why rejected.** The collective category files (`cli-utils.nix`,
`nix-tooling.nix`, `agent-clis.nix`) genuinely contain multiple parallel
tools with no umbrella tool to name them after. Picking one (e.g., naming
the cli-utils file `ripgrep.nix`) would be misleading; any name that
truthfully described the file's content would be a category name. So strict
all-tool naming isn't even achievable.

### "Decompose by lifecycle / frequency of change"

Considered: name files by how often they change (`stable.nix`, `volatile.nix`).

**Why rejected.** Lifecycle is not a meaningful axis to a reader who is trying
to find a specific configuration. Knowing that a file is stable doesn't help
you find shell configuration in it.

## What this gives us

- A reader can predict where any configuration lives without consulting an
  index.
- The tree reads as a clear taxonomy without forcing any single naming
  convention to do work it isn't suited for.
- Tool swaps are cheap (rename a file body, not a path) where the role name
  has been chosen well; they're a single-file content change otherwise.
- Inconsistency-as-honesty: the rule is a single sentence, but it produces
  three name shapes, and that's the right answer.
