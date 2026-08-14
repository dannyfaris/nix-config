# Taxonomy: how files and modules are named

This document captures the naming convention applied across the home-manager module trees (`home/shared/` and `home/nixos/`) and the system module trees (`modules/nixos/` and `modules/shared/`), and by extension any future module trees. The decision itself is recorded in [ADR-012](./decisions/ADR-012-taxonomy.md); this document is the applied principle with examples.

> **Note:** some of the examples below reference earlier directory shapes (`modules/home/` and `modules/system/` from a pre-foundation refactor; `modules/core/...` and `home/core/...` from the pre-ADR-026 tier-prefix era) because the rule was articulated against those trees. The current trees are `home/{shared,nixos,darwin}/` and `modules/{nixos,darwin,shared}/` per the PRD §5 directory grid (post-[ADR-026](./decisions/ADR-026-drop-core-tier-prefix.md), with the `darwin/` axis added when nix-darwin onboarded — epic #11). The naming rule itself applies unchanged; only the directories moved.

## The rule

**Name each file by whichever term is most communicative to a reader.**

That's the whole rule. Everything below is its application.

In practice, "most communicative" resolves to one of three name sources:

1. **Role-based names** when the role is a more universally recognised term than any one implementing tool.
2. **Tool/protocol names** when the tool's name *is* its role — the tool is the universally recognised term and abstracting away from it adds ambiguity rather than clarity.
3. **Collective category names** when a file groups multiple tools serving one role and there's no obvious single-tool umbrella.

## Examples and reasoning

### `modules/home/` (role-based)

| File              | Why role-based                                                                                           |
| ----------------- | -------------------------------------------------------------------------------------------------------- |
| `shell.nix`       | "Shell" is more universal than "fish". A reader knows what a shell is without needing to know which one. |
| `prompt.nix`      | "Prompt" is the role; starship is one implementation.                                                    |
| `multiplexer.nix` | "Multiplexer" is the role; zellij is one implementation.                                                 |
| `editor.nix`      | "Editor" is the role; helix is one implementation.                                                       |

### `modules/home/` (tool/protocol-named)

| File         | Why tool-named                                                                                                                                                                                                                             |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `git.nix`    | "Git" is the universally recognised term — calling it `version-control.nix` would be more abstract but no clearer to any reader. The file contains git + gh + glab, but git is unambiguously the umbrella.                                 |
| `ssh.nix`    | "SSH" is short for "Secure Shell Protocol" — the acronym IS the role. Calling it `secure-shell.nix` is the same name, longhand. Calling it `remote-shell.nix` introduces ambiguity (could mean SSH-the-tool or remote-shell-as-a-context). |
| `direnv.nix` | "direnv" is the recognised term in nix circles. "project-envs" was considered but is less communicative than the actual tool name.                                                                                                         |

### `modules/home/` (collective category)

| File              | What it contains                                                                                                                                          |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `cli-utils.nix`   | rg, fd, fzf, bat, eza, zoxide, lazygit, yazi, htop, dust — modern Unix replacements. No single tool is the umbrella; the category is.                     |
| `nix-tooling.nix` | nh, nom, nixd, nixfmt, statix, deadnix — six tools improving the nix dev experience. Same pattern.                                                        |
| `agent-clis.nix`  | Claude Code + Cursor CLI — the always-on base. Codex + Antigravity CLI live in the sibling `agent-clis-extras.nix`, imported per-host (ADR-008, ADR-020). |

### `modules/system/` (mixed, all communicative)

| File                                       | Naming class                                                                  |
| ------------------------------------------ | ----------------------------------------------------------------------------- |
| `boot.nix`, `networking.nix`, `locale.nix` | Role names — these are universal terms for what they configure.               |
| `nix.nix`                                  | Tool name — "nix" is the universally recognised term for nix daemon settings. |
| `ssh.nix`                                  | Protocol acronym (same reasoning as in `modules/home/`).                      |
| `sops.nix`, `docker.nix`                   | Tool names.                                                                   |
| `users.nix`, `packages.nix`                | Role/category names.                                                          |

## Rejected alternatives

### "All-role with forced names"

This was the first proposal: rename everything to a role name, even where the role name was wordier than the tool name (e.g., `secure-shell.nix` for SSH, `project-envs.nix` for direnv, `version-control.nix` for git).

**Why rejected.** Some of these names were genuinely more confusing than their tool-name alternatives. `secure-shell.nix` reads as a context (a collection of tools used during remote shell sessions) rather than a role (the SSH protocol itself). `project-envs.nix` is an invented term, less recognised than "direnv". The pursuit of consistency-for-its-own-sake produced names that were strictly worse on the criterion that actually matters: how fast a reader parses the name into understanding.

### "All-tool with no abstractions"

Mirror image of the above: name every file after its primary tool — `fish.nix`, `starship.nix`, `zellij.nix`, etc.

**Why rejected.** The collective category files (`cli-utils.nix`, `nix-tooling.nix`, `agent-clis.nix`) genuinely contain multiple parallel tools with no umbrella tool to name them after. Picking one (e.g., naming the cli-utils file `ripgrep.nix`) would be misleading; any name that truthfully described the file's content would be a category name. So strict all-tool naming isn't even achievable.

### "Decompose by lifecycle / frequency of change"

Considered: name files by how often they change (`stable.nix`, `volatile.nix`).

**Why rejected.** Lifecycle is not a meaningful axis to a reader who is trying to find a specific configuration. Knowing that a file is stable doesn't help you find shell configuration in it.

## What this gives us

- A reader can predict where any configuration lives without consulting an index.
- The tree reads as a clear taxonomy without forcing any single naming convention to do work it isn't suited for.
- Tool swaps are cheap (rename a file body, not a path) where the role name has been chosen well; they're a single-file content change otherwise.
- Inconsistency-as-honesty: the rule is a single sentence, but it produces three name shapes, and that's the right answer.

## Structural units: bundles, foundation, and standalone modules

The naming rule above covers *individual modules*. A separate, narrower convention covers the *aggregator files* that compose them — introduced by [ADR-027](./decisions/ADR-027-foundation-and-bundles.md) when the role abstraction was walked back. The structural picture is simpler than the three-bucket framing might suggest: there is one kind of aggregator file (a bundle), and one naming convention (`foundation.nix`) that marks the bundle every host imports.

### Bundles

**Name:** kebab-case, describes the capability the bundle groups (`remote-access.nix`, `cli-tooling.nix`, `desktop-env.nix`, `git-multi-identity.nix`).

**Location:** under a `bundles/` subdirectory per platform layer:

```
modules/nixos/bundles/remote-access.nix
home/shared/bundles/cli-tooling.nix
home/shared/bundles/git-multi-identity.nix
```

**The naming rule (load-bearing):** **bundle names describe what is in the bundle, not what kind of host imports it.** This is the lesson from the walked-back role taxonomy: `headless.nix` named the kind of host; its contents became a category lie. `remote-access.nix` names the capability; its contents *cannot* become a category lie because the name isn't making a category claim. A host importing `remote-access.nix` is just a host with that capability — no implied taxonomy.

Concretely, this rules out names like:

- `headless.nix` (host-kind) — what ADR-027 retired.
- `workstation.nix` (host-kind) — same problem.
- `server-bundle.nix` (host-kind by another name) — same.

And rules in names like:

- `remote-access.nix` (the capability of being reachable over SSH)
- `desktop-env.nix` (the capability of running a graphical desktop)
- `git-multi-identity.nix` (the capability of carrying multiple git identities)

Applies the existing "most-communicative term" rule (above) to the capability layer.

### Foundation: a bundle by convention

`foundation.nix` is the bundle that hosts of a given platform import by convention. It is structurally a bundle (same `bundle-purity` rule, same ≥ 2 imports, same pure aggregation) and is distinguished only by:

- **Name** — always `foundation.nix`. The name signals "this is the bundle every host imports."
- **Placement** — at the top of the platform's module tree, one level above `bundles/`:

  ```
  modules/nixos/foundation.nix       # exists
  modules/darwin/foundation.nix      # exists
  modules/shared/foundation.nix      # if a cross-platform foundation emerges
  home/nixos/foundation.nix          # home-tree foundations: conventional slots,
  home/darwin/foundation.nix         #   populated only when a platform's HM
  home/shared/foundation.nix         #   imports converge on a base (none yet)
  ```

  Placement at the top of the tree rather than inside `bundles/` is a discoverability choice: a contributor browsing the platform's module directory sees `foundation.nix` immediately.

**Why "foundation":** describes the file's *position* — the floor every host of that platform stands on. Considered alternatives (`base`, `common`, `baseline`, `essentials`, `prelude`, `bedrock`) and rejected for specific reasons in the conversation that produced ADR-027. "Foundation" won on three criteria: no collision with existing repo vocabulary (`core`, `shared`, `experimental`, `role`-now-gone); architectural metaphor that matches how hosts relate to it ("built on", not "measured against"); and conceptually neutral on its contents.

The contents convention (foundation tends to hold identity + admin + posture; other bundles hold capabilities) is a guideline about what belongs *inside* foundation, not a structural rule.

### Standalone modules

A module that lives directly at `modules/<platform>/<name>.nix` (or the home equivalent) without a `bundles/` parent. Naming follows the existing module-naming rule (role-based, tool/protocol, or collective category — pick the most communicative term for the module's contents). Standalone is the honest state for a capability that hasn't yet attracted a sibling worth grouping with — see ADR-027 for the rule-of-two trigger to promote a standalone module into a bundle.

## Why the structural naming is a separate concern

The module-naming rule (top of this document) answers "what do we call a file that configures a tool or role?". The bundle-naming rule answers "what do we call a file that *aggregates* other modules?". They intersect — both aim for the most-communicative term — but the failure modes are different: a misnamed module is a documentation problem; a misnamed bundle becomes a category lie (the role lesson). The bundle rule is therefore stricter: not "the most communicative term" but "specifically a capability term, never a host-kind term."

---

# Host naming

A distinct concern from the module/bundle naming above: that rule names *files*; this one names *hosts* (the `hosts/<name>/` directories and the machines they configure). The decision and its full rationale live in [ADR-045](./decisions/ADR-045-star-host-naming.md), which supersedes the earlier celestial-substrate framework of [ADR-038](./decisions/ADR-038-celestial-host-naming.md); it composes with [ADR-016](./decisions/ADR-016-host-identity.md) (which fixes *when* a name changes). This section is the applied rule.

## The rule

**A host's name is a star.** The pool is flat: a star name makes no operational claim about the machine — nothing in it says what the host runs, owns, or depends on. That is the point. The previous framework keyed a host's class on its substrate and made the name *promise* something; the promise hit a ceiling (the planet pool ran dry) and went dishonest (a "moon-capable" laptop that will never anchor a VM). A flat star label dissolves both: nothing to run out of, nothing to be dishonest about.

**The naming is non-binding taste, not a rule that constrains anything.** Host names drive no config — the only eval-bearing references are the `hosts/<name>/` directory and the handful of keys that move with it — so which star lands on which host is free to change. Everything below the rule is *flavour*: recorded because it is pleasant and coherent, not because anything depends on it. This composes with ADR-016: the name binds to the machine (not its software role) and is stable per physical machine.

### Flavour (non-binding)

- **Southern-hemisphere sky.** Names lean toward stars of the southern sky — the operator's sky. A preference, not a fence; northern stars are fair game.
- **A grouped site may share a constellation or cluster,** so the grouping reads at a glance. Current groupings: the main homelab as the **Pleiades**, an offsite homelab as **Centaurus**.
- **Portable devices take unattached stars** — a phone, laptop, or other device that travels with you is a lone bright star, not a member of a grouped cluster (so a future portable must not take Mimosa — β Crucis would pair with Acrux and quietly make Crux a third grouping).
- **VMs are just stars,** named ad hoc; no relational rule (ADR-045 dropped ADR-038's moon→planet binding).
- **Prospect pools** for future growth: Scorpius, Carina, and the southern birds (Grus, Pavo, Phoenix, Tucana, Apus).

The collective fleet is called **Sidera** (Latin, *the stars*) — see ADR-045.

## The fleet

> Upkeep: this section is a roadmap (live targets plus reserve and prospect pools), not a census — it is a deliberate superset of `hosts/`, so it is not bound to the host-census lint (#583). Correct the `hosts/` dir today cells at each onboarding/rename; a generated census remains the recorded end state (#583's revisit trigger; the registry-carrier question lives with #562). As of 2026-08-12 the live dirs are `alcyone`, `alnair`, `electra`, `celaeno`.

The picks below are the operator's current choices; per ADR-045 they are non-binding and roll out one host at a time, so the `hosts/<dir>` a machine lives under today can lag its target name until that host's rename lands. The re-key is complete: every live host (`alcyone`, `alnair`, `electra`, `celaeno`) sits under its star name — `neptune`'s rename and on-box macOS/tailnet cutover both verified 2026-08-12 (#804).

### Main homelab — the Pleiades

| Target name | Machine                             | `hosts/` dir today |
| ----------- | ----------------------------------- | ------------------ |
| **Alcyone** | NixOS x86_64 flagship desktop tower | `alcyone`          |
| **Celaeno** | darwin home Mac (mini)              | `celaeno`          |
| **Maia**    | mini PC (M720q)                     | — (upcoming)       |
| **Electra** | mini PC (M920q)                     | `electra`          |
| **Taygeta** | Raspberry Pi 4                      | — (upcoming)       |
| **Atlas**   | NAS (6-bay)                         | — (upcoming)       |

Reserve sisters: **Merope, Asterope, Pleione**.

### Portable devices

| Target name | Machine                   | `hosts/` dir today  |
| ----------- | ------------------------- | ------------------- |
| **Alnair**  | NixOS laptop              | `alnair`            |
| **Acrux**   | iPhone (Secure ShellFish) | — (not nix-managed) |

Reserve: **Achernar, Atria**.

### Offsite homelab — Centaurus

| Target name | Machine                                       | `hosts/` dir today |
| ----------- | --------------------------------------------- | ------------------ |
| **Hadar**   | NixOS x86_64 work + personal dev (HP ProDesk) | — (retired)        |

Reserve: **Toliman, Menkent**.
