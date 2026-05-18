# Architecture Decision Records (ADRs)

This directory captures every load-bearing decision shaping this nix config.
Each ADR is a self-contained document with the context, the decision, the
rationale, and honest consequences.

## Format

We use a **light ADR format**:

```markdown
# ADR-NNN: [Title]

**Date**: YYYY-MM-DD
**Status**: Accepted

## Context
[The forces driving the decision — project constraints, user preferences,
prior decisions that constrain this one. ~1 short paragraph.]

## Decision
[What we chose, 1–2 paragraphs.]

## Rationale
[The load-bearing reasoning — why this option over alternatives. The
honest comparison with rejected options.]

## Consequences
- ✓ [positive outcome]
- ✓ [positive outcome]
- ✗ [honest negative tradeoff]
- ⚠ [migration trigger — circumstances that would make this decision
   worth revisiting]

## Implementation
[Brief: which module file(s), key idioms, load-bearing config snippets.]
```

The shape is intentionally light: enough structure to make ADRs scannable
and consistent, but not so much that small decisions feel over-formalised.

## Index

| # | Topic | Choice | Summary |
|---|-------|--------|---------|
| [001](./ADR-001-shell.md) | Shell | fish | Interactive shell; chosen for clean out-of-box UX |
| [002](./ADR-002-prompt.md) | Prompt | starship | Declarative TOML; nix-shell indicator was the deciding factor |
| [003](./ADR-003-direnv.md) | Per-project envs | direnv + nix-direnv | Standard nix dev-shell activation pattern |
| [004](./ADR-004-multiplexer.md) | Multiplexer | zellij | Discoverable status bar; modern out-of-box UX |
| [005](./ADR-005-editor.md) | Editor | helix | Batteries-included; selection-first model |
| [006](./ADR-006-cli-utilities.md) | CLI utilities | rg, fd, fzf, bat, eza, zoxide, lazygit, yazi, htop, dust | Modern Unix replacements |
| [007](./ADR-007-nix-tooling.md) | Nix tooling | nh, nom, nixd, nixfmt, statix, deadnix | Modern overlay on nix UX |
| [008](./ADR-008-agent-clis.md) | AI coding agents | Claude Code, Codex, Gemini, Cursor | Four agents, OAuth login flows |
| [009](./ADR-009-git.md) | Git | dual identity, HTTPS+token | personal/work split via gitdir; HTTPS via gh/glab credential helpers |
| [010](./ADR-010-ssh.md) | SSH | defaults only | Outbound key generation deferred (HTTPS git removes the need) |
| [011](./ADR-011-remote-dev-qol.md) | Remote-dev QoL | mosh + OSC52 | Session resilience; cross-machine clipboard |
| [012](./ADR-012-taxonomy.md) | Module taxonomy | Most-communicative term | The naming rule itself, as a meta-decision |
| [013](./ADR-013-composition-framework.md) | Composition framework | flake-parts + role-explicit imports | Roles list modules explicitly; no auto-discovery |
| [014](./ADR-014-independent-roles.md) | Role composition | independent, not inherited | Each role imports modules directly; no shared parents |
| [015](./ADR-015-tier-as-directory.md) | Stability tier | encoded as directory | `core/` vs `experimental/` in the path |
| [016](./ADR-016-host-identity.md) | Host identity | stable per physical machine | Hardware change = new host; software role change = no rename |
| [017](./ADR-017-headless-bootstrap-aws-ami.md) | Headless bootstrap (AWS) | NixOS AMI + amazon-image module | Resolves PRD §12 deferral; no nixos-anywhere/disko on EC2 |
| [018](./ADR-018-headless-secrets-sops.md) | Headless secrets | sops-nix | Resolves PRD §12 deferral; same pattern as the VM, 1Password `op` deferred again |
| [019](./ADR-019-host-parametrisation.md) | Per-host parametrisation | `_module.args.hostContext` + `extraSpecialArgs` | Per-host values reach home-manager modules via the function-arg forwarder |
| [020](./ADR-020-role-overlap-via-import-splits.md) | Work-vs-personal divergences | import splits, not host-keyed `mkIf` | One file = one configuration; choice expressed by which modules a host imports |

## Conventions

- **Sequential numbering, padded to three digits.** Easier sorting; reads
  right; gives room to grow.
- **Filename convention**: `ADR-NNN-<topic>.md` where `<topic>` is a
  short kebab-case slug.
- **Status starts as Accepted.** If a decision is later superseded, edit the
  status to "Superseded by ADR-XXX" and add a top-of-file note pointing to
  the successor. Don't delete or rewrite the historical record.
- **Date** is the date of the original decision, not the date of writing.
  When backfilling ADRs from earlier conversations, use the conversation
  date.

## Adding a new ADR

1. Pick the next number.
2. Copy the format block above.
3. Write the four substantive sections honestly. The Consequences section is
   the test — if you can't articulate negatives or migration triggers, the
   decision probably isn't worth an ADR.
4. Update this index.
5. Cross-reference from `philosophy.md` or `taxonomy.md` if the ADR touches
   either.
6. If the new ADR supersedes an old one, edit the old one's status and add
   the pointer.
