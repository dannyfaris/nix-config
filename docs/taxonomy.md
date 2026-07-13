# Taxonomy: how files and modules are named

This document captures the naming convention applied across the
home-manager module trees (`home/shared/` and `home/nixos/`)
and the system module trees (`modules/nixos/` and
`modules/shared/`), and by extension any future module trees. The
decision itself is recorded in
[ADR-012](./decisions/ADR-012-taxonomy.md); this document is the
applied principle with examples.

> **Note:** some of the examples below reference earlier directory
> shapes (`modules/home/` and `modules/system/` from a pre-foundation
> refactor; `modules/core/...` and `home/core/...` from the pre-ADR-026
> tier-prefix era) because the rule was articulated against those trees.
> The current trees are `home/{shared,nixos,darwin}/` and
> `modules/{nixos,darwin,shared}/`
> per the PRD §5 directory grid (post-[ADR-026](./decisions/ADR-026-drop-core-tier-prefix.md),
> with the `darwin/` axis added when nix-darwin onboarded — epic #11).
> The naming rule itself applies unchanged; only the directories moved.

## The rule

**Name each file by whichever term is most communicative to a reader.**

That's the whole rule. Everything below is its application.

In practice, "most communicative" resolves to one of three name sources:

1. **Role-based names** when the role is a more universally recognised term
   than any one implementing tool.
2. **Tool/protocol names** when the tool's name *is* its role — the tool is
   the universally recognised term and abstracting away from it adds
   ambiguity rather than clarity.
3. **Collective category names** when a file groups multiple tools serving
   one role and there's no obvious single-tool umbrella.

## Examples and reasoning

### `modules/home/` (role-based)

| File | Why role-based |
|------|----------------|
| `shell.nix` | "Shell" is more universal than "fish". A reader knows what a shell is without needing to know which one. |
| `prompt.nix` | "Prompt" is the role; starship is one implementation. |
| `multiplexer.nix` | "Multiplexer" is the role; zellij is one implementation. |
| `editor.nix` | "Editor" is the role; helix is one implementation. |

### `modules/home/` (tool/protocol-named)

| File | Why tool-named |
|------|----------------|
| `git.nix` | "Git" is the universally recognised term — calling it `version-control.nix` would be more abstract but no clearer to any reader. The file contains git + gh + glab, but git is unambiguously the umbrella. |
| `ssh.nix` | "SSH" is short for "Secure Shell Protocol" — the acronym IS the role. Calling it `secure-shell.nix` is the same name, longhand. Calling it `remote-shell.nix` introduces ambiguity (could mean SSH-the-tool or remote-shell-as-a-context). |
| `direnv.nix` | "direnv" is the recognised term in nix circles. "project-envs" was considered but is less communicative than the actual tool name. |

### `modules/home/` (collective category)

| File | What it contains |
|------|------------------|
| `cli-utils.nix` | rg, fd, fzf, bat, eza, zoxide, lazygit, yazi, htop, dust — modern Unix replacements. No single tool is the umbrella; the category is. |
| `nix-tooling.nix` | nh, nom, nixd, nixfmt, statix, deadnix — six tools improving the nix dev experience. Same pattern. |
| `agent-clis.nix` | Claude Code + Cursor CLI — the always-on base. Codex + Antigravity CLI live in the sibling `agent-clis-extras.nix`, imported per-host (ADR-008, ADR-020). |

### `modules/system/` (mixed, all communicative)

| File | Naming class |
|------|--------------|
| `boot.nix`, `networking.nix`, `locale.nix` | Role names — these are universal terms for what they configure. |
| `nix.nix` | Tool name — "nix" is the universally recognised term for nix daemon settings. |
| `ssh.nix` | Protocol acronym (same reasoning as in `modules/home/`). |
| `sops.nix`, `docker.nix` | Tool names. |
| `users.nix`, `packages.nix` | Role/category names. |

## Rejected alternatives

### "All-role with forced names"

This was the first proposal: rename everything to a role name, even where the
role name was wordier than the tool name (e.g., `secure-shell.nix` for SSH,
`project-envs.nix` for direnv, `version-control.nix` for git).

**Why rejected.** Some of these names were genuinely more confusing than
their tool-name alternatives. `secure-shell.nix` reads as a context (a
collection of tools used during remote shell sessions) rather than a role (the
SSH protocol itself). `project-envs.nix` is an invented term, less recognised
than "direnv". The pursuit of consistency-for-its-own-sake produced names that
were strictly worse on the criterion that actually matters: how fast a reader
parses the name into understanding.

### "All-tool with no abstractions"

Mirror image of the above: name every file after its primary tool —
`fish.nix`, `starship.nix`, `zellij.nix`, etc.

**Why rejected.** The collective category files (`cli-utils.nix`,
`nix-tooling.nix`, `agent-clis.nix`) genuinely contain multiple parallel
tools with no umbrella tool to name them after. Picking one (e.g., naming
the cli-utils file `ripgrep.nix`) would be misleading; any name that
truthfully described the file's content would be a category name. So strict
all-tool naming isn't even achievable.

### "Decompose by lifecycle / frequency of change"

Considered: name files by how often they change (`stable.nix`, `volatile.nix`).

**Why rejected.** Lifecycle is not a meaningful axis to a reader who is trying
to find a specific configuration. Knowing that a file is stable doesn't help
you find shell configuration in it.

## What this gives us

- A reader can predict where any configuration lives without consulting an
  index.
- The tree reads as a clear taxonomy without forcing any single naming
  convention to do work it isn't suited for.
- Tool swaps are cheap (rename a file body, not a path) where the role name
  has been chosen well; they're a single-file content change otherwise.
- Inconsistency-as-honesty: the rule is a single sentence, but it produces
  three name shapes, and that's the right answer.

## Structural units: bundles, foundation, and standalone modules

The naming rule above covers *individual modules*. A separate, narrower
convention covers the *aggregator files* that compose them — introduced
by [ADR-027](./decisions/ADR-027-foundation-and-bundles.md) when the role
abstraction was walked back. The structural picture is simpler than the
three-bucket framing might suggest: there is one kind of aggregator file
(a bundle), and one naming convention (`foundation.nix`) that marks the
bundle every host imports.

### Bundles

**Name:** kebab-case, describes the capability the bundle groups
(`remote-access.nix`, `cli-tooling.nix`, `desktop-env.nix`,
`git-multi-identity.nix`).

**Location:** under a `bundles/` subdirectory per platform layer:

```
modules/nixos/bundles/remote-access.nix
home/shared/bundles/cli-tooling.nix
home/shared/bundles/git-multi-identity.nix
```

**The naming rule (load-bearing):** **bundle names describe what is in
the bundle, not what kind of host imports it.** This is the lesson from
the walked-back role taxonomy: `headless.nix` named the kind of host;
its contents became a category lie. `remote-access.nix` names the
capability; its contents *cannot* become a category lie because the name
isn't making a category claim. A host importing `remote-access.nix` is
just a host with that capability — no implied taxonomy.

Concretely, this rules out names like:

- `headless.nix` (host-kind) — what ADR-027 retired.
- `workstation.nix` (host-kind) — same problem.
- `server-bundle.nix` (host-kind by another name) — same.

And rules in names like:

- `remote-access.nix` (the capability of being reachable over SSH)
- `desktop-env.nix` (the capability of running a graphical desktop)
- `git-multi-identity.nix` (the capability of carrying multiple git identities)

Applies the existing "most-communicative term" rule (above) to the
capability layer.

### Foundation: a bundle by convention

`foundation.nix` is the bundle that hosts of a given platform import by
convention. It is structurally a bundle (same `bundle-purity` rule, same
≥ 2 imports, same pure aggregation) and is distinguished only by:

- **Name** — always `foundation.nix`. The name signals "this is the
  bundle every host imports."
- **Placement** — at the top of the platform's module tree, one level
  above `bundles/`:

  ```
  modules/nixos/foundation.nix       # exists
  modules/darwin/foundation.nix      # exists
  modules/shared/foundation.nix      # if a cross-platform foundation emerges
  home/nixos/foundation.nix          # home-tree foundations: conventional slots,
  home/darwin/foundation.nix         #   populated only when a platform's HM
  home/shared/foundation.nix         #   imports converge on a base (none yet)
  ```

  Placement at the top of the tree rather than inside `bundles/` is a
  discoverability choice: a contributor browsing the platform's module
  directory sees `foundation.nix` immediately.

**Why "foundation":** describes the file's *position* — the floor every
host of that platform stands on. Considered alternatives (`base`,
`common`, `baseline`, `essentials`, `prelude`, `bedrock`) and rejected for
specific reasons in the conversation that produced ADR-027. "Foundation"
won on three criteria: no collision with existing repo vocabulary
(`core`, `shared`, `experimental`, `role`-now-gone); architectural
metaphor that matches how hosts relate to it ("built on", not "measured
against"); and conceptually neutral on its contents.

The contents convention (foundation tends to hold identity + admin +
posture; other bundles hold capabilities) is a guideline about what
belongs *inside* foundation, not a structural rule.

### Standalone modules

A module that lives directly at `modules/<platform>/<name>.nix` (or
the home equivalent) without a `bundles/` parent. Naming follows the
existing module-naming rule (role-based, tool/protocol, or collective
category — pick the most communicative term for the module's contents).
Standalone is the honest state for a capability that hasn't yet attracted
a sibling worth grouping with — see ADR-027 for the rule-of-two trigger
to promote a standalone module into a bundle.

## Why the structural naming is a separate concern

The module-naming rule (top of this document) answers "what do we call
a file that configures a tool or role?". The bundle-naming rule answers
"what do we call a file that *aggregates* other modules?". They
intersect — both aim for the most-communicative term — but the failure
modes are different: a misnamed module is a documentation problem; a
misnamed bundle becomes a category lie (the role lesson). The bundle
rule is therefore stricter: not "the most communicative term" but
"specifically a capability term, never a host-kind term."

---

# Host naming: celestial bodies

A distinct concern from the module/bundle naming above: that rule names *files*; this one names *hosts* (the `hosts/<name>/` directories and the machines they configure). The decision and its full rationale — including the roads not taken — live in [ADR-038](./decisions/ADR-038-celestial-host-naming.md), amending [ADR-016](./decisions/ADR-016-host-identity.md) (which fixes *when* a name changes); this section is the applied rule.

## The rule

**A host's name is a celestial body, and its *substrate* picks the celestial class.** One principle underneath it: **gravitational binding mirrors operational dependency** — what a machine *is* (owned metal, rented metal, or a guest VM) decides its class.

| Substrate | Celestial class | Why it fits |
|-----------|-----------------|-------------|
| Physical machine (metal you own) | major planet, **moon-capable** | a full world with its own gravity; the VMs you pin to it orbit it as moons |
| VPS / cloud instance (someone else's metal) | major planet, **moonless** | a real standalone host, but on rented metal — barren, nothing of yours orbiting it |
| VM pinned to an owned host | a **moon** of that host's planet | the strongest gravitational tie in the scheme — it mirrors the VM's total dependence on its host metal |
| Roaming VM, or any host that fits no class above | a **minor body** — asteroid &c., the open reserve | bound to no single planet; a deliberately loose catch-all |

Whether a planet carries moons is itself the owned-vs-rented marker: your own metal can anchor pinned VMs — each of which *is* one of its moons, named after one of that host-planet's actual moons — while rented metal stays barren by choice. The minor-body reserve (asteroids, comets, dwarf planets, KBOs) is one deliberately under-specified pool for roaming VMs and any host that fits no class above; it is **not** pre-partitioned — if a reserve category recurs often enough to deserve its own rule, [ADR-038](./decisions/ADR-038-celestial-host-naming.md) is iterated then, not now. Earth is excluded by operator preference. This composes with ADR-016: the name binds to the machine, not its software role — substrate is a machine property, so it sits inside that stability rule.

## The fleet

The framework and every name below are ratified ([#368](https://github.com/dannyfaris/nix-config/issues/368)); the per-host directory renames roll out one host at a time, so the `hosts/<dir>` a machine lives under today lags its target name until that host's rename lands. The pilot — `mac-mini` → `neptune` ([#403](https://github.com/dannyfaris/nix-config/issues/403)) — has landed; `metis` → Mars is still pending (`nixos-vm`'s rename is mooted — reserve-typed per [#448](https://github.com/dannyfaris/nix-config/issues/448), and the host is retiring).

| Target name | Class | Machine | `hosts/` dir today |
|------|-------|---------|--------------------|
| **Jupiter** | moon-capable planet | NixOS x86_64 flagship desktop tower | — (not yet onboarded) |
| **Saturn** | moon-capable planet | darwin MacBook Air daily driver | `saturn` (config landed; deploy pending hardware) |
| **Mars** | moon-capable planet | NixOS x86_64 work + personal dev (ProDesk) | `metis` |
| **Neptune** | moon-capable planet | darwin home Mac | `neptune` |
| **Mercury** | moonless planet | AWS EC2 x86_64 work, headless | `mercury` (name survives) |
| *(minor-body reserve — no name minted)* | minor body (reserve) | UTM/aarch64 refinement VM on a non-host Mac; retiring | `nixos-vm` |

VPS hosts cap at two — only Mercury and Venus are moonless among the major planets (a deliberate ceiling, per ADR-038). Moon-capable planets and the minor-body reserve both scale freely; per-planet moon budgets do not (Mars has only two named moons).
