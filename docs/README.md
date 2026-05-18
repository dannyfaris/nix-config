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

The companion to this directory is the auto-memory at
`/home/dbf/.claude/projects/-home-dbf-nix-config/memory/`. After Tier 3, those
memory files are thin pointers that reference these docs as the source of
truth, eliminating drift between AI memory and in-repo reference.

## Contents

- **[nix-config-prd.md](./nix-config-prd.md)** — the design document for the
  multi-host rebuild: roles, module organisation, stability tiers, the
  cross-platform contract, structural invariants, and bootstrap. The
  canonical specification of *what we're building and why*.

- **[philosophy.md](./philosophy.md)** — the operating principles that shape
  every decision in this repo (tight from the start, declarative > imperative,
  whitelist > blanket, no premature abstraction, etc.) and the *why* behind
  each.

- **[taxonomy.md](./taxonomy.md)** — how modules and files are named in this
  repo. The "most-communicative term" rule and how it's applied. When role
  names win, when tool names win, when collective category names win.

- **[decisions/](./decisions/)** — Architecture Decision Records (ADRs), one
  per major decision. Light-format: Context / Decision / Rationale /
  Consequences / Implementation. See
  [decisions/README.md](./decisions/README.md) for the index and conventions.

## Reading order

If you're new to this repo:

1. Start with the project-level [CLAUDE.md](../CLAUDE.md) for the top-level
   context, current state, and operational stances.
2. Read [nix-config-prd.md](./nix-config-prd.md) for the design of the
   multi-host configuration — what each role is, how modules are organised,
   what the structural rules are.
3. Read [philosophy.md](./philosophy.md) — the operating principles will help
   you predict why subsequent choices were made.
4. Skim [taxonomy.md](./taxonomy.md) so the module structure makes sense.
5. Dip into [decisions/](./decisions/) for any specific tool or design choice
   you're curious about.

## Conventions

- Each doc has a single subject; there are no kitchen-sink files.
- Prose is the default. Code snippets only where they're load-bearing for
  understanding.
- Honest consequences and migration triggers are recorded — these aren't
  marketing pages.
- Updates land here first. AI memory points here. Module `# why` comments
  reference here when the reasoning is non-obvious.
