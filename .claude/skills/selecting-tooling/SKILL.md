---
name: selecting-tooling
description: Repeatable process for assessing and choosing a tool, package, daemon, or service to adopt, swap, or keep in this NixOS/nix-darwin config. Combines first-principles architecture, prior-art research, and — critically — verification of every load-bearing claim against the actual flake pins and running system before deciding. Use when selecting or comparing packages/tools/services, evaluating alternatives, deciding whether to adopt/replace/retain a dependency, or working a roadmap or desktop-env selection issue (sound server, clipboard manager, polkit agent, mount stack, file manager, and so on). Records the decision via the repo's doc-before-code, peer-review, and draft-PR cadence.
---

# Selecting tooling

A disciplined way to choose what to install in this config. The generic half — research the options, weigh tradeoffs — is something to just do well. This skill exists for the half that gets skipped and repeatedly changes the answer: **grounding in what's already here, and verifying every load-bearing claim against the actual pins and running system before deciding.** Treat the checklist as a high-freedom guide, not a rigid script — follow where the verification leads.

## When this applies

Any decision to **adopt, swap, keep, or compare** a package, application, daemon, service, or stack in the config. Equally: sound servers, clipboard managers, polkit agents, mount stacks, file managers, CLI tools, browser choices.

**When it does not:** a foregone install with no real alternative weighed (see the "Deliberate no-doc" precedent in `docs/desktop/README.md`). Don't run the full ceremony for `ripgrep`.

## The process

Copy this checklist into your working notes and track it:

```
Selection progress:
- [ ] 0. Verify the premise — is the problem as stated actually true?
- [ ] 1. Ground in current state — what's already installed / pinned / wired?
- [ ] 2. First principles — how does the mechanism actually work?
- [ ] 3. Prior art — proven, aligned options + maintenance + packaging reality
- [ ] 4. VERIFY every load-bearing claim against the real system / pins
- [ ] 5. Separate convention from the genuine judgment calls
- [ ] 6. Decide — honest tradeoffs + a clear lean + the residual risk
- [ ] 7. Record + build — doc-before-code → peer-review → (draft) PR
```

**0 — Verify the premise.** Issues and requests routinely state a problem that isn't true: "nothing surfaces a prompt" (an agent was already running); "mounting needs auth" (removable media is passwordless). Check the stated problem exists before designing a fix. This is step zero for a reason.

**1 — Ground in current state.** The highest-leverage step. `grep` the repo, and query the running host (`nix eval` the host config, `systemctl --user`, `/proc`, look for config files present/absent). This repeatedly reframes "add X" into "swap X" or "keep X" — which is a different, smaller decision.

**2 — First principles.** Explain the mechanism plainly enough to teach it. Decisions should rest on understanding the architecture (who owns the data, which daemon does what, what the protocol guarantees), not on copying a popular dotfile.

**3 — Prior art (spawn a research subagent).** Ask for three things, with source URLs: the conventional + philosophically-aligned option(s); **maintenance reality** (release recency, bus factor, single-maintainer risk — matters most on security/critical paths); and **packaging reality** (is it in our nixpkgs at all? what version? is there an open bump PR?). Tell it to be skeptical and *not* just confirm your guess — say so explicitly.

**4 — VERIFY (the firm step; budget real effort here).** Do **not** trust docs, recalled memory, or the research summary for any load-bearing fact. Check against the actual pins and the running box. This step flipped or recalibrated the conclusion in every worked example — see `examples.md`. The recurring checks live in "Verification gotchas" below.

**5 — Convention vs judgment.** State which layers are "adopt the convention" (don't agonize) and which are the genuine fork. Most stacks are 80% convention; spend the deliberation on the 20%.

**6 — Decide.** An honest tradeoff table, a clear lean, and the named residual risk. For any number: **measure it or cite it — never fabricate — and state it once** (don't repeat a figure across the doc and the issue comment; it drifts).

**7 — Record + build.** Follow the repo's existing cadence; this skill does not restate it:
- **Artifact + structure:** the per-tool selection-doc shape in `docs/desktop/README.md` (or `docs/<area>/`).
- **Workflow** (doc-before-code, intent-first issues, peer-review of staged diffs, draft-PR + squash auto-merge): `docs/workflow.md`.
- Peer-review **both** the selection doc and the implementation diff with a subagent before commit.

## Verification gotchas

The non-obvious checks that keep changing outcomes — this is the core value of the skill:

- **It may already be here.** `niri-flake` and desktop modules pull in agents/daemons/keyrings *transitively*. Check before adding a duplicate.
- **Standalone closure ≠ marginal closure.** `nix path-info -S` counts shared toolkit deps that other things already pull. Compute the paths reachable *only* through the candidate to get the real cost; exclude the candidate's own unit when doing the set math.
- **nixpkgs lag is real.** The version you'd actually get may trail upstream by months. Check the version *in the pin* (`nix eval .#nixosConfigurations.<host>.pkgs.<p>.version`), not just "it exists." Before authoring a bump, search for an existing open nixpkgs PR. Pattern: local `overrideAttrs` now + upstream PR in parallel, drop the override when it lands.
- **Module/option existence goes stale.** Confirm a NixOS/home-manager option exists in the *locked* source (grep the pinned nixpkgs/home-manager checkout), not from memory.
- **Security/privilege assumptions.** Don't assume a password prompt happens — verify the actual policy (e.g. polkit action defaults: removable-media mounting is `allow_active yes`). Don't add a blanket rule the whitelist stance wouldn't want.
- **Single-source every measured number.** A figure repeated across artifacts drifts; a peer reviewer will (rightly) flag it.

## Subagents

- **Research (step 3) and verification cross-checks:** a research subagent; demand source URLs and explicit skepticism ("do not just confirm").
- **Peer review (step 7):** an independent subagent reviews the draft doc and the staged diff before commit. First confirm the working tree matches the intended merge target, and scope the review to the relevant files.

## Examples

See [examples.md](examples.md) — four worked cases (audio, clipboard, polkit, removable-media), each highlighting how step 4 (verify) changed the outcome.
