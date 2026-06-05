# Operator identities — personal and work split

The operator works two distinct identities from this dev box:

- **Personal** — `dannyfaris <daniel@faris.co.nz>`, GitHub, this nix-config,
  side projects, anything outside `~/grey-st/`.
- **Work** — `Daniel Faris <daniel.faris@gotaxi.co.nz>`, Grey St (which
  operates the Tax Traders and Taxi brands), GitLab, anything inside
  `~/grey-st/`.

Multiple tools need to know which identity is active so that commits,
sessions, and credentials route to the right place. This doc captures
the convention they all follow.

## Convention

**Rule.** Personal is the default. Work is conditional under `~/grey-st/`.
Every tool that participates in the split applies the same shape: the
personal identity is used everywhere unless the working directory is
inside `~/grey-st/`, at which point the work identity takes over. The
load-bearing trigger is the literal path prefix `~/grey-st/`. The
companion `~/personal/` directory exists by convention — both are
pre-created by `home/shared/git-identity-dual.nix`'s activation block —
but `~/personal/` is not a routing condition for any tool; it is a
naming convention for where personal repos *prefer* to live.

**Why.** The personal-default direction means a repo or session that
starts outside `~/grey-st/` cannot silently inherit the work identity.
Stray nix experiments, throwaway scripts, cloned forks, and this repo
itself all stay personal without further thought. The work identity is
opt-in by location: putting something under `~/grey-st/` is the explicit
signal "this belongs to the employer context" — the same signal that
already governs which git remote it pushes to and which calendar /
chat context it relates to. The inverse direction was tried — see the
prior art in "See also" — and reverted because its safety improvement
in one direction (personal email leaking into work history) was
outweighed by the friction it introduced everywhere else, and because
the box is operator-personal-by-default in practice.

**How it shows up.** Each participating tool wires the split in its
own idiom but observes the same direction and trigger. New tools that
grow per-identity state (credentials, transcripts, caches, profiles)
should adopt the same pattern: personal default, work conditional
under `~/grey-st/`. Before wiring, verify end-to-end that the tool's
per-tree mechanism actually controls *identity* state — not just
settings, caches, or session histories.

## Mechanism layer

For tools whose identity selection runs off environment variables or
config-path lookups, the standard activation primitive is direnv (per
[ADR-003](./decisions/ADR-003-direnv.md)): an `.envrc` at `~/grey-st/`
sets per-identity variables and Nix-managed direnv activates them on
`cd`. Tools that have a native conditional mechanism — git's
`includeIf gitdir:` is the canonical case — should use it directly
rather than route through direnv.

## Participating tools

| Tool | Mechanism | Reference |
|---|---|---|
| **git** | `includeIf gitdir:~/grey-st/` in user-level config | [ADR-009](./decisions/ADR-009-git.md), `home/shared/git-identity-dual.nix` |

## Tools that opted out

- **Claude Code** ([#137](https://github.com/dannyfaris/nix-config/issues/137)) —
  the intended mechanism (`CLAUDE_CONFIG_DIR`) does not control identity
  in Claude Code 2.1.121. The `oauthAccount` value that `/status`
  reports lives in `$HOME/.claude.json` regardless of the env var, and
  `/login` writes the default store regardless of cwd; `CLAUDE_CONFIG_DIR`
  only steers `.credentials.json`, `settings.json`, `projects/`, and
  `statusline.sh`. Settled on single identity (personal default); use
  `/logout` + `/login` on the rare occasion the work account is needed
  inside `claude`.

## Failure modes

The split is best-effort, not enforced. Known modes:

- **Tool-specific staleness within a session.** Tools that snapshot
  the active identity at session start do not switch identity if the
  working directory changes mid-session — new terminal / session
  required. No current participating tool exhibits this (git re-reads
  config every invocation), but it remains the standard concern for
  any future env-var-driven tool.
- **Silent overwrite on identity-write actions.** A tool's "set
  identity" command writes to whichever store is currently active.
  `git config --global user.email ...` from anywhere overwrites the
  default. Recoverable, but invisible at the time it happens.
- **No after-the-fact audit for non-git tools.** Git has
  `git log --author=daniel.faris@gotaxi.co.nz` (and the inverse
  `--author=daniel@faris.co.nz`) to retroactively catch identity
  leaks across a tree's history. Most other tools have no equivalent.

Mitigations are tool-specific and tracked under each tool's own
issues rather than centrally. The general posture is "rely on
explicit `~/grey-st/` placement to be enough"; instrumentation gets
added per tool only if leaks actually occur.

## See also

- [ADR-009](./decisions/ADR-009-git.md) — git dual identity, the
  canonical implementation of this pattern.
- [ADR-003](./decisions/ADR-003-direnv.md) — direnv as the standard
  per-tree env activation primitive, leveraged by any tool whose
  identity selection runs off environment variables.
- [#122](https://github.com/dannyfaris/nix-config/issues/122) (proposal),
  [#136](https://github.com/dannyfaris/nix-config/pull/136) (the flip
  that landed), [#139](https://github.com/dannyfaris/nix-config/pull/139)
  (the revert that restored the personal-default direction). Useful
  prior art for any future "should we flip the direction?" question;
  the on-disk ADR record was cleared, so issues / PRs are the trail.
- [#137](https://github.com/dannyfaris/nix-config/issues/137) — Claude
  Code per-tree auth investigation (declined; see "Tools that opted
  out").
- [docs/workflow.md](./workflow.md) — process conventions.
