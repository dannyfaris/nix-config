# Nix Configuration: Product Requirements & Design Document

**Status:** Draft
**Author:** Dan
**Last updated:** 2026-05-14

---

## 1. Purpose and success criterion

### 1.1 What this document is

A design document for a unified Nix configuration that serves as the declarative substrate for all of Dan's primary computing environments: headless NixOS dev machines, NixOS Niri workstations, and macOS workstations. Multiple instances of each role are expected.

Audience: Dan (now and future), Claude Code (which will read this at the start of every implementation session), and any human collaborator who needs to understand the system.

### 1.2 Why this configuration exists

Dan operates across multiple machines — headless dev boxes, a Linux workstation, a MacBook Air, an incoming Mac mini — and wants them to behave as one coherent environment rather than as a collection of similar-but-drifting setups.

A unified declarative configuration delivers three things that ad-hoc setup cannot:

- **Clarity.** Decisions about how the environment should work are made once, articulated explicitly, and inspectable in one place.
- **Confidence.** Because the environment is built from a single source of truth, it behaves the way it's specified to behave — on every machine, every time it's deployed.
- **Portability.** The same environment can be rolled out wherever it's needed: a new VPS, a fresh laptop, bare metal, a VM. The investment in thinking it through pays out across every future instance.

The configuration is built so that effort spent optimising any part of the environment compounds — improvements propagate to every relevant machine, and the cost of standing up a new instance approaches the cost of running the bootstrap sequence.

### 1.3 Primary success criterion

> **Can Dan deploy his considered environment, intact and consistent, to any machine he needs it on — without reconstructing decisions in the moment?**

If yes, the configuration is doing its job. If standing up a new machine requires re-making decisions, comparing against other machines, or accepting drift, the configuration is incomplete.

### 1.4 Supporting properties

For the primary criterion to hold, the configuration must also deliver:

- **A stable core.** The load-bearing parts of the environment are reliable, well-considered, and changed deliberately. They are the substance of what gets deployed.
- **A safe surface for experimentation.** New tools and configurations can be tried in isolation from the core. Successful experiments are promoted deliberately; failed ones are removed cleanly, without residue. This is what keeps the core itself improving over time.
- **Durable design context.** Conventions, rationale, and structural rules live in the repository, not in Dan's head — enabling effective collaboration with stateless AI agents and surviving long absences.
- **Reproducible bootstrap.** Any role instance can be brought up from a clean OS via a documented, repeatable sequence.

### 1.5 Out of scope for this section

Detailed role contents, module organisation, enforcement mechanisms, and remaining design specifics are covered in §§3–11.

---

## 2. Scope

### 2.1 In scope

- Three role types: `headless`, `linux-workstation`, `macos-workstation`.
- Multiple instances per role.
- Single repository, single flake, shared module layer.
- Bootstrap from clean OS via a documented sequence.

### 2.2 Out of scope

- Platforms beyond NixOS and macOS (no Windows, no non-Niri Linux desktops, no embedded targets).
- Declarative management of macOS GUI settings beyond nix-darwin's typed options. The targeted exception is disabling per-app auto-updates, because they interact poorly with the Mosyle MDM permission-prompt flow (each auto-update triggers a self-service permission escalation that interrupts work); updates are instead consolidated through `nix-homebrew` and driven by `darwin-rebuild`.
- Data management (Obsidian vault contents, photography libraries, project repositories) — only configuration.
- iCloud-mediated state, Apple service state, or anything Apple owns at the system level.
- Replacing or duplicating tooling that already solves a problem well (e.g., browser sync, 1Password for secrets).
- Exhaustive capture of every setting on every machine — capturing intent, not state.
- Commit signing.
- `agenix` / `sops-nix`. Runtime secret access via the 1Password CLI (`op`) is sufficient for current workstation use. `headless` instances in current scope do not consume runtime secrets; if a future headless workload requires them, the mechanism (1Password service-account tokens, `sops-nix` re-introduction scoped to the role, or another option) is a decision deferred to that point (see §12).
- Tutorial or learning content — assumes working familiarity with Nix, flake-parts, and module composition.
- Use as a public template — this is Dan's configuration; generalisation is a separate project if ever undertaken.
- Build-time performance tuning beyond defaults — correctness and clarity dominate.

---

## 3. Roles and instances

### 3.1 The role-instance model

The configuration is organised around **roles**: named, reusable compositions of modules that together define what it means to be a particular kind of machine. **Hosts** are instances of roles — thin declarations that adopt a role and supply instance-specific details.

This separation means:
- Decisions about *what a kind of machine should be* are made once, in the role.
- Decisions about *which specific machine this is* live in the host file.
- Spinning up a new machine of an existing role is a matter of writing a small host file, not reconstructing role-level decisions.

### 3.2 Role composition

Roles are **independent compositions**. Each role directly imports the modules it needs from `modules/` and `home/`. Roles do not inherit from or extend each other.

Where roles need overlapping module sets (notably `headless` and `linux-workstation`), the overlap is mechanical — both role files import the same modules — not architectural. The single source of truth for shared behaviour is the module itself, not a shared parent role.

Roles are thin: their job is to compose modules. A role file contains an `imports` list and (if genuinely needed) `_module.args` — nothing else. Where a role needs to choose between alternative tools (e.g., which compositor a `linux-workstation` uses), the choice is expressed as a choice of which module to import (`./modules/core/nixos/niri.nix` vs. `./modules/core/nixos/sway.nix`), not as a `mkDefault` setting an option. This keeps roles as pure composition; tool-specific configuration lives entirely in modules.

### 3.3 The three roles

**`headless`** — A NixOS machine without a graphical environment, accessed remotely. Optimised for development work via SSH. Instances include VPS dev boxes, bare-metal Linux servers, and VMs used for transient development environments.

**`linux-workstation`** — A NixOS machine with a graphical environment, used directly. The full development environment of `headless` plus a GUI layer, compositor, desktop applications, and the visual environment for daily work. Initial instances will use the Niri compositor; this is a choice the role makes, not part of its identity.

**`macos-workstation`** — A macOS machine managed via `nix-darwin`, used directly. Provides the cross-platform development environment shared with the Linux roles, plus macOS-specific configuration: applications via `nix-homebrew`, system settings via nix-darwin's typed options, launchd agents, and per-app auto-update disabling. Mac App Store applications are out of scope for declarative management in the current design; they are installed once interactively. Initial instances are MacBook Air and Mac mini.

Detailed role contents are captured in the modules themselves; the PRD does not enumerate them.

### 3.4 Host instances

A host file is minimal. It declares:

- The role being adopted.
- Hostname and any host-identifying metadata.
- Hardware configuration (for NixOS hosts).
- Instance-specific overrides where genuinely necessary.
- Optionally, opt-in to experimental modules for that instance.

A host file should not contain inline configuration logic. If a host needs behaviour, that behaviour belongs in a module, which the host (or its role) imports.

The exact attribute shape for a host declaration is defined in §5 (Module organisation).

---

## 4. Architectural principles

The configuration is built on four load-bearing principles. Each is specified in detail in the section noted; the summary here exists for quick reference.

**4.1 Explicit composition (§5).** Role files explicitly list the modules they include; hosts adopt a role and optionally add further modules. Module bodies are pure configuration — applicability is not declared inside modules. The directory structure (`core/`-vs-`experimental/` × `shared/`-vs-`nixos/`-vs-`darwin/`) is a project-level organisational convention enforced by lint, not a framework feature.

**4.2 Roles and hosts (§3).** Roles are first-class, named compositions of modules. Hosts are thin instantiations of roles. Roles compose modules with only role-shaped wiring; tool-specific configuration lives in modules. Hosts contain only role adoption, identifying data, and optional module opt-ins (`imports`, `experimental`).

**4.3 Stability tiers (§6).** Modules occupy one of two tiers: `core` (stable, applied to all instances of a role) or `experimental` (under evaluation, scoped to individual hosts). Tier is encoded in directory structure. Core must not depend on experimental.

**4.4 Cross-platform purity (§7).** Shared modules work identically on all supported platforms by construction. Platform-specific behaviour lives in platform-specific modules. There are no platform conditionals in shared modules.

---

## 5. Module organisation

### 5.1 Directory structure

```
flake.nix
flake.lock
README.md
CLAUDE.md
docs/
  nix-config-prd.md
  philosophy.md
  taxonomy.md
  decisions/
    ADR-NNN-<slug>.md
hosts/
  <hostname>/
    default.nix              # pure declarative data
    hardware.nix             # NixOS hardware config (where applicable)
roles/
  headless.nix
  linux-workstation.nix
  macos-workstation.nix
modules/
  core/
    shared/                  # cross-platform system modules
    nixos/                   # NixOS-specific system modules
    darwin/                  # nix-darwin-specific system modules
  experimental/
    shared/
    nixos/
    darwin/
home/
  core/
    shared/                  # cross-platform Home Manager modules
    nixos/                   # Home Manager modules used only on NixOS hosts
    darwin/                  # Home Manager modules used only on macOS hosts
  experimental/
    shared/
    nixos/
    darwin/
lib/
  mk-host.nix                # host construction helper
scripts/
  lint-*.sh                  # structural enforcement
```

### 5.2 Top-level distinctions

**`modules/` vs. `home/`** — separated because they target different evaluation contexts with different option schemas. Files in `modules/` declare NixOS or nix-darwin modules (system-level: services, packages, system settings). Files in `home/` declare Home Manager modules (user-level: dotfiles, user environment, user services). A file in the wrong tree will fail evaluation.

**`core/` vs. `experimental/`** — separated to encode stability tier in the file path. Core modules are stable and may be imported anywhere. Experimental modules are under evaluation and have restricted dependency rules (see §6).

**`shared/` vs. `nixos/` vs. `darwin/`** — separated to encode platform applicability. Modules in `shared/` must work identically on all supported platforms (see §7 for the cross-platform contract). Modules in `nixos/` or `darwin/` may use platform-specific constructs freely.

This three-axis split (system vs. user, core vs. experimental, shared vs. platform-specific) makes every module's role visible from its path, and makes structural rules enforceable by path-based linting.

### 5.3 Roles

Roles live at top level in `roles/`, one file per role. A role file is a pure composition: it imports the modules the role requires and declares no inline configuration of its own. Logic lives in modules; roles compose them.

The three roles correspond directly to the three files: `roles/headless.nix`, `roles/linux-workstation.nix`, `roles/macos-workstation.nix`.

### 5.4 Hosts

Each host has a directory under `hosts/` named for the host itself.

A host's `default.nix` is a pure declarative attribute set — data, not logic:

```nix
{
  role = "linux-workstation";
  hostname = "mothership";
  system = "x86_64-linux";

  # Optional: additional core modules to import beyond what the role provides.
  # Used for host-level capabilities (e.g., `linux-builder` on a macOS host).
  imports = [
    # paths under modules/core/ or home/core/
  ];

  # Optional: experimental modules opted into for this instance
  experimental = [
    # paths under modules/experimental/ or home/experimental/
  ];
}
```

The flake's host-construction logic (in `lib/mk-host.nix`) reads these declarations, resolves the role, and produces a NixOS or nix-darwin configuration whose `imports` list is the role's modules, followed by the host's `imports`, followed by the host's `experimental`. The Nix module system merges the resulting set into the final configuration.

**On module merging.** The Nix module system does not "layer" modules in import order — option values are merged via priority (`mkDefault`, `mkForce`, `mkOverride`). Core modules set option values at default priority. Where a host import or an experimental module needs to override a value already set by the role's modules, it uses `lib.mkForce` (for a hard override) or `lib.mkOverride <priority>` with an explicit priority lower than the default. Experimental modules are not implicitly higher-priority than core; an experiment that needs to win must say so explicitly. This avoids silent merge failures where an experimental module's value loses to a default-priority core value.

Hosts must not contain inline module logic. If a host needs behaviour beyond what its role provides, that behaviour belongs in a module — added via `imports` (for a core module) or `experimental` (for a module still under evaluation).

For NixOS hosts, a `hardware.nix` sits alongside `default.nix` containing the machine's hardware configuration (generated by `nixos-generate-config` and adjusted as needed).

### 5.5 Naming conventions

**Files:** kebab-case. `fish.nix`, `git-signing.nix`, `niri-keybindings.nix`. No camelCase or snake_case for filenames.

**Module attributes:** match the filename. A module at `modules/core/shared/fish.nix` declares behaviour into the attribute path corresponding to `fish`. Mismatches are caught by lint.

**Roles:** as defined in §3 — `headless`, `linux-workstation`, `macos-workstation`. These are the only role names; new roles require updating the PRD.

**Hosts:** stable per physical machine. The host directory's name refers to a specific machine, not to its current role or purpose. A machine's software role may change without renaming. Hardware-platform changes (e.g., MacBook Air → MacBook Pro, motherboard replacement, new cloud infrastructure) are treated as a different host: a new `hosts/<name>/` directory is created with a fresh name, and the prior host directory may be retired. Existing host directories are not renamed in place. The rule is recorded in ADR-016.

Examples drawn from the initial set of hosts:
- `mothership` — the existing Linux workstation
- `mba` — the current MacBook Air
- `mac-mini` — the current Mac mini

These names are accepted under the rule: each refers unambiguously to a specific physical machine. A replacement (e.g., upgrading the MacBook Air to a MacBook Pro) gets its own host directory and a fresh name.

### 5.6 Helpers and scripts

**`lib/`** contains Nix helper functions used across modules and roles. The host-construction helper, `mk-host.nix`, lives here. Additional helpers are added when concrete need arises.

**`scripts/`** contains non-Nix shell scripts implementing the structural lint checks defined in §8, plus operational scripts that automate multi-step procedures — notably `promote.sh` and `remove.sh` for the experimental-to-core lifecycle (§6.4). Additional scripts are added when concrete need arises.

### 5.7 Decision log

Architectural decisions are recorded as ADRs in `docs/decisions/`, numbered sequentially in a single series shared with prior decisions on this repository. Each ADR follows the light format defined in `docs/decisions/README.md`:

```markdown
# ADR-NNN: <Topic> — <Choice>

**Date**: YYYY-MM-DD
**Status**: Accepted | Superseded by ADR-NNN

## Context
## Decision
## Rationale
## Consequences
- ✓ ...
- ✗ ...
- ⚠ migration trigger ...
## Implementation
```

ADRs capture decisions with rationale, and serve as live design context — readable by humans and by AI agents working on the configuration.

The ADRs introduced alongside this PRD:

```
docs/decisions/
  ADR-013-composition-framework.md
  ADR-014-independent-roles.md
  ADR-015-tier-as-directory.md
  ADR-016-host-identity.md
```

Earlier ADRs (`ADR-001` through `ADR-012`) record decisions made during the prior iteration of the repository; they remain in `docs/decisions/` as historical record. Some are superseded by the new design and will have their `Status` updated to point to the superseding ADR as the new modules are built out.

---

## 6. Stability tiers

### 6.1 The two tiers

**Core.** Stable, proven modules. Imported by roles and applied to every instance of the relevant role. Changes to core are deliberate.

**Experimental.** Modules under evaluation. Scoped to individual host instances via the host's `experimental` attribute. Never imported by roles. May be promoted to core or removed at any time, both via explicit decision (see §6.4).

A `deprecated/` tier is not part of the current design. Failed experiments are removed; superseded core modules are replaced or deleted directly. The tier can be added later if a phase-out path is ever needed.

### 6.2 Dependency rules

- Core modules MUST NOT import experimental modules.
- Experimental modules MAY import core modules.
- Roles import only core modules. Experimental modules are opted into at the host level.

These rules are enforced by the `tier-deps` invariant (§8.1).

### 6.3 Scoping

Experimental modules are scoped to specific host instances, not to roles. A host opts in by listing the experimental module's path in its `experimental` attribute (see §5.4).

This means:
- A new host of an existing role does not inherit the in-flight experiments of any other host.
- An experiment can be tried on one machine without affecting any other.
- Promotion to core is what makes a module apply to all instances of a role.

### 6.4 Promotion and removal

Both promotion and removal are explicit, deliberate decisions made through a review. They are never the result of drift, inaction, or accumulation.

The review is conducted by Dan. Its cadence, format, and triggers are at his discretion.

Both procedures are scripted to keep the action atomic — a partial promotion (file moved but role import not added) is the failure mode to design against.

#### Promotion procedure

`scripts/promote.sh <module-path>` performs:

1. Move the file from `modules/experimental/<platform>/` to `modules/core/<platform>/` (or the equivalent for `home/`).
2. Add the module to the relevant role(s), so it applies to all instances of that role.
3. Remove the experimental opt-in from any host's `experimental` attribute.

The author then commits the result with a message that captures the promotion and the rationale:

```
promote: <module-name> from experimental to core

<brief rationale: what was being evaluated, why it earned promotion>
```

#### Removal procedure

`scripts/remove.sh <module-path>` performs:

1. Delete the file from `modules/experimental/<platform>/` (or `home/experimental/<platform>/`).
2. Remove the experimental opt-in from any host's `experimental` attribute.

The author then commits the result with a message that captures the removal and what was learned:

```
remove: <module-name> from experimental

<brief rationale: what was tried, why it didn't earn promotion, what was learned>
```

The "what was learned" matters. A failed experiment is a learning artefact. The commit message is where that learning is recorded.

### 6.5 Records

Experiments and their outcomes are recorded in commit history. The combination of file location (promotion = file move, removal = file deletion) and commit message captures what was tried, when, on which hosts, and how it resolved.

Experiments do not generate ADRs by default. ADRs are reserved for architectural decisions; most experiments are not architectural in nature. An experiment whose outcome *is* architectural — for example, replacing a foundational tool across all roles — would generate an ADR for that decision, but the ADR is about the architectural shift, not the experimental process that led to it.

---

## 7. Cross-platform contract

### 7.1 The contract

A module under `modules/*/shared/` or `home/*/shared/` MUST work identically on all supported platforms (`x86_64-linux`, `aarch64-linux`, `aarch64-darwin`, and `x86_64-darwin` if used) by construction. The shared module's behaviour does not depend on which platform it is evaluated for.

This is enforced by the `shared-purity` invariant (§8.1). The lint catches platform conditionals (the most common violation), but it is necessary, not sufficient: references to platform-specific package attributes (e.g., `pkgs.linuxPackages.something`) are not detected by the lint. These would still fail at build time on the affected platform via the `hosts-build` invariant (§8.1 #7).

### 7.2 What "shared" means in practice

The shared trees hold configuration that is genuinely platform-agnostic. Examples drawn from the current toolchain:

- Shell configuration (Fish: aliases, abbreviations, functions, prompt configuration)
- Git configuration
- Terminal multiplexer configuration (Zellij)
- CLI tool configuration (`bat`, `ripgrep`, `fzf`, `direnv`, `starship`, etc.)
- Cross-platform development tooling (language toolchains, package managers' user-level config)

The unifying property: the configuration target is a tool that exists with identical user-facing behaviour on every supported platform, and the configuration itself doesn't reference platform-specific paths, services, or constructs.

### 7.3 Allowed in shared modules

- Configuration that is literally identical across platforms.
- References to packages that exist with the same attribute path on all target platforms.
- Conditional logic based on user choice or role, not on platform.

### 7.4 Forbidden in shared modules

- Platform checks of any form: `pkgs.stdenv.isDarwin`, `pkgs.stdenv.isLinux`, `stdenv.hostPlatform.is*`, or equivalents.
- `lib.optionals`, `lib.mkIf`, or similar constructs keyed on platform.
- Imports of platform-specific modules.
- References to platform-specific paths (e.g., `/Library/`, `/etc/nixos/`, `/System/`).
- Any other construct whose presence implies the module's behaviour depends on platform.

There are no exceptions. If a module has any platform-dependent behaviour, it does not belong in `shared/`. Split it into platform-specific modules instead.

### 7.5 Allowed in platform-specific modules

Modules under `modules/*/nixos/`, `modules/*/darwin/`, `home/*/nixos/`, and `home/*/darwin/` may use any construct appropriate to their platform. Within these trees, platform-specific options, paths, services, and package references are unrestricted.

### 7.6 What is not a platform difference

Some differences between hosts look platform-shaped but are not, and must not be treated as such:

- **Role differences.** A NixOS host with a graphical environment and a NixOS host without one are both NixOS; the difference is the role, not the platform. The split between `headless` and `linux-workstation` lives at the role level, not the module level.
- **Capability differences.** A macOS host with `linux-builder` configured can build Linux derivations; a macOS host without it cannot. This is a capability of the specific instance, not a platform distinction. Host-level capabilities are added via the host's `imports` (§5.4), not by platform conditionals.
- **Hardware differences.** Architecture (`aarch64` vs `x86_64`) is part of the platform tuple, but within a single platform family (e.g., both `aarch64-linux` and `x86_64-linux` are NixOS) the architecture is rarely a module-level concern. Hardware-specific configuration lives in the host's `hardware.nix`, not in module trees.

The `shared/`-vs-`nixos/`-vs-`darwin/` split is about the *operating system the module's options target*. Other axes of variation are handled by role composition or host-level configuration, not by the cross-platform contract.

---

## 8. Structural invariants and enforcement

Every convention that admits a deterministic test is encoded as an automated check. The list below defines the invariants the configuration must satisfy. Each invariant has a stable rule name, which is referenced in lint failure messages so that an agent failing a check can map the error back to the rule and its rationale in `CLAUDE.md`.

### 8.1 Invariants

| # | Rule name | Invariant | Enforcement |
|---|-----------|-----------|-------------|
| 1 | `shared-purity` | No platform conditionals (`isDarwin`, `isLinux`, `stdenv.is*`, platform-keyed `optionals`, references to platform-specific paths) appear in any file under `modules/*/shared/` or `home/*/shared/`. Necessary but not sufficient — see §7.1. | `scripts/lint-shared-purity.sh` |
| 2 | `tier-deps` | No file under `modules/core/` or `home/core/` imports from `modules/experimental/` or `home/experimental/`. | `scripts/lint-tier-deps.sh` |
| 3 | `filename-kebab-case` | All `.nix` filenames are kebab-case (no camelCase, no snake_case). | `scripts/lint-filename-kebab-case.sh` |
| 4 | `role-purity` | Role files (in `roles/`) contain only an `imports` list and, if needed, `_module.args` at the top level. No `mkDefault` selections, no inline option setting. A role-level choice between alternative tools is expressed as a choice of which module to import. Values in `imports` resolve to module paths under `modules/core/` or `home/core/`, or to other role files. | `scripts/lint-role-purity.sh` |
| 5 | `host-purity` | Host `default.nix` files contain only the declared attribute set (`role`, `hostname`, `system`, `imports`, `experimental`) and no inline module logic. Values in `imports` resolve to paths under `modules/core/` or `home/core/`; values in `experimental` resolve to paths under `modules/experimental/` or `home/experimental/`; no path appears in both attributes. | `scripts/lint-host-purity.sh` |
| 6 | `flake-evaluates` | The flake evaluates without errors. A module placed under the wrong tree (a Home Manager module under `modules/`, a NixOS module under `home/`) fails evaluation here. Errors from this invariant come from Nix directly and do not follow the `[<rule-name>]` format. | `nix flake check` |
| 7 | `hosts-build` | Every host configuration that the current machine can build natively, builds. Cross-platform builds may run via `linux-builder` on macOS hosts but are not required. | `nix build .#<host>` per applicable host |
| 8 | `format` | All Nix code is formatted. | `nixfmt` (RFC 166 official) |
| 9 | `lint-statix` | No Nix anti-patterns. | `statix` |
| 10 | `lint-deadnix` | No dead Nix code. | `deadnix` |

Three invariants from earlier drafts were dropped after review:

- `path-applicability`: the path encodes tier and platform compatibility; the module body has no separate applicability declaration to cross-check. The `shared-purity` invariant already enforces the only meaningful path-vs-content rule (see ADR-013).
- `module-headers`: the structured header was duplicating information already encoded in the path. Authors may optionally lead a module with a single-line purpose comment as a soft convention, not a lint rule.
- `tree-purity`: collapsed into `flake-evaluates` — a misplaced module is itself an evaluation failure, and the two are caught by the same `nix flake check` invocation. Pretending they're separate invariants suggested distinct error formats that don't exist in practice.

### 8.2 Enforcement integration

Invariants run in **two stages**, split by cost:

| Stage | Hook | Contents | Typical duration |
|---|---|---|---|
| Pre-commit | `pre-commit` | `nixfmt`, `statix`, `deadnix`, all `scripts/lint-*.sh` structural rules | under 10 seconds |
| Pre-push | `pre-push` | `nix flake check` (evaluation), then `nix build .#<host>` for each host the current machine can build natively | seconds to minutes |

Pre-commit stays fast — formatter + linters + path-based structural scripts only, no Nix evaluation — so `--no-verify` remains an emergency tool rather than a routine bypass. Pre-push pays the evaluation and build cost once per push, at the natural boundary for "this change is going somewhere a real machine might pull it from."

Both hook layers are declared inside the flake using `git-hooks.nix`, so hook setup is itself declarative and bootstrapped automatically on new machines.

An additional manual entry point, `nix run .#verify`, runs the full check set (pre-commit + pre-push contents together) on demand. This is the command an AI agent invokes when working without a human-driven commit/push rhythm, and the command a human invokes before doing anything risky.

### 8.3 Failure messages

Every lint script emits failure messages in a consistent format:

```
[<rule-name>] <file>: <specific failure>
See CLAUDE.md § <rule-name> for rationale and correction guidance.
```

This format gives an agent failing a check the rule name (for documentation lookup), the file (for direct correction), and a specific failure description (for the actual fix). The pointer to `CLAUDE.md` closes the loop: every rule has a corresponding section in `CLAUDE.md` describing what it enforces, why, and how to satisfy it.

### 8.4 Judgment-based conventions

Conventions that cannot be deterministically tested — module naming descriptiveness, comment quality, the right scope for a single module, when to split — are documented in `CLAUDE.md` as guidelines rather than enforced as invariants. Their function is to inform decisions during authoring and review; their absence from this list is deliberate.

---

## 9. Tooling and workflow

### 9.1 Formatter

`nixfmt` (the official RFC 166 formatter) is the canonical Nix formatter for this configuration. All `.nix` files are formatted with `nixfmt` and the formatting is enforced as an invariant (§8.1 #8). Alternative formatters (notably `alejandra`) were considered; nixfmt was chosen for its status as the official, RFC-tracked tool — the cost of being on the official formatter is near-zero, and "officially canonical" is preferable for a configuration designed for long-horizon stability.

### 9.2 Linters

- **`statix`** flags Nix anti-patterns. Enforced as invariant §8.1 #9.
- **`deadnix`** flags dead Nix code (unused bindings, unused function arguments). Enforced as invariant §8.1 #10.

Both are run as part of the pre-commit hook chain.

### 9.3 Structural lint scripts

Custom structural rules from §8.1 are implemented as shell scripts under `scripts/lint-*.sh`. Each script enforces a single invariant, named after the invariant's rule name. Failures emit the standardised message format defined in §8.3.

### 9.4 Hook framework

Pre-commit and pre-push hooks are declared inside the flake using `git-hooks.nix`. This makes hook configuration declarative and ensures hooks are bootstrapped automatically on every machine that activates the configuration.

The two stages execute as defined in §8.2: pre-commit runs fast checks plus evaluation; pre-push runs the host builds. Any failure aborts the corresponding git operation. The `nix run .#verify` flake app runs the full set on demand.

### 9.5 Continuous integration

CI is deferred. The local hook chain, combined with builds via `linux-builder` on macOS hosts (§8.1 #7), provides the verification needed during initial build-out.

CI may be added later, once multiple machines are in active use, to provide cross-platform coverage that local hooks cannot. The decision and configuration are not part of this PRD.

### 9.6 AI agent integration

`CLAUDE.md` at the repository root is the canonical documentation of conventions and enforcement for AI agents working on the configuration. It contains:

- The architectural principles (§4)
- The cross-platform contract (§7)
- Every structural invariant (§8.1) with its rule name, what it enforces, and how to satisfy it
- The stability tier workflow (§6.4)
- Judgment-based conventions that inform authoring decisions (§8.4)
- Pointers to this PRD and ADRs for deeper rationale

Hook failures reference rules by name (§8.3), allowing the agent to map errors back to the relevant section of `CLAUDE.md` and self-correct.

### 9.7 Daily workflow

The design-level workflow for routine changes:

1. **Edit** the relevant module, role, or host file.
2. **Commit.** Pre-commit runs fast structural checks only (formatter, linters, path-based lint scripts). Any failure aborts the commit with a rule-named error message.
3. **(Optional) Verify locally** with `nix run .#verify` if making non-trivial changes — this runs the full check set (evaluation + host builds) without waiting for push.
4. **Push.** Pre-push runs `nix flake check` (evaluation) then `nix build .#<host>` for each host the current machine can build natively. Any failure aborts the push.
5. **Rebuild** the machine (`darwin-rebuild switch` or `nixos-rebuild switch` against the flake) to apply the change.
6. **Verify** the change behaves as expected.

For experimental modules: the workflow includes opting the module into a host's `experimental` attribute before rebuild. For promotion or removal: use `scripts/promote.sh` or `scripts/remove.sh` (§6.4).

Operational detail — exact commands, troubleshooting steps, recovery from failed activations — lives in `CLAUDE.md` and the repository README, not in this PRD.

---

## 10. Testing strategy

The testing strategy is scoped deliberately. It covers what can be verified deterministically before code reaches a running machine: evaluation, build, and structural correctness. Runtime behaviour, activation effects, and end-to-end system tests are out of scope.

This section frames the strategy at the design level. The specific checks and tooling that implement it are defined in §8 and §9.

### 10.1 In scope

- **Evaluation.** `nix flake check` confirms the flake's outputs are well-formed and that all modules and configurations evaluate without error.
- **Build.** Native builds via `nix build .#<host>` confirm each host configuration produces a valid system closure. Cross-platform builds via `linux-builder` on macOS hosts extend this coverage to NixOS configurations.
- **Structural.** Custom lint scripts (§8.1, §9.3) enforce the structural invariants that cannot be caught by evaluation or build.

### 10.2 Out of scope

- **End-to-end activation testing in VMs.** NixOS supports `nixos-rebuild build-vm`, which could catch a narrow class of activation-time failures (service ordering, mount points, first-boot effects) that `nix build` alone does not. The class is small in practice — anything that builds clean usually activates clean — and for failures that do slip through, rollback (§11.4) recovers cleanly and without network. The added harness is not worth the maintenance cost for current scope. nix-darwin has no equivalent harness in any case.
- **Property-based testing of module composition.** The structural invariants in §8 cover the cases that matter; introducing property-based testing would add tooling without proportional return for a personal configuration.
- **Runtime behaviour testing.** Whether a configured tool actually works as intended on a running system is verified manually, not automatically.

### 10.3 Local verification

The hook chain (§8.2) runs the in-scope check set across commit and push. A clean pre-push pass is the standard for "this change is safe to roll out." See §9.4 for the integration model.

### 10.4 Pre-activation verification

Before activating changes on a real machine, build (not switch) first:

```
nix build .#<host>
```

If the build succeeds, activate:

```
darwin-rebuild switch --flake .#<host>     # macOS
sudo nixos-rebuild switch --flake .#<host> # NixOS
```

This separates "does it build?" from "does it activate?" — the former is safe to verify at any time; the latter changes system state.

Recovery procedures for failed activations are defined in §11.

---

## 11. Bootstrap and recovery

### 11.1 Bootstrap intent

Standing up a new instance of any role from a clean operating system is a documented, repeatable sequence. The configuration provides the target state; the bootstrap sequence brings a machine from its starting condition to that target.

The exact commands for each scenario live in the repository README and `CLAUDE.md`. This section documents the design.

### 11.2 Bootstrap phases

For any host, bootstrap consists of the same conceptual phases:

1. **Provide Nix.** Install Nix on the target machine, with flakes and the `nix-command` experimental feature enabled. The installer used should be the Determinate Systems installer with the upstream Nix variant (not Determinate Nix).
2. **Provide the repository.** Clone this repository onto the target machine. On NixOS hosts being installed from scratch, this may happen as part of the install process.
3. **Activate.** Run the appropriate rebuild command (`darwin-rebuild switch` or `nixos-rebuild switch`) against the flake, targeting the specific host configuration.
4. **Authenticate.** Sign into 1Password on the new machine to make runtime secrets available to the configured environment.
5. **Verify.** Confirm the activated environment matches expectations.

### 11.3 Per-role notes

**`macos-workstation`:** Install Nix on the existing macOS install, clone, activate via `nix run nix-darwin -- switch`. After first activation, `darwin-rebuild` is available on `PATH`. Homebrew components are activated as part of the flake. Mac App Store applications, if used, are installed manually after bootstrap — they are out of scope for declarative management in current design.

**`linux-workstation`:** Bootstrap from a fresh NixOS install (via ISO). In-place migration from non-NixOS Linux distributions is not supported by this configuration; existing non-NixOS machines must be reinstalled.

**`headless`:** Bootstrap requires installing NixOS onto a target machine (typically a VPS or bare-metal server). The specific bootstrap tool and declarative disk-layout approach are deferred until the first concrete `headless` instance is provisioned. The decision is recorded in §12.

### 11.4 Rollback

NixOS and nix-darwin both maintain a list of generations — each activation produces a new generation, addressable by number.

Rollback paths:

- **Last activation broke something:** `darwin-rebuild --rollback` or `sudo nixos-rebuild --rollback` reverts to the previous generation.
- **An earlier generation is needed:** `--list-generations` shows the history; `--switch-generation <N>` reverts to a specific one.
- **The flake itself is broken:** `git revert` the offending commit and re-activate from the working state.

Rollback is reliable because it reverts to a complete prior generation, not a partial state. The `--rollback` and `--switch-generation` operations work entirely from local generations and require no network — so even a botched activation that breaks networking, package fetch, or DNS can still be recovered from the affected machine itself.

### 11.5 Disaster recovery

The configuration is recoverable from two stores:

- **The flake** lives in the canonical Git repository (GitHub or equivalent).
- **Secrets** live in 1Password, accessed at runtime via `op` and never materialised to the configuration itself.

Recovering a machine after total loss is the same operation as bootstrapping a new one:

1. Provision a clean OS install matching the role's platform.
2. Run the bootstrap sequence (§11.2) for the appropriate host.

Data — Obsidian vault contents, photography libraries, project repositories — is explicitly out of scope (§2.2) and is recovered separately via its own backup mechanisms.

### 11.6 The bus-factor test

A successful design produces a configuration that another competent operator (familiar with Nix at a general level, given access to the repository and 1Password) can rebuild from in an afternoon. This is the operational standard the bootstrap design serves.

For `macos-workstation` and `linux-workstation` roles, this test holds today. For `headless`, it holds once the bootstrap tool decision (§11.3) is made.

---

## 12. Deferred decisions

Design decisions that have been deliberately deferred. Decisions resolved during PRD drafting are documented in the relevant section above and not duplicated here.

**Bootstrap path for `headless` instances.** Options include `nixos-anywhere` (paired with `disko` for declarative disk layout), vendor-provided NixOS images, or other approaches. To be evaluated when the first headless instance is required, informed by the specific vendor and use case at that time. The disk-layout approach is coupled to this decision.

**Runtime secrets on `headless` instances.** Per §2.2, current scope doesn't require runtime secrets on headless hosts. When the first headless workload requires secrets, the mechanism (1Password service-account tokens with a bootstrap-provisioned token, `sops-nix` re-introduced for the headless role only, or another option) is to be chosen at that point and recorded as an ADR.

**Continuous integration.** Deferred per §9.5. May be added once cross-platform coverage becomes valuable.

---

**End of document.**
