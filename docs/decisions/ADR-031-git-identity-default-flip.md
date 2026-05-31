# ADR-031: Flip the dual-identity default — work as default, personal as gitdir-conditional

**Date**: 2026-05-31
**Status**: Accepted, Implemented

## Context

[ADR-009](./ADR-009-git.md) §Decision established **personal as the default identity** with a `gitdir:~/work/` conditional override applying the work identity inside the work boundary. The reasoning at the time was that personal repos are the historical default and work is the carve-out.

A year-plus of using this setup made the asymmetric leak vectors visible. Each direction has its own "wrong" case when a repo lands outside the conventional directory:

| Default | "Wrong" case | Leak |
|---|---|---|
| Personal default (today) | Work repo cloned outside `~/work/` | Personal email surfaces in employer's git history |
| Work default (proposed) | Personal repo cloned outside `~/personal/` | Work email surfaces in personal/public git history |

The two failure modes are not symmetric in cost:

- A personal email landing in an employer's GitLab is visible to colleagues, employer infra (audit logs, mirrors, archives, integrations), and resists clean retroactive removal. It also affects personal privacy. Employer git history is durable: backups, GitLab Geo replicas, CI artifacts, third-party integrations (linear, slack, etc.) often surface commits by email.
- A work email landing in a personal repo is generally bad if NDAs apply but is broadly less personally identifying. It also tends to be on the operator's own infrastructure where retroactive cleanup (force-push to a personal repo) is in-scope.

Operator's working pattern has also shifted: work is the dominant workload, personal repos are the minority. The default should match the majority case.

## Decision

**Flip the default identity.** Work identity becomes the unconditional default; personal identity is applied via `gitdir:`-conditional includes.

```nix
settings.user = {
  name = "Daniel Faris";
  email = "daniel.faris@gotaxi.co.nz";
};

includes = [
  {
    condition = "gitdir:~/personal/";
    contents.user = { name = "dannyfaris"; email = "daniel@faris.co.nz"; };
  }
  {
    condition = "gitdir:~/nix-config/";
    contents.user = { name = "dannyfaris"; email = "daniel@faris.co.nz"; };
  }
];
```

The second `gitdir:~/nix-config/` condition is an explicit carve-out for this very flake's working checkout, which lives at `~/nix-config/` rather than under `~/personal/` because it is also the canonical `NH_FLAKE` path (see `lib/operator.nix:flakeRepoDirname` and the `flakePath` host-context default in `modules/nixos/host-context.nix`). Relocating it to `~/personal/nix-config` would propagate through every host's `_module.args.hostContext` and the `NH_FLAKE` environment variable on every host — strictly larger than this change wants to be. An explicit carve-out is the smaller move.

## Rationale

**Match the default to the dominant workload.** Work is the majority case; making it the default closes the asymmetry where the minority pattern (personal) carries the burden of "remember which carve-out applies".

**Asymmetric leak severity.** The proposed flip trades a higher-severity leak (personal email into employer git history) for a lower-severity one (work email into a personal repo cloned to an unconventional path). Issue #122's tradeoff table captures the calculus: the high-visibility-low-recoverability leak is the one worth designing against.

**Pre-flight audit closes the migration risk.** Before applying, an operator-side find ran:

```sh
find ~ -maxdepth 4 -name .git -type d \
  -not -path '*/work/*' -not -path '*/personal/*' \
  -not -path '*/.cache/*' -not -path '*/.local/*' \
  -not -path '*/.cargo/*' -not -path '*/.rustup/*' 2>/dev/null
```

On metis (2026-05-31) the only match was `~/nix-config/.git` — handled by the explicit carve-out above. On future hosts (mercury, nixos-vm, mac-mini onboarding) the audit needs to be re-run before `nh os switch`; matches relocate into `~/personal/` or `~/work/` (or earn their own carve-out condition, with a comment explaining why relocation isn't right).

**Single carve-out is acceptable special-casing.** The "no carve-outs" stance from ADR-027 is about *aggregator-file purity*, not about git config. `gitdir:`-conditional includes are git's native mechanism for exactly this — a deliberate per-directory override. One conditional per non-conventional location is the smaller of two evils versus "relocate every personal project for the sake of the rule".

## Consequences

- ✓ Personal email cannot leak into a work repo cloned anywhere on the box. The work default catches every `~/work/`-resident repo and every misplaced work repo (`~/Projects/<work-thing>/`, `/tmp/`, `~/Downloads/`, etc.).
- ✓ Default matches the majority workload; the carve-out applies to the minority.
- ✓ The `~/nix-config/` carve-out preserves the existing `NH_FLAKE` / flake-path wiring across all three hosts.
- ✗ A personal repo cloned outside `~/personal/` (or `~/nix-config/`) silently inherits the work identity — the inverse of the leak we closed. This is the price of any directionally-rooted default. The audit gotcha (below) is the mitigation.
- ⚠ **Audit on each new host before activation.** The find above is a one-time pre-flight check per host. Any orphan personal repos must be relocated or earn their own carve-out before `nh os switch`. TODO.md tracks this gotcha for the remaining hosts.
- ⚠ Migration trigger: if employer policy ever changes such that `Daniel Faris <daniel.faris@gotaxi.co.nz>` is not the right work identity (rename, employer change), the default changes here — and the `gitdir:~/work/` conditional from the old shape is gone. ADR-009 + this ADR both need updating.
- ⚠ Migration trigger: if a personal forge (GitHub Action, Codeberg, etc.) starts requiring DCO sign-offs or commits-to-be-by-Real-Name, the personal identity may need to mirror the work shape (`Daniel Faris` real name). Today, GitHub's `dannyfaris` handle is fine.

## Implementation

Single-file edit: `home/shared/git-identity-dual.nix` — flip the `settings.user` block and the `includes` list per the snippet in §Decision.

`home/shared/git-identity-work.nix` (the single-identity file used on `mercury`) is unaffected — work-only hosts already have the work identity as their sole identity.

ADR-009 §Status updates to `Accepted, Implemented (Amended by ADR-031)`. The substantive ADR-009 text — auth model (HTTPS + token), `gh`/`glab` credential helpers, no SSH keys for git — stands unchanged.

`TODO.md` carries the per-host audit gotcha under the relevant onboarding section so future host commissioning runs the find before activating identity.

## Provenance

Proposal originated from issue #122 (2026-05-31), itself salvaged from an exploratory branch (`claude/nix-home-manager-setup-BFdQz`, 2026-05-13) that drafted the change against the pre-refactor `modules/home/git.nix` path. The deliberation captured in the issue body — directional-leak tradeoff, inverse-trap mitigation, pre-flight audit — is the load-bearing reasoning; this ADR preserves and accepts that analysis.
