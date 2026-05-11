# ADR-006: CLI utilities — modern Unix replacements set

**Date**: 2026-05-06
**Status**: Accepted

## Context

Standard Unix tools (`grep`, `find`, `cat`, `ls`, `cd`, `du`, etc.) are
40+ years old. They work, but on modern hardware and modern repos they
are slow, default-noisy, and lack things modern tooling takes for granted
(colour, git-awareness, sensible ignores, structured output). A small set
of Rust/Go rewrites have become the de facto modern stack across most nix
configs.

The decision isn't *which* of these tools to use — most coexist with
their classic counterparts and serve different purposes. It's *which set*
to install by default in home-manager.

## Decision

Ten tools are installed at the home-manager level, available everywhere on
this user's account:

- **ripgrep** (`rg`) — replaces `grep`
- **fd** — replaces `find`
- **fzf** — fuzzy finder (history search, file picker)
- **bat** — replaces `cat` for *viewing* (cat still used for piping)
- **eza** — replaces `ls`
- **zoxide** — partial replacement for `cd` (fuzzy-jump-by-name)
- **lazygit** — TUI git client
- **yazi** — TUI file manager
- **htop** — process / system monitor
- **dust** — replaces `du` with visual disk usage tree

A second tier of tools is **deliberately deferred** rather than installed
pre-emptively:

- **delta** (better git diff pager) — defer until first wanted.
- **jq** (JSON tool) — defer until first JSON workflow.

A third tier is **deliberately skipped**, with reasons recorded so the
decision isn't relitigated unintentionally:

- `atuin` / `mcfly` — fancy shell history. fzf's Ctrl-R is sufficient on
  one machine. Reconsider when multi-machine sync matters (the user adds
  the x86_64 desktop in Tier 5).
- `broot` / `nnn` — other TUI file managers. yazi covers the need.
- `tldr` — concise man-page summaries. Replaceable by Claude Code in
  another zellij pane.
- `glow` — markdown renderer. `bat README.md` covers most cases.
- `procs` — `ps` replacement. htop covers most "what's running" needs.
- `duf` — `df` replacement. Less compelling than dust.

## Rationale

The ten locked-in tools each earn their place by daily use:

- **ripgrep + fd + fzf** form the modern search/navigation triad. Used
  several times an hour in any serious dev workflow.
- **bat** provides syntax-highlighted file viewing without the user having
  to remember which paginator/viewer to invoke.
- **eza** with git status (`eza -l --git`) replaces a chain of
  `ls` + `git status` for "what's in this dir, what's modified".
- **zoxide** quietly removes the need to type long paths once a directory
  has been visited.
- **lazygit** is the TUI git client; given helix has no built-in git
  plugin (ADR-005), running lazygit in a separate zellij pane is the
  canonical pattern.
- **yazi** is the visual file manager. It earned its place specifically
  by serving job-of-file-manipulation that helix's file picker can't:
  exploring unfamiliar directories, batch operations with visual
  confirmation, image previews via the kitty graphics protocol. The
  initial proposal had been to skip yazi; pushback on that exclusion led
  to a re-examination and confirmed yazi serves a distinct role.
- **htop** answers "what's eating CPU/RAM?" — the only way to see that on
  a headless box. Cheap, invisible until needed.
- **dust** answers "where did my disk go?" — same pattern as htop.

The deferred tier (delta, jq) is held for two reasons: each is genuinely
useful but only sometimes; and adding tools pre-emptively contradicts the
"no premature abstraction" principle (philosophy.md).

The skipped tier is recorded with rationale specifically so the
decisions don't get reflexively reversed. Each entry there has a reason
or a migration trigger documented.

## Consequences

- ✓ Daily-use friction drops noticeably across search, navigation, viewing,
  git, and disk management.
- ✓ Each tool is small and self-contained; failure modes are localised.
- ✓ Originals (`cat`, `find`, `grep`, `du`, `ps`, `df`, `cd`) remain
  callable as their classic selves — scripts unaffected (shell aliases
  don't apply to script execution anyway), interactive muscle memory
  preserved.
- ⚠ `ls`, `ll`, `la`, `lla`, `lt` are aliased to eza variants by
  `programs.eza`'s default fish integration. This is an accepted
  carve-out: eza is a strict-superset interactive replacement for ls
  (colour, git status, modern formatting; defaults still alphabetical /
  one-per-line). The original `ls` is still callable via
  `command ls` / `\ls` / `/run/current-system/sw/bin/ls` if ever needed.
- ✗ Ten new tools to be aware of. Mitigated by each being a near-drop-in
  for a familiar command.
- ⚠ Migration trigger: multi-machine setup → reconsider atuin for
  cross-machine history sync.

## Implementation

Configured in `modules/home/cli-utils.nix`. Pattern: use dedicated
`programs.X` modules where home-manager provides them (these wire shell
integrations cleanly, e.g. fzf's Ctrl-R history binding); plain
`home.packages` for the rest.

```nix
{ pkgs, ... }: {
  programs.fzf.enable = true;
  programs.bat.enable = true;
  programs.eza.enable = true;
  programs.zoxide.enable = true;
  programs.lazygit.enable = true;
  programs.yazi.enable = true;

  home.packages = with pkgs; [
    ripgrep
    fd
    htop
    dust
  ];
}
```

**Aliasing carve-out for eza.** `programs.eza.enableFishIntegration`
defaults to `true` and ships these aliases automatically:
`ls = eza`, `ll = eza -l`, `la = eza -a`, `lla = eza -la`, `lt = eza --tree`.
We keep them — see Consequences for the rationale.

**Do not alias other originals.** `cat`, `find`, `grep`, `du`, `ps`,
`df` stay themselves. Use the new names directly (`bat`, `fd`, `rg`,
`dust`, `htop`) — they have meaningful behavioural differences that
would surprise script logic if aliased. Define short *additional*
aliases for common patterns if you want them (e.g. inside a project's
fish abbrs), but never replace the original command's behaviour.
