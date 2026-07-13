# Reference documentation

This directory is the canonical record of the *why* behind this NixOS config — the
philosophy, the taxonomy, and the individual decisions that shaped each piece of
the configuration.

## Audience and intent

These docs are written primarily for **humans reading the repo** — future-me at
six-months remove, a future collaborator, or anyone trying to understand why a
choice was made. AI sessions also use these as reference; `CLAUDE.md` at the
repo root is the higher-level entry point for AI sessions, and links here for
depth.

The companion to this directory is Claude Code's file-based auto-memory
(`~/.claude/projects/<repo>/memory/`). That memory is per-host and never
synced between machines, so it is a session scratchpad — anything durable
lives here in `docs/` (and `CLAUDE.md`), committed to the repo where every
host sees it. See CLAUDE.md §"Agent memory lives in git, not local state".

## Contents

- **[nix-config-prd.md](./nix-config-prd.md)** — the design document for the
  multi-host configuration: composition model (foundation + bundles +
  standalone modules), module organisation, the cross-platform contract,
  structural invariants, and bootstrap. The canonical specification of
  *what we're building and why*.

- **[philosophy.md](./philosophy.md)** — the operating principles that shape
  every decision in this repo (tight from the start, declarative > imperative,
  whitelist > blanket, no premature abstraction, etc.) and the *why* behind
  each.

- **[workflow.md](./workflow.md)** — the process principles that shape how
  work moves through the repo (intent-first issue framing, doc-before-code
  for selections, peer-review staged diffs before commit, dependencies via
  linked issues, squash auto-merge, etc.) and the *why* behind each. Sibling
  to philosophy.md: philosophy is *what* we build; workflow is *how* we
  build it.

- **[taxonomy.md](./taxonomy.md)** — how modules and files are named in this
  repo. The "most-communicative term" rule and how it's applied. When role
  names win, when tool names win, when collective category names win.

- **[identities.md](./identities.md)** — the cross-tool convention for the
  operator's personal / work identity split: direction (personal default,
  work conditional under `~/grey-st/`), trigger boundary, participating tools,
  failure modes. Where future tools that grow per-identity state should
  refer when wiring their split.

- **[ci.md](./ci.md)** — the per-knob operational companion to
  [ADR-025](./decisions/ADR-025-ci-in-flake.md): why each setting in
  `.github/workflows/ci.yaml` is what it is (display-name/branch-protection
  mechanics, permissions, runner pins, substituters, the build-output
  cache, the retry). Living doc; ADR-025 owns the framework decision and
  dated history, this owns the standing mechanics.

- **[decisions/](./decisions/)** — Architecture Decision Records (ADRs), one
  per major decision. Light-format: Context / Decision / Rationale /
  Consequences / Implementation. See
  [decisions/README.md](./decisions/README.md) for the index and conventions.

- **[desktop/](./desktop/)** — living documents for the Wayland desktop
  environment: per-tool selections, fonts, keybindings. Complements
  `decisions/` (immutable ADRs) with mutable rationale that evolves as
  the desktop grows. See [desktop/README.md](./desktop/README.md) for
  the index and conventions.

- **[darwin/](./darwin/)** — living documents for macOS-specific host
  configuration: [touch-id.md](./darwin/touch-id.md) (Touch ID for sudo)
  and [system-updates.md](./darwin/system-updates.md) (the unattended
  macOS + App Store update posture). The macOS parallel to `desktop/`;
  the nix-darwin framing ADRs stay in `decisions/`.

- **[research/](./research/)** — point-in-time research notes: surveys,
  prior-art scans, and option analyses that feed decisions and living
  documents but are neither. Dated and cited; explicitly not decisions.
  See [research/README.md](./research/README.md) for the index.

- **[design/](./design/)** — design notes: the doc-before-code working-out of a non-trivial change (problem & intent → forces → options weighed → decision → architecture → de-risk → open items). *Proposed* artifacts that precede implementation; the decision graduates to an ADR in `decisions/`, while `research/` notes feed them. See [design/README.md](./design/README.md) for the index and conventions.

- **[agents/](./agents/)** — living documents for the AI coding agents
  (Claude Code + Cursor CLI per ADR-008) and their per-surface decisions
  — model-tier colour mapping, statusline signal selection, behavioural
  conventions. Parallel to `desktop/` for the agent-CLI surface; the
  framing ADRs (ADR-008, ADR-024) stay in `decisions/`. See
  [agents/README.md](./agents/README.md) for the index.

- **[runbooks/](./runbooks/)** — operational procedures: ordered, copy-
  pasteable steps for tasks that aren't (and shouldn't be) declarative.
  Currently:
  [headless-bootstrap.md](./runbooks/headless-bootstrap.md) —
  bringing up a new headless NixOS host (AWS or bare-metal) from
  clean OS to `nh os switch` via `nixos-anywhere` + `disko`. And
  [darwin-bootstrap.md](./runbooks/darwin-bootstrap.md) — bringing up a new macOS host from clean state to `nh darwin switch` via the NixOS official installer + `nix run nix-darwin -- switch`.

## Reading order

If you're new to this repo:

1. Start with the project-level [CLAUDE.md](../CLAUDE.md) for the top-level
   context, current state, and operational stances.
2. Read [nix-config-prd.md](./nix-config-prd.md) for the design of the
   multi-host configuration — how foundation + bundles compose, how modules
   are organised, what the structural rules are.
3. Read [philosophy.md](./philosophy.md) — the operating principles will help
   you predict why subsequent choices were made.
4. Read [workflow.md](./workflow.md) — the process conventions tell you how
   work moves through the repo (intent-first issues, doc-before-code,
   peer-review). Read before opening issues or cutting code.
5. Skim [taxonomy.md](./taxonomy.md) so the module structure makes sense.
6. Dip into [decisions/](./decisions/) for any specific tool or design choice
   you're curious about.

## Conventions

- Each doc has a single subject; there are no kitchen-sink files.
- Prose is the default. Code snippets only where they're load-bearing for
  understanding.
- Honest consequences and migration triggers are recorded — these aren't
  marketing pages.
- Updates land here first. AI memory points here. Module `# why` comments
  reference here when the reasoning is non-obvious.
