# Nix Configuration: Product Requirements & Design Document

**Status:** Draft
**Author:** Dan
**Last updated:** 2026-05-14

---

## 1. Purpose and success criterion

### 1.1 What this document is

A design document for a unified Nix configuration that serves as the declarative substrate for all of Dan's primary computing environments: headless NixOS dev machines, NixOS Niri workstations, and macOS workstations. Multiple instances of each host shape are expected.

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
- **Reproducible bootstrap.** Any host can be brought up from a clean OS via a documented, repeatable sequence.

### 1.5 Out of scope for this section

The composition model, module organisation, enforcement mechanisms, and remaining design specifics are covered in §§3–11.

---

## 2. Scope

### 2.1 In scope

- Two platforms: NixOS (`x86_64-linux`, `aarch64-linux`) and macOS (`aarch64-darwin`).
- Three host shapes expected to recur: headless NixOS, NixOS workstation (with desktop environment), macOS workstation. These are descriptive groupings, not enforced categories — hosts are composed from foundation + bundles + standalone modules (§3), and shape is what the composition adds up to.
- Multiple hosts per shape.
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
- `agenix` / `sops-nix`. Runtime secret access via the 1Password CLI (`op`) is sufficient for current workstation use. Headless hosts in original scope did not consume runtime secrets; this changed with the first concrete headless host (Mercury, ADR-018), which adopted `sops-nix` for the user password hash. Subsequent secret-consumption decisions are per-host: see ADR-018 and the bus-factor / Option-C deliberations in TODO.
- Tutorial or learning content — assumes working familiarity with Nix, flake-parts, and module composition.
- Use as a public template — this is Dan's configuration; generalisation is a separate project if ever undertaken.
- Build-time performance tuning beyond defaults — correctness and clarity dominate.

---

## 3. Composition model

### 3.1 The model

A host's configuration is composed from two kinds of import targets:

- **Bundles** — aggregator files whose body is an `imports` list naming two or more modules toward one coherent named capability. Hosts opt in by importing the bundle.
- **Standalone modules** — capability modules a host imports directly when no natural bundle home has yet emerged for them. They graduate to bundle membership when a coherent sibling appears (rule of two).

One bundle per platform — named `foundation.nix` and placed at the top of the platform's module tree — is imported by every host of that platform by convention. Foundation is structurally a bundle (same `bundle-purity` rule applies); it is distinguished from other bundles only by its conventional universal-import status and by placement at the top of the tree rather than inside `bundles/`. See [ADR-027](./decisions/ADR-027-foundation-and-bundles.md) for the design rationale.

This composition means:
- Decisions about *what every host of a platform needs unconditionally* are made once, in the platform's `foundation.nix`.
- Decisions about *what a host does* are expressed as the bundles and standalone modules it imports.
- Spinning up a new host is a matter of writing a small host file that imports `foundation.nix` plus the bundles and standalone modules its purpose requires.

Roles — as a single-word categorical label for a host's purpose — are not part of the model. The role abstraction was tried and walked back in ADR-027; a host's purpose is described by its composition, not by a category name.

### 3.2 Foundation

Each platform has a `foundation.nix` at `modules/core/<platform>/foundation.nix` (and, where applicable, `home/core/<platform>/foundation.nix`). Its contents are whatever modules are unconditionally true of every host the platform serves — typically:

- **Identity** — the user(s) the host runs as, the host's secrets-decryption wiring, and other "this host is one of ours" attributes.
- **Administration** — Nix daemon settings, locale/timezone, the unfree-package whitelist, baseline admin packages.
- **Posture** — security defaults (firewall, login policies) that apply unconditionally.

Foundation should stay honestly minimal: it is reserved for things that aren't opt-in capabilities. A capability — even one every current host happens to want — belongs in a capability bundle, not in foundation. The "every host imports it today" property is a fleet snapshot, not a reason to fold the capability into foundation.

Structurally, foundation is a bundle. The `bundle-purity` rule (§8.1) applies to it uniformly (≥ 2 imports, pure aggregation, no inline configuration). Placement at the top of the platform tree, rather than inside `bundles/`, is a discoverability convention reflecting its conventional universal-import status — not a separate structural layer.

### 3.3 Capability bundles

A bundle is a file at `modules/core/<platform>/bundles/<name>.nix` (or `home/core/<platform>/bundles/<name>.nix`). Its body is an `imports` list naming two or more modules toward a coherent named capability.

Bundle names describe what is in the bundle, not what kind of host imports it. Illustrative examples (final decomposition lives in slice 2 of the role-removal migration):

- `remote-access` — sshd + mosh + ghostty.terminfo
- `cli-tooling` — shell + prompt + direnv + multiplexer + editor + cli-utils + nix-tooling
- `agent-clis-base` — claude-code + cursor-cli
- `desktop-env` — niri + greetd + desktop-fonts + electron-wayland + libsecret (system side); foot + niri user-config + the per-tool selections from `docs/desktop/` (home side)
- `container-runtime` — rootless docker daemon + CLI

A bundle exists when it groups two or more modules. Single-module "bundles" are forbidden; the underlying capability stays a standalone module (§3.1, second bullet) until a sibling joins it. The pre-wrapping trap is the same forecast-driven abstraction the role layer fell into and is rejected for the same reason.

Bundles are flat: they import modules, not other bundles. A bundle-of-bundles is not part of this model.

### 3.4 Host instances

A host file declares:

- Identifying metadata: hostname, platform tuple, hardware configuration (for NixOS hosts).
- An `imports` list naming `foundation.nix`, plus the bundles and standalone modules the host composes. Experimental modules (under `modules/experimental/` or `home/experimental/`) opted into for this instance appear in the same `imports` list, distinguished by their path prefix.
- Instance-specific option overrides where genuinely host-specific (see below).

A host file may contain inline option overrides where the override is genuinely instance-specific and would be a category mistake to place in a shared module. The test: would moving this override into foundation or a bundle apply it to hosts that shouldn't have it? If yes, the host file is the right home. Concrete examples from current hosts:

- AWS-image conflicts (`ec2.efi = true`) — only the AWS host has the conflict.
- Hardware-specific swap sizing (`swapDevices`, `zramSwap` size) — sized for the specific machine's RAM and storage.
- Memory-pressure policy (`systemd.oomd.enableUserSlices`) — opted into per host based on its workload.
- Kernel parameters tuned for the host (`boot.kernel.sysctl.*`).
- Module conflict resolution via `lib.mkForce` where the conflicting module is imported only by this host (e.g., overriding amazon-image's `PermitRootLogin` default).

What remains forbidden in host files: inline conditional logic, helper function definitions, derivation definitions, or anything that would belong in a reusable module. The `host-purity` invariant (§8.1) enforces this.

The exact attribute shape for a host declaration is defined in §5 (Module organisation).

---

## 4. Architectural principles

The configuration is built on four load-bearing principles. Each is specified in detail in the section noted; the summary here exists for quick reference.

**4.1 Explicit composition (§5).** Hosts and bundles explicitly list the modules they include. Module bodies are pure configuration — applicability is not declared inside modules. The directory structure (`core/`-vs-`experimental/` × `shared/`-vs-`nixos/`-vs-`darwin/`) is a project-level organisational convention enforced by lint, not a framework feature.

**4.2 Foundation, bundles, and hosts (§3).** A host's configuration is composed from bundles (aggregator files importing two or more modules toward a coherent capability) and standalone modules (capability modules without a bundle home yet). One bundle per platform, named `foundation.nix` and placed at the top of the platform's module tree, is imported by every host of that platform by convention; structurally it is a bundle like any other. Host files contain identifying data, an `imports` list naming the foundation, bundles, and standalone modules they compose, and instance-specific option overrides where genuinely host-specific (see §3.4 for the test).

**4.3 Stability tiers (§6).** Modules occupy one of two tiers: `core` (stable, available to foundation and bundles) or `experimental` (under evaluation, scoped to individual hosts). Tier is encoded in directory structure. Core must not depend on experimental.

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
    default.nix              # imports list + identifying data
    disko.nix                # declarative disk layout (NixOS hosts; see ADR-023)
    hardware-configuration.nix  # auto-generated NixOS hardware probe (see ADR-023)
modules/
  core/
    shared/                  # cross-platform system modules
      foundation.nix         # (if cross-platform foundation emerges)
      bundles/               # cross-platform bundles
    nixos/                   # NixOS-specific system modules
      foundation.nix         # unconditional baseline for every NixOS host
      bundles/               # NixOS-specific bundles
    darwin/                  # nix-darwin-specific system modules
      foundation.nix         # unconditional baseline for every macOS host
      bundles/               # Darwin-specific bundles
  experimental/
    shared/
    nixos/
    darwin/
home/
  core/
    shared/                  # cross-platform Home Manager modules
      foundation.nix
      bundles/
    nixos/                   # Home Manager modules used only on NixOS hosts
      foundation.nix
      bundles/
    darwin/                  # Home Manager modules used only on macOS hosts
      foundation.nix
      bundles/
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

This three-axis split (system vs. user, core vs. experimental, shared vs. platform-specific) makes every module's purpose visible from its path, and makes structural rules enforceable by path-based linting.

### 5.3 Bundles and standalone modules

**Bundles** are aggregator files whose body is an `imports` list naming two or more modules toward one coherent named capability. They live under `modules/core/<platform>/bundles/` (and the parallel home tree). Bundle filenames describe the capability (`remote-access.nix`, `cli-tooling.nix`, `desktop-env.nix`). Bundle files contain no inline configuration — logic lives in the modules they import.

**Foundation** is the bundle that hosts of a given platform conventionally always import. It lives at `modules/core/<platform>/foundation.nix` (and the parallel home tree), one level above `bundles/`. Placement at the top of the platform tree is a discoverability convention reflecting its universal-import status. Structurally it is governed by the same `bundle-purity` rule as any other bundle.

**Standalone modules** sit at the top of their platform directory (e.g. `modules/core/nixos/btrfs-scrub.nix`) and are imported directly by the hosts that want them. A standalone module graduates to a bundle when a second module joins it under a coherent capability label.

The bundles-vs-standalone-modules distinction is mechanical (bundles aggregate ≥ 2 modules; standalone modules don't aggregate at all). The foundation-vs-other-bundles distinction is purely conventional (foundation is the one bundle every host imports; placement and name signal that). One structural rule — `bundle-purity` (§8.1) — covers all aggregator files; modules are just modules.

### 5.4 Hosts

Each host has a directory under `hosts/` named for the host itself.

A host's `default.nix` is a thin module: identifying data plus an `imports` list naming the foundation, bundles, and standalone modules the host composes.

```nix
{ inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    inputs.disko.nixosModules.disko

    # Foundation — every NixOS host imports this.
    ../../modules/core/nixos/foundation.nix

    # Capability bundles this host opts into.
    ../../modules/core/nixos/bundles/remote-access.nix
    ../../modules/core/nixos/bundles/local-linux-platform.nix
    ../../modules/core/nixos/bundles/container-runtime.nix
    ../../home/core/shared/bundles/cli-tooling.nix
    ../../home/core/shared/bundles/agent-clis-extras.nix

    # Standalone modules (no bundle home yet).
    ../../modules/core/nixos/btrfs-scrub.nix

    # Optional: experimental modules opted into for this instance.
    # ../../modules/experimental/nixos/<name>.nix
  ];

  networking.hostName = "mothership";
  system.stateVersion = "25.11";

  # Per-host values consumed by home-manager modules.
  _module.args.hostContext = { /* ... */ };
}
```

The flake's host-construction logic (in `lib/mk-host.nix`) is a thin wrapper around `nixpkgs.lib.nixosSystem` (or the nix-darwin equivalent): it wires `inputs` as a `specialArg` and imports the third-party flake-modules (home-manager, sops-nix). The user's modules — foundation, bundles, standalone modules — are imported explicitly by the host file itself, where they can be read top-to-bottom as a manifest of what the host is doing.

**On module merging.** The Nix module system does not "layer" modules in import order — option values are merged via priority (`mkDefault`, `mkForce`, `mkOverride`). Core modules set option values at default priority. Where a host or experimental module needs to override a value already set by a foundation or bundle module, it uses `lib.mkForce` (for a hard override) or `lib.mkOverride <priority>` with an explicit priority lower than the default. Experimental modules are not implicitly higher-priority than core; an experiment that needs to win must say so explicitly. This avoids silent merge failures where an experimental module's value loses to a default-priority core value.

Hosts must not contain inline module *logic* (helper definitions, `let`-bound logic, derivations). Instance-specific option overrides are permitted where the override is genuinely host-specific per §3.4's test. If a host needs reusable behaviour beyond what foundation + its imported bundles provide, that behaviour belongs in a module — imported directly (if standalone) or added to a bundle (if it shares a coherent capability with an existing module).

For NixOS hosts installed via `nixos-anywhere` (ADR-022), the per-host directory follows a three-file convention (ADR-023): `default.nix` (hand-authored logical config), `disko.nix` (declarative disk layout), and `hardware-configuration.nix` (auto-generated by `nixos-anywhere --generate-hardware-config`, committed verbatim, never hand-edited).

### 5.5 Naming conventions

**Files:** kebab-case. `fish.nix`, `git-signing.nix`, `niri-keybindings.nix`. No camelCase or snake_case for filenames.

**Module attributes:** match the filename. A module at `modules/core/shared/fish.nix` declares behaviour into the attribute path corresponding to `fish`. Mismatches are caught by lint.

**Bundles:** kebab-case, named after the capability they group (`remote-access.nix`, `cli-tooling.nix`, `desktop-env.nix`). Do not name bundles after the kind of host that imports them — that's the role-shaped category claim that ADR-027 walked back. A bundle name should describe what is *in* the bundle, not what kind of host *uses* it.

**Hosts:** stable per physical machine. The host directory's name refers to a specific machine, not to its current purpose. A machine's software composition may change without renaming. Hardware-platform changes (e.g., MacBook Air → MacBook Pro, motherboard replacement, new cloud infrastructure) are treated as a different host: a new `hosts/<name>/` directory is created with a fresh name, and the prior host directory may be retired. Existing host directories are not renamed in place. The rule is recorded in ADR-016.

Examples drawn from the current and planned set of hosts:
- `nixos-vm` — UTM refinement VM (aarch64-linux)
- `mercury` — work-only headless dev host on AWS EC2 (x86_64-linux)
- `metis` — personal x86_64 dev box, transitioning from headless to the first desktop host (ADR-028)
- `mothership` — second Linux desktop host (planned; pending hardware)
- `mba` — MacBook Air (planned via nix-darwin)
- `mac-mini` — Mac mini (planned via nix-darwin)

These names are accepted under the rule: each refers unambiguously to a specific physical machine. A replacement (e.g., upgrading the MacBook Air to a MacBook Pro) gets its own host directory and a fresh name.

### 5.6 Helpers and scripts

**`lib/`** contains Nix helper functions used across the configuration. The host-construction helper, `mk-host.nix`, lives here. Additional helpers are added when concrete need arises.

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

The ADRs introduced alongside this PRD (with subsequent status):

```
docs/decisions/
  ADR-013-composition-framework.md   # amended by ADR-027 (role layer walked back)
  ADR-014-independent-roles.md       # superseded by ADR-027
  ADR-015-tier-as-directory.md
  ADR-016-host-identity.md
```

Earlier ADRs (`ADR-001` through `ADR-012`) record decisions made during the prior iteration of the repository; they remain in `docs/decisions/` as historical record. Some are superseded by the new design and will have their `Status` updated to point to the superseding ADR as the new modules are built out.

---

## 6. Stability tiers

### 6.1 The two tiers

**Core.** Stable, proven modules. Eligible for import by foundation, bundles, or directly by hosts. Changes to core are deliberate.

**Experimental.** Modules under evaluation. Scoped to individual host instances by being imported (under `modules/experimental/` or `home/experimental/` paths) directly in a host's `imports` list. Never imported by foundation or bundles. May be promoted to core or removed at any time, both via explicit decision (see §6.4).

A `deprecated/` tier is not part of the current design. Failed experiments are removed; superseded core modules are replaced or deleted directly. The tier can be added later if a phase-out path is ever needed.

### 6.2 Dependency rules

- Core modules MUST NOT import experimental modules.
- Experimental modules MAY import core modules.
- Foundation files and bundles import only core modules. Experimental modules are opted into at the host level by appearing in the host's `imports` list under an `experimental/` path.

These rules are enforced by the `tier-deps` invariant (§8.1).

### 6.3 Scoping

Experimental modules are scoped to specific host instances. A host opts in by adding the experimental module's path (under `modules/experimental/` or `home/experimental/`) to its `imports` list (see §5.4).

This means:
- A new host of similar shape does not inherit the in-flight experiments of any other host.
- An experiment can be tried on one machine without affecting any other.
- Promotion to core is what makes a module eligible for foundation or bundle membership, and therefore (when promoted into a bundle most hosts import) for fleet-wide rollout.

### 6.4 Promotion and removal

Both promotion and removal are explicit, deliberate decisions made through a review. They are never the result of drift, inaction, or accumulation.

The review is conducted by Dan. Its cadence, format, and triggers are at his discretion.

Both procedures are scripted to keep the action atomic — a partial promotion (file moved but no consumers updated) is the failure mode to design against.

#### Promotion procedure

`scripts/promote.sh <module-path>` performs:

1. Move the file from `modules/experimental/<platform>/` to `modules/core/<platform>/` (or the equivalent for `home/`).
2. Add the module to the appropriate consumer — a bundle (existing or new), the platform's `foundation.nix`, or one or more host `imports` lists — depending on the scope decided at promotion time.
3. Remove the experimental-path entries from any host's `imports` list (the experimental opt-in path is no longer valid; the new core path is what the consumer references).

The author then commits the result with a message that captures the promotion and the rationale:

```
promote: <module-name> from experimental to core

<brief rationale: what was being evaluated, why it earned promotion>
```

#### Removal procedure

`scripts/remove.sh <module-path>` performs:

1. Delete the file from `modules/experimental/<platform>/` (or `home/experimental/<platform>/`).
2. Remove the experimental-path entries from any host's `imports` list.

The author then commits the result with a message that captures the removal and what was learned:

```
remove: <module-name> from experimental

<brief rationale: what was tried, why it didn't earn promotion, what was learned>
```

The "what was learned" matters. A failed experiment is a learning artefact. The commit message is where that learning is recorded.

### 6.5 Records

Experiments and their outcomes are recorded in commit history. The combination of file location (promotion = file move, removal = file deletion) and commit message captures what was tried, when, on which hosts, and how it resolved.

Experiments do not generate ADRs by default. ADRs are reserved for architectural decisions; most experiments are not architectural in nature. An experiment whose outcome *is* architectural — for example, replacing a foundational tool across the fleet — would generate an ADR for that decision, but the ADR is about the architectural shift, not the experimental process that led to it.

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
- Conditional logic based on user choice or host capability, not on platform.

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

- **Capability differences.** A NixOS host with a graphical environment and a NixOS host without one are both NixOS; the difference is which bundles each host imports (a desktop host adds `desktop-env`, `desktop-apps`, etc.). Similarly, a macOS host with `linux-builder` configured can build Linux derivations, and one without it cannot. These are capabilities of the specific instance, expressed by composition (bundle selection + standalone module imports), not by platform conditionals. `modules/core/<platform>/foundation.nix` does not branch on whether the host has any particular capability; capabilities live in bundles and standalone modules that hosts opt into.
- **Hardware differences.** Architecture (`aarch64` vs `x86_64`) is part of the platform tuple, but within a single platform family (e.g., both `aarch64-linux` and `x86_64-linux` are NixOS) the architecture is rarely a module-level concern. Hardware-specific configuration lives in the host's `hardware-configuration.nix` (auto-generated; see ADR-023) and `disko.nix` (disk layout), not in module trees.

The `shared/`-vs-`nixos/`-vs-`darwin/` split is about the *operating system the module's options target*. Other axes of variation are handled by bundle selection and host-level composition (§3, §5.4), not by the cross-platform contract.

---

## 8. Structural invariants and enforcement

Every convention that admits a deterministic test is encoded as an automated check. The list below defines the invariants the configuration must satisfy. Each invariant has a stable rule name, which is referenced in lint failure messages so that an agent failing a check can map the error back to the rule and its rationale in `CLAUDE.md`.

### 8.1 Invariants

| # | Rule name | Invariant | Enforcement |
|---|-----------|-----------|-------------|
| 1 | `shared-purity` | No platform conditionals (`isDarwin`, `isLinux`, `stdenv.is*`, platform-keyed `optionals`, references to platform-specific paths) appear in any file under `modules/*/shared/` or `home/*/shared/`. Necessary but not sufficient — see §7.1. | `scripts/lint-shared-purity.sh` |
| 2 | `tier-deps` | No file under `modules/core/` or `home/core/` imports from `modules/experimental/` or `home/experimental/`. | `scripts/lint-tier-deps.sh` |
| 3 | `filename-kebab-case` | All `.nix` filenames are kebab-case (no camelCase, no snake_case). | `scripts/lint-filename-kebab-case.sh` |
| 4 | `bundle-purity` | Aggregator files — `modules/core/<platform>/foundation.nix`, `home/core/<platform>/foundation.nix`, and any file under `modules/core/<platform>/bundles/` or `home/core/<platform>/bundles/` — contain only an `imports` list at the top level. No `mkDefault` selections, no inline option setting. Each entry in `imports` resolves to a distinct module under `modules/core/` or `home/core/` (post-path-resolution; the same module referenced via two relative-path spellings counts once). Aggregator files must import **two or more distinct modules** — single-module "bundles" are forbidden, and the underlying capability stays a standalone module until a sibling joins it. Bundles do not import other bundles (the model is flat per ADR-027). | `scripts/lint-bundle-purity.sh` |
| 5 | `host-purity` | Host `default.nix` files contain: identifying data (`networking.hostName`, `system.stateVersion`, `nixpkgs.hostPlatform` when applicable); per-host wiring (`_module.args.hostContext`); an `imports` list resolving to paths under `modules/core/`, `home/core/`, `modules/experimental/`, `home/experimental/`, or `./hardware-configuration.nix` / `./disko.nix` in the same directory; and instance-specific option overrides where the override is genuinely host-specific and would be a category mistake to place in a shared module (e.g., AWS-image conflicts, hardware-specific swap sizing, oomd policy, module-conflict resolution via `lib.mkForce`, host-tuned kernel parameters). Forbidden: inline conditional logic on host attributes, helper function definitions, derivation definitions, or any construct that would belong in a reusable module. Lint enforces the *structural* envelope (no helper definitions, no `let` bindings introducing logic, no derivation syntax) rather than judging each option assignment — the test of "genuinely host-specific" is left to author and reviewer per PRD §3.4. | `scripts/lint-host-purity.sh` |
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

1. **Edit** the relevant module, foundation, bundle, or host file.
2. **Commit.** Pre-commit runs fast structural checks only (formatter, linters, path-based lint scripts). Any failure aborts the commit with a rule-named error message.
3. **(Optional) Verify locally** with `nix run .#verify` if making non-trivial changes — this runs the full check set (evaluation + host builds) without waiting for push.
4. **Push.** Pre-push runs `nix flake check` (evaluation) then `nix build .#<host>` for each host the current machine can build natively. Any failure aborts the push.
5. **Rebuild** the machine (`darwin-rebuild switch` or `nixos-rebuild switch` against the flake) to apply the change.
6. **Verify** the change behaves as expected.

For experimental modules: the workflow includes adding the experimental module's path (under `modules/experimental/` or `home/experimental/`) to the host's `imports` list before rebuild. For promotion or removal: use `scripts/promote.sh` or `scripts/remove.sh` (§6.4).

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

Standing up a new host from a clean operating system is a documented, repeatable sequence. The configuration provides the target state; the bootstrap sequence brings a machine from its starting condition to that target.

The exact commands for each scenario live in the repository README and `CLAUDE.md`. This section documents the design.

### 11.2 Bootstrap phases

For any host, bootstrap consists of the same conceptual phases:

1. **Provide Nix.** Install Nix on the target machine, with flakes and the `nix-command` experimental feature enabled. The installer used should be the Determinate Systems installer with the upstream Nix variant (not Determinate Nix).
2. **Provide the repository.** Clone this repository onto the target machine. On NixOS hosts being installed from scratch, this may happen as part of the install process.
3. **Activate.** Run the appropriate rebuild command (`darwin-rebuild switch` or `nixos-rebuild switch`) against the flake, targeting the specific host configuration.
4. **Authenticate.** Sign into 1Password on the new machine to make runtime secrets available to the configured environment.
5. **Verify.** Confirm the activated environment matches expectations.

### 11.3 Per-host-shape notes

**macOS hosts (managed via `nix-darwin`):** Install Nix on the existing macOS install, clone, activate via `nix run nix-darwin -- switch`. After first activation, `darwin-rebuild` is available on `PATH`. Homebrew components are activated as part of the flake. Mac App Store applications, if used, are installed manually after bootstrap — they are out of scope for declarative management in current design.

**NixOS workstation hosts (with desktop environment bundles):** Bootstrap from a fresh NixOS install (via ISO). In-place migration from non-NixOS Linux distributions is not supported by this configuration; existing non-NixOS machines must be reinstalled.

**NixOS headless hosts (no desktop environment bundles):** Bootstrap via `nixos-anywhere` + `disko` with operator-injected host SSH keys (resolved in [ADR-022](./decisions/ADR-022-headless-bootstrap-nixos-anywhere.md), superseding the earlier AMI-launch approach in ADR-017). Applies to VPS, cloud, and bare-metal targets uniformly.

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

1. Provision a clean OS install matching the host's platform.
2. Run the bootstrap sequence (§11.2) for the appropriate host.

Data — Obsidian vault contents, photography libraries, project repositories — is explicitly out of scope (§2.2) and is recovered separately via its own backup mechanisms.

### 11.6 The bus-factor test

A successful design produces a configuration that another competent operator (familiar with Nix at a general level, given access to the repository and 1Password) can rebuild from in an afternoon. This is the operational standard the bootstrap design serves.

The test holds today for NixOS headless hosts (via the nixos-anywhere + disko path resolved in ADR-022, demonstrated on Mercury and Metis). It will hold for NixOS workstation hosts once metis transitions to the desktop env (ADR-028), and for macOS hosts once the mac-mini onboarding completes.

---

## 12. Deferred decisions

Design decisions that have been deliberately deferred. Decisions resolved during PRD drafting are documented in the relevant section above and not duplicated here.

**Bootstrap path for headless hosts.** *Resolved (2026-05-18) for AWS by [ADR-017](./decisions/ADR-017-headless-bootstrap-aws-ami.md):* official NixOS AMI from https://nixos.github.io/amis/ + the `amazon-image.nix` module from nixpkgs. *Subsequently superseded (2026-05-25) by [ADR-022](./decisions/ADR-022-headless-bootstrap-nixos-anywhere.md):* `nixos-anywhere` + `disko` with operator-pre-generated host keys, providing one install path across AWS + bare metal.

**Runtime secrets on headless hosts.** *Resolved (2026-05-18) by [ADR-018](./decisions/ADR-018-headless-secrets-sops.md):* continue with `sops-nix`, identical to the UTM VM. The host's ed25519 SSH key is the decryption identity. 1Password `op` on headless is deferred again until a real headless workload requires it (the trigger is described in ADR-018's Consequences).

**Continuous integration.** Deferred per §9.5. May be added once cross-platform coverage becomes valuable.

---

**End of document.**
