# nix-config

[![CI](https://github.com/dannyfaris/nix-config/actions/workflows/ci.yaml/badge.svg?branch=main)](https://github.com/dannyfaris/nix-config/actions/workflows/ci.yaml)

Personal NixOS configuration. Three hosts today: a UTM aarch64 VM for refinement (`nixos-vm`), an AWS EC2 x86_64 box for work-only headless dev (`mercury`), and an HP ProDesk x86_64 desktop (`metis`). The same flake-parts tree builds them all; the same set of decisions — module structure, naming, default stances, operational posture — governs every host.

Shared publicly for transparency and so others can lift pieces useful to their own configurations. Not maintained as a generalisable template — decisions reflect one operator's preferences and constraints (PRD §2.2).

## Shape

```
flake.nix                      # flake-parts entry point
parts/                         # flake-parts modules (CI, formatter, dev-shells, nixosConfigurations)
hosts/<host>/                  # per-host instance: hardware, identity, imports of foundation + bundles
modules/{nixos,shared}/   # system-layer modules (foundation, bundles, standalone)
home/{nixos,shared}/      # home-manager modules (foundation, bundles, standalone)
lib/                           # mk-host wrapper, per-host parameters, helper modules
docs/                          # the rationale behind every decision
```

A host file is short: it imports `foundation.nix` (identity, admin, posture), opts into capability bundles for what the host does (`desktop-env`, `remote-access`, `cli-tooling`, …), and adds standalone modules for capabilities that haven't yet earned a bundle home. New hosts are short for the same reason. See [ADR-027](./docs/decisions/ADR-027-foundation-and-bundles.md) for the composition model.

## Operating philosophy

Six principles shape every decision; full statements with reasoning at [`docs/philosophy.md`](./docs/philosophy.md):

- **Tight from the start** — "good enough for now" becomes permanent for everyone except the current author.
- **Declarative > imperative** — state what should be true; nix figures out how.
- **Explicit > implicit** — intent visible in the repo, not in the contributor's head.
- **Whitelist > blanket** — new things slip through blanket allows; whitelists force a deliberate choice.
- **Single source of truth** — two records that disagree are the most painful failure mode.
- **No premature abstraction** — wrappers and flags earn their place by concrete need, not speculation.

These produce the technical stances pinned in [`CLAUDE.md`](./CLAUDE.md) §"Deliberate stances" (`users.mutableUsers = false`, key-only SSH, the `allowUnfreePredicate` whitelist) and the process stances in [`docs/workflow.md`](./docs/workflow.md) (intent-first issues, doc-before-code for selections, peer-review staged diffs, dependencies via linked issues, squash auto-merge).

## Reading order

For a contributor reading the repo cold:

1. [`CLAUDE.md`](./CLAUDE.md) — top-level state, deliberate stances, the operational current.
2. [`docs/nix-config-prd.md`](./docs/nix-config-prd.md) — the design spec for the multi-host configuration.
3. [`docs/philosophy.md`](./docs/philosophy.md) — the technical principles that predict subsequent choices.
4. [`docs/workflow.md`](./docs/workflow.md) — how work moves through the repo.
5. [`docs/decisions/`](./docs/decisions/) — Architecture Decision Records for any tool or design choice worth knowing about.

[`docs/README.md`](./docs/README.md) is the canonical index into the reference materials.

## Status

CI builds every host on every PR via `nix flake check` (see [`.github/workflows/ci.yaml`](./.github/workflows/ci.yaml)). Lockfile bumps come via a weekly automated PR (Mondays 04:00 UTC) and merge manually after green CI. PRs land via squash auto-merge after required checks pass. Substantive decisions are recorded as ADRs before they affect `main`.

## License

MIT — see [LICENSE](./LICENSE).
