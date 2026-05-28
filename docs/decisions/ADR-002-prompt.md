# ADR-002: Prompt — starship

**Date**: 2026-05-06
**Status**: Accepted

## Context

A shell prompt is the persistent visual context for every command — "where am
I, what state is the working tree in, did the last command succeed". Fish's
default prompt is functional (user, host, cwd, git branch) but doesn't
indicate when you're inside a `nix develop` shell. On a nix dev box where
direnv automatically activates per-project flakes, knowing your current
environment matters: it's the difference between "this `cargo` is the
project's pinned version" and "this `cargo` is whatever was on PATH".

## Decision

The prompt is **starship**, configured via `programs.starship` in
home-manager with a deliberately minimal TOML config declared inline as a
nix attrset. The nix-shell module is enabled to surface direnv-activated
environments visually.

## Rationale

Three options were on the table:

1. **Pure fish default.** Zero new packages, no config. Drawback: no
   nix-shell indicator. nix-direnv prints an entry/exit banner so the change
   isn't invisible, but the prompt doesn't *persistently* tell you which env
   you're in. Workable when juggling one project; less so once you have
   several.
2. **Tiny fish prompt tweak.** Override `fish_prompt` with ~10 lines of fish
   that adds an `❄️` indicator when `$IN_NIX_SHELL` is set. Zero new
   packages; bespoke code we own. Cheaper than starship at the dependency
   level but more dependent on us understanding fish's prompt machinery to
   maintain.
3. **starship.** One new package, declarative TOML config, gives us
   nix-shell, exit-code, command-duration, richer git status, language
   versions — all configurable as toggleable modules.

The deciding factor was the nix-shell indicator. Once direnv + nix-direnv
are in play (ADR-003), persistent visual confirmation of the current
environment becomes load-bearing, not cosmetic.

Between option 2 (cheap but bespoke) and option 3 (one package but
declarative): the dependency cost of starship is a single well-maintained
Rust binary, and the TOML config in nix matches the declarative aesthetic of
the rest of the repo better than fish-prompt-functions-in-nix. Starship also
provides several other useful modules (exit code, command duration) that the
user is likely to grow into without effort.

The initial proposal had been to defer starship and pick it up later; the
nix-shell-indicator argument flipped the call. Recorded in the ADR's history
as a worked example of a recommendation reversing on closer examination.

## Consequences

- ✓ Persistent nix-shell indicator visible in every shell line.
- ✓ Declarative TOML config inline in nix — same aesthetic as the rest of
  the repo.
- ✓ Cross-shell: if fish is ever swapped for zsh later, starship config
  carries forward unchanged.
- ✓ Headroom for additional modules (exit code, command duration, language
  versions) when wanted, by toggling them on.
- ✗ One additional dependency vs. fish's default prompt. (Small — single
  Rust binary, ~5 MB.)
- ⚠ Migration trigger: if the user wants a markedly more minimal prompt than
  starship's default + custom format string can provide, the bespoke fish
  prompt option (~10 lines) is the fallback. Removing starship is one line.

## Implementation

Configured in `home/core/shared/prompt.nix` via `programs.starship`. Settings
declared inline as a nix attrset (`programs.starship.settings`), not in a
separate TOML file. Initial minimal shape:

```toml
format = "$directory$git_branch$git_status$nix_shell$character"
add_newline = false

[nix_shell]
format = "[$symbol$name]($style) "
symbol = "❄️ "
```

This produces a single-line prompt with directory, git state, nix-shell
indicator, and the prompt character — nothing else. Other starship modules
(time, hostname, language versions, etc.) stay off by default. Add only when
the user expresses a concrete want.

Fish hook is auto-wired by `programs.starship.enable`. No manual init line
needed.

## History

### Host segment added (2026-05-28, ADR-028 cluster)

The "add modules only when the user expresses a concrete want" stance held
until the three-host fleet went live (nixos-vm, mercury, metis) and ADR-028
put metis on track to become a physical desktop. "Which host am I on, and
am I local or remote?" became a concrete operational question — exactly the
trigger the original ADR anticipated.

Resolved by a leading host segment in `prompt.nix`: two mutually-exclusive
`custom.host_local` / `custom.host_ssh` modules gated on `$SSH_CONNECTION`.
Hostname always shown; the glyph differs — `U+F108` (nf-fa-desktop) when
local, `U+F489` (nf-mdi-console_network) over SSH. Closes GH #17 and
subsumes slice 1 of GH #6.

The built-in `hostname` module was considered (with `ssh_only = true`) but
can only *prepend* a fixed SSH symbol — it cannot swap glyphs by SSH state.
Two custom modules + `when` shell tests was the only structural way to get
the swap.

**Always-on rationale (vs Pure/Starship/Powerlevel10k's `ssh_only`
convention).** The field default suppresses user@host locally and
surfaces it only on SSH — *absence* is the local signal. We deliberately
diverge and render the host segment unconditionally. The operator runs
many concurrent terminal panes across multiple devices: 5–10 panes open
at once, some local on different desktops, some SSH'd to different
remote hosts, switched between via window/tab focus. The "where am I"
question isn't sequential ("which host did I last `cd` into?") but
parallel ("which of these visible panes is mercury, which is nixos-vm,
which is the laptop?"). Absence-is-local breaks when you have multiple
locals — *which* is the load-bearing question, not *whether*. The
chrome cost (~12 chars permanently at the leftmost position of every
prompt) is the price of disambiguation under that workload.

**Style.** Host segment is coloured by SSH state — `green` (base0B) when
local, `purple` (base0E) when SSH'd. Chevron separator stays outside
the style markup (default foreground) so the host reads as a chip
against the bare separator. See PR #41 commit history for the
colour-collision investigation that led here (untracked counter moved
to `orange`/base09 so the SSH host marker is the only purple on
line 2).

**Known limitation — zellij detach/reattach.** `$SSH_CONNECTION` is set
by sshd on login and inherited into long-lived processes (including
zellij sessions). A zellij pane started under SSH retains the SSH glyph
even after detach + local reattach. Accepted as a low-impact edge case;
the visible signal is "this pane was opened under SSH", which is still
useful context.

### `(…)`-as-metadata convention (2026-05-28)

Anything wrapped in parentheses on the prompt-or-statusline line is
**contextual metadata about the immediately-preceding segment**. The
convention spans both surfaces:

| Wrapping | Surface(s) | Position | Meaning |
|---|---|---|---|
| `(❄️)` | prompt + statusline | after the cwd | this directory has a nix-shell active |
| `(worktree-name)` | statusline only | after the branch | currently on the named git worktree |

(`(worktree)` doesn't appear on the prompt because starship has no
worktree module wired; the statusline implements it directly. The
*convention* applies to both; only the worktree *use* is statusline-
only.)

Both consume their preceding segment's scope: `nix-config (❄️)` reads
as "the nix-config directory, with nix-shell active"; `main (adr-029)`
reads as "the main branch, on worktree adr-029".

**Test for new uses** — a signal qualifies as `(…)`-metadata only if
it describes a *property of the preceding segment's state*, not just
something that visually relates to it:

- ✓ Property — wrap. `(read-only)` is a property of the directory.
  `(detached)` is a property of the branch state.
- ✗ Related-but-separate — don't wrap; render as its own segment.
  Upstream ahead/behind counts (`⇡1 ⇣2`) are about the branch's
  relationship with a *remote*, not the branch's own state.
  Language version indicators (Python `3.12`, Node `22`) are about
  the directory's *environment*, not the directory itself.

The test boils down to: if you wouldn't naturally say "the X is Y"
about the preceding segment, it's a separate segment, not metadata.

Implementation: nix-shell renders via `programs.starship.settings.nix_shell`
positioned between `$directory` and `$git_branch` in the format string,
with `format = "\([$symbol]($style)\) "` — parens are escaped (`\(`
`\)`) because starship treats unescaped `(...)` as a "render-if-non-
empty" conditional group, not literal parens. Only the snowflake picks
up `$style`; the parens render in default foreground. The statusline
mirrors this via a conditional `(❄️)` segment inserted between the
path and the git block in `claude-statusline.sh`.
