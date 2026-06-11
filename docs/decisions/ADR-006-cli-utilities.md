# ADR-006: CLI utilities — modern Unix replacements set

**Date**: 2026-05-06
**Status**: Accepted

> **Revision (2026-06-05):** stale module paths in this ADR were swept to the
> current flat layout (`home/core/…` → `home/…`, `modules/core/…` → `modules/…`)
> per [ADR-026](./ADR-026-drop-core-tier-prefix.md), which dropped the `core/`
> tier prefix. Navigability fix only — the decision recorded here is unchanged.

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

Twelve tools are installed at the home-manager level, available everywhere
on this user's account:

- **ripgrep** (`rg`) — replaces `grep`
- **fd** — replaces `find`
- **fzf** — fuzzy finder (history search, file picker)
- **bat** — replaces `cat` for *viewing* (cat still used for piping)
- **eza** — replaces `ls`
- **zoxide** — partial replacement for `cd` (fuzzy-jump-by-name)
- **lazygit** — TUI git client
- **lazydocker** — TUI docker client (see "Tool-vs-runtime split" below)
- **yazi** — TUI file manager
- **htop** — process / system monitor
- **dust** — replaces `du` with visual disk usage tree
- **jq** — JSON processor (driven by the Claude Code statusline; see ADR-024)

A second tier of tools is **deliberately deferred** rather than installed
pre-emptively:

- **delta** (better git diff pager) — defer until first wanted.

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
- **ENHANCE** (`dlvhdr/gh-enhance`) — the gh-dash author's GitHub-Actions companion TUI (Go, MIT, public; sponsor-supported but *not* paywalled). Skipped not for cost but for packaging: it isn't in nixpkgs and ships no home-manager module, so it can't be installed the declarative reproducible-from-flake way everything else here is — the only paths today are an imperative `gh extension install` (rejected by declarative > imperative) or carrying our own `buildGoModule` derivation. Revisit when it lands as a nixpkgs package; the packaging-and-adopt track is #320. (Its sibling `gh-dash` — the free MIT PR/issue dashboard — *was* adopted; see below.)

## Rationale

The twelve locked-in tools each earn their place by daily use:

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
- **lazydocker** is the TUI docker client — same archetype as lazygit,
  same author. See "Tool-vs-runtime split" below for why the TUI is in
  home-manager but the docker CLI/daemon aren't.
- **yazi** is the visual file manager. It earned its place specifically
  by serving job-of-file-manipulation that helix's file picker can't:
  exploring unfamiliar directories, batch operations with visual
  confirmation, image previews via the kitty graphics protocol. The
  initial proposal had been to skip yazi; pushback on that exclusion led
  to a re-examination and confirmed yazi serves a distinct role.
- **htop** answers "what's eating CPU/RAM?" — the only way to see that on
  a headless box. Cheap, invisible until needed.
- **dust** answers "where did my disk go?" — same pattern as htop.
- **jq** earned its place by the deferred tier's documented trigger
  (first JSON workflow): ADR-024's statusline parses Claude Code's
  JSON-on-stdin. Broadly useful for ad-hoc JSON inspection beyond that.

The deferred tier (delta) is held for two reasons: it's genuinely
useful but only sometimes; and adding tools pre-emptively contradicts the
"no premature abstraction" principle (philosophy.md).

The skipped tier is recorded with rationale specifically so the
decisions don't get reflexively reversed. Each entry there has a reason
or a migration trigger documented.

### Tool-vs-runtime split (lazydocker)

lazydocker is in home-manager but **docker itself is not** at the role
level. The split:

- **lazydocker (TUI client)** — universal, in home-manager. Same archetype
  as lazygit: it's a UI over whatever's available, with no runtime of its
  own.
- **docker CLI** — per-project by default. Each project that needs docker
  declares the CLI version it wants in its own `flake.nix`
  `devShells.default`, picked up via direnv on `cd` (ADR-003). This
  avoids global docker version churn and lets different projects pin
  different versions. *Per-host exception: Mercury and any other
  headless host that imports `modules/nixos/docker.nix` gets the
  docker CLI system-wide alongside the daemon — see ADR-021 for the
  rationale on overriding this default once a daemon exists locally.*
- **docker daemon** — a deployment decision, not a per-project one.
  **Resolved (2026-05-18) by [ADR-021](./ADR-021-docker-on-headless.md):**
  rootless Docker via `virtualisation.docker.rootless.enable` on hosts
  that need it (Mercury today), imported per-host from
  `modules/nixos/docker.nix` rather than from the role. The
  originally-sketched alternatives (Docker Desktop on the Mac with
  `DOCKER_HOST=ssh://…`, rootful `virtualisation.docker.enable`, podman)
  are discussed and rejected in ADR-021.

This split means lazydocker sits ready in home-manager regardless of
daemon state. Hosts without the daemon module work exactly as ADR-006
originally specified (per-project CLI via devShells, daemon remote or
absent); hosts with the daemon module additionally get a local
rootless daemon and a system-wide CLI.

### gh-dash (GitHub PR/issue dashboard)

**Added 2026-06-09.** gh-dash is a TUI dashboard for GitHub pull requests and issues, packaged as a `gh` CLI extension (MIT, in nixpkgs, first-class `programs.gh-dash` home-manager module). It is *not* one of the twelve modern-Unix-replacements above — it's a GitHub-workflow surface, not a general Unix tool — so it sits outside the "available everywhere" core and is recorded here as an adjacent adoption rather than a 13th locked tool.

- **Host gate.** The HM module self-registers in `programs.gh.extensions`, so gh-dash structurally rides on `programs.gh`. It is imported via the `git-multi-identity` bundle next to `gh.nix` — landing on every GitHub host (nixos-vm, metis, mac-mini) and, by the same `mercury_push_boundary` that omits `gh.nix` from `git-work`, never on the work-only host. Putting it on Mercury would mean enabling `gh` there, a deliberate-stance relaxation; declined. See ADR-020 for the personal-vs-work import split.
- **Theming.** gh-dash has no Stylix target, so its `theme.colors` block is bridged by hand to the base16 palette (`config.lib.stylix.colors`) inside `home/shared/gh-dash.nix` — a scheme change in `stylix-palette.nix` repaints it for free. Pinning a named vendor theme (Catppuccin/etc.) was rejected: it would be a second palette source that drifts from Stylix. The cost is a small hand-maintained seam (no `stylix.targets.<x>.enable` toggle).
- **Zellij launcher.** On hosts where `programs.gh-dash.enable` is true, the agent Zellij key layer exposes `Alt+r` (mnemonic: PR/review dashboard) as a floating `gh-dash` pane and shows the same shortcut in the `Alt+k` help pane. `Alt+g` stays the local-repo `lazygit` launcher. The chord is a bare `Alt`-letter free in both zellij and fish (`Alt+s` is fish's prepend-sudo). The agent-layer binds depend on `support_kitty_keyboard_protocol = false` (see `home/shared/multiplexer.nix` for why) — without it zellij leaks the binds to the inner pane on foot. The host gate is unchanged — the bind exists only where `gh-dash` is enabled, so it never reaches the work-only host.

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
- ✗ Twelve new tools to be aware of. Mitigated by each being a near-drop-in
  for a familiar command.
- ⚠ Migration trigger: multi-machine setup → reconsider atuin for
  cross-machine history sync.

## Implementation

Configured in `home/shared/cli-utils.nix`. Pattern: use dedicated
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
  programs.lazydocker.enable = true;
  programs.yazi.enable = true;

  home.packages = with pkgs; [
    ripgrep
    fd
    htop
    dust
    jq
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

**bat as MANPAGER.** `home.sessionVariables.MANPAGER = "sh -c 'col -bx
| bat -l man -p'"` plus `MANROFFOPT = "-c"`. `col -bx` strips overstrike
backspaces (man's bold/underline encoding); `-l man` picks bat's
man-page syntax; `-p` drops decorations. `MANROFFOPT = "-c"` disables
groff's SGR colour output so it falls back to overstrike encoding,
which `col -bx` then strips cleanly before bat re-renders. Wired here
(not in `programs.bat`) because MANPAGER is a shell-session env var,
not a bat-module toggle.

**fzf + fd integration.** Three `programs.fzf` options point fzf at
fd instead of system `find`: `defaultCommand` (bare `fzf` /
`$FZF_DEFAULT_COMMAND`), `fileWidgetCommand` (Ctrl-T file picker),
`changeDirWidgetCommand` (Alt-C directory picker). All three use
`fd --type {f,d} --hidden --exclude .git` — `.gitignore`-aware and
faster than `find`. fd was already in `home.packages` per the locked
list above; this wiring only points fzf at it.
